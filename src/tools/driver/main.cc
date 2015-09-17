// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <arpa/inet.h>
#include <libgen.h>
#include <limits.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/file.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/native_socket.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"
#include "src/tools/driver/connection.h"
#include "src/tools/driver/platform.h"

// Fast front-end for persistent compiler process.
//
// To obtain the required performance of command line tools, the fletch
// compiler based on dart2js needs to stay persistent in memory. The start-up
// time of the Dart VM, and its performance of unoptimized code make this
// necessary.
//
// An alternative would be to have a small Dart program connect to the VM, but
// measurements show this C++ program to be 10-20 times faster than a
// hello-world program in Dart.
//
// If the persistent process isn't running, it will be started by this program.
//
// Consequently, this process always communicates with a server process that
// isn't considered a child of itself.
//
// Details about starting the server: to avoid starting multiple servers, this
// program attempts obtain an exclusive lock during the initial handshake with
// the server. If the server doesn't respond, it is started, and the lock isn't
// released until the server is ready.

namespace fletch {

static const int COMPILER_CRASHED = 253;

static char* program_name = NULL;

static char fletch_config_file[MAXPATHLEN];

static char fletch_socket_file[MAXPATHLEN];

static const char fletch_config_name[] = ".fletch";

static int fletch_config_fd;

static const char dart_vm_env_name[] = "DART_VM";

static const char dart_vm_name[] = "dart";

static int exit_code = COMPILER_CRASHED;

static void WriteFully(int fd, uint8* data, ssize_t length);

void Die(const char* format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  fprintf(stderr, "\n");
  exit(255);
}

static void StrCpy(
    void* destination,
    size_t destination_size,
    const void* source,
    size_t source_size) {
  const void* source_end = memchr(source, '\0', source_size);
  if (source_end == NULL) {
    Die("%s: source isn't zero-terminated.", program_name);
  }
  size_t source_length = reinterpret_cast<const uint8*>(source_end) -
      reinterpret_cast<const uint8*>(source);
  // Increment source_length to include '\0'.
  source_length++;

  if (source_length > destination_size) {
    Die("%s: not enough room in destination (%i) for %i bytes.",
        program_name, destination_size, source_length);
  }

  memcpy(destination, source, source_length);
}

static void StrCat(
    void* destination,
    size_t destination_size,
    const void* source,
    size_t source_size) {
  void* destination_end = memchr(destination, '\0', destination_size);
  if (destination_end == NULL) {
    Die("%s: destination isn't zero-terminated.", program_name);
  }
  size_t destination_length =
    reinterpret_cast<uint8*>(destination_end) -
    reinterpret_cast<uint8*>(destination);

  StrCpy(
      destination_end, destination_size - destination_length,
      source, source_size);
}

static void Close(int fd) {
  if (TEMP_FAILURE_RETRY(close(fd)) == -1) {
    Die("%s: close failed: %s", program_name, strerror(errno));
  }
}

dev_t GetDevice(const char* name) {
  struct stat info;
  if (stat(name, &info) != 0) {
    Die("%s: Unable to stat '%s': %s", program_name, name, strerror(errno));
  }
  return info.st_dev;
}

bool FileExists(const char* name) {
  struct stat info;
  if (stat(name, &info) == 0) {
    return (info.st_mode & S_IFREG) != 0;
  }
  return false;
}

void FletchConfigFile(char* result, const char* directory) {
  // TODO(ahe): Use StrCat or StrCpy instead.
  char* ptr = stpncpy(result, directory, MAXPATHLEN);
  if (ptr[-1] != '/') {
    ptr[0] = '/';
    ptr++;
  }
  // TODO(ahe): Use StrCat or StrCpy instead.
  strncpy(ptr, fletch_config_name, sizeof(fletch_config_name));
}

void ParentDir(char* directory) {
  char copy[MAXPATHLEN + 1];
  // On Linux, dirname's argument may be modified. On Mac OS X, it returns a
  // pointer to internal memory. Probably not thread safe. So we first copy
  // directory to a place we don't mind getting modified.
  // TODO(ahe): Use StrCat or StrCpy instead.
  strncpy(copy, directory, MAXPATHLEN);
  char* parent = dirname(copy);
  if (parent == NULL) {
    Die("%s: Unable to compute parent directory of '%s': %s",
        program_name, directory, strerror(errno));
  }
  // TODO(ahe): Use StrCat or StrCpy instead.
  strncpy(directory, parent, MAXPATHLEN);
}

// Detect the configuration and initialize the following variables:
//
// * fletch_config_file
//
// We search for a file named fletch_config_name in the current directory. If
// such a file doesn't exist, traverse parent directories until a file is
// found. Stop traversing parent directories if its device is different from
// current directory. If no file is found, assume it should be created in the
// current directory.
static void DetectConfiguration() {
  char cwd[MAXPATHLEN + 1];
  char directory[MAXPATHLEN + 1];
  char path[MAXPATHLEN + 1];

  if (getcwd(cwd, sizeof(directory)) == NULL) {
    Die("%s: Unable to read current directory: %s",
        program_name, strerror(errno));
  }
  // TODO(ahe): Use StrCat or StrCpy instead.
  strncpy(directory, cwd, MAXPATHLEN);

  dev_t starting_device = GetDevice(cwd);

  do {
    FletchConfigFile(path, directory);

    if (FileExists(path)) {
      // TODO(ahe): Use StrCat or StrCpy instead.
      strncpy(fletch_config_file, path, MAXPATHLEN);
      return;
    }
    if (strlen(directory) == 1) {
      break;
    }
    ParentDir(directory);
  } while (starting_device == GetDevice(directory));

  FletchConfigFile(path, cwd);
  // TODO(ahe): Use StrCat or StrCpy instead.
  strncpy(fletch_config_file, path, MAXPATHLEN);
}

// Opens and locks the config file named by fletch_config_file and initialize
// the variable fletch_config_fd.
static void LockConfigFile() {
  int fd = TEMP_FAILURE_RETRY(
      open(fletch_config_file, O_RDONLY | O_CREAT, S_IRUSR | S_IWUSR));
  if (fd == -1) {
    Die("%s: Unable open '%s' failed: %s.", program_name, fletch_config_file,
        strerror(errno));
  }

  if (TEMP_FAILURE_RETRY(flock(fd, LOCK_EX)) == -1) {
    Die("%s: flock '%s' failed: %s.", program_name, fletch_config_file,
        strerror(errno));
  }

  fletch_config_fd = fd;
}

// Release the lock on fletch_config_fd.
static void UnlockConfigFile() {
  // Closing the file descriptor will release the lock.
  Close(fletch_config_fd);
}

static void ReadDriverConfig() {
  size_t offset = 0;
  size_t length = sizeof(fletch_socket_file) - 1;
  while (offset < length) {
    ssize_t bytes = TEMP_FAILURE_RETRY(
        read(fletch_config_fd, fletch_socket_file + offset, length - offset));
    if (bytes < 0) {
      Die("%s: error reading from child process: %s",
          program_name, strerror(errno));
    } else if (bytes == 0) {
      break;  // End of file.
    }
    offset += bytes;
  }
  fletch_socket_file[offset] = '\0';
}

static void ComputeFletchRoot(char* buffer, size_t buffer_length) {
  // TODO(ahe): Fix lint problem: Do not use variable-length arrays.
  char resolved[buffer_length];  // NOLINT
  GetPathOfExecutable(buffer, buffer_length);
  if (realpath(buffer, resolved) == NULL) {
    Die("%s: realpath of '%s' failed: %s", program_name, buffer,
        strerror(errno));
  }
  StrCpy(buffer, buffer_length, resolved, sizeof(resolved));

  // 'buffer' is now the absolute path of this executable (with symlinks
  // resolved). When running from fletch-repo, this executable will be in
  // "fletch-repo/fletch/out/$CONFIGURATION/fletch_driver".
  ParentDir(buffer);
  // 'buffer' is now, for example, "fletch-repo/fletch/out/$CONFIGURATION".
  ParentDir(buffer);
  // 'buffer' is now, for example, "fletch-repo/fletch/out".
  ParentDir(buffer);
  // 'buffer' is now, for example, "fletch-repo/fletch".

  size_t length = strlen(buffer);
  if (length > 0 && buffer[length - 1] != '/') {
    // Append trailing slash.
    StrCat(buffer, buffer_length, "/", 2);
  }
}

// Stores the location of the Dart VM in 'buffer'.
static void ComputeDartVmPath(char* buffer, size_t buffer_length) {
  char* dart_vm_env = getenv(dart_vm_env_name);
  if (dart_vm_env != NULL) {
    StrCpy(buffer, buffer_length, dart_vm_env, strlen(dart_vm_env) + 1);
    return;
  }

  // TODO(ahe): Fix lint problem: Do not use variable-length arrays.
  char resolved[buffer_length];  // NOLINT
  GetPathOfExecutable(buffer, buffer_length);
  if (realpath(buffer, resolved) == NULL) {
    Die("%s: realpath of '%s' failed: %s", program_name, buffer,
        strerror(errno));
  }
  StrCpy(buffer, buffer_length, resolved, sizeof(resolved));

  // 'buffer' is now the absolute path of this executable (with symlinks
  // resolved). When running from fletch-repo, this executable will be in
  // "fletch-repo/fletch/out/$CONFIGURATION/fletch_driver".
  ParentDir(buffer);
  // 'buffer' is now, for example, "fletch-repo/fletch/out/$CONFIGURATION".

  size_t length = strlen(buffer);
  if (length > 0 && buffer[length - 1] != '/') {
    // Append trailing slash.
    StrCat(buffer, buffer_length, "/", 2);
  }

  StrCat(buffer, buffer_length, dart_vm_name, sizeof(dart_vm_name));
  // 'buffer' is now, for example, "fletch-repo/fletch/out/$CONFIGURATION/dart".
}

// Stores the package root in 'buffer'. The value of 'fletch_root' must be the
// absolute path of '.../fletch-repo/fletch/' (including trailing slash).
static void ComputePackageSpec(
    char* buffer, size_t buffer_length,
    const char* fletch_root, size_t fletch_root_length) {
  StrCpy(buffer, buffer_length, fletch_root, fletch_root_length);
  StrCat(buffer, buffer_length,
         "pkg/fletchc/.packages", sizeof("pkg/fletchc/.packages"));
  // 'buffer' is now, for example, "fletch-repo/fletch/package/".
}

// Flush all open streams (FILE objects). This is needed before forking
// (otherwise, buffered data will get duplicated in the children leading to
// duplicated output). It is also needed before using file descriptors, as I/O
// based on file descriptors bypass any buffering in streams.
void FlushAllStreams() {
  if (fflush(NULL) != 0) {
    Die("%s: fflush failed: %s", program_name, strerror(errno));
  }
}

pid_t Fork() {
  FlushAllStreams();

  pid_t pid = fork();
  if (pid == -1) {
    Die("%s: fork failed: %s", program_name, strerror(errno));
  }
  return pid;
}

static void WaitForDaemonHandshake(
    pid_t pid,
    int parent_stdout,
    int parent_stderr);

static void ExecDaemon(
    int child_stdout,
    int child_stderr,
    const char** argv);

static void StartDriverDaemon() {
  const int kMaxArgv = 6;
  const char* argv[kMaxArgv];

  char fletch_root[MAXPATHLEN + 1];
  ComputeFletchRoot(fletch_root, sizeof(fletch_root));

  char vm_path[MAXPATHLEN + 1];
  ComputeDartVmPath(vm_path, sizeof(vm_path));

  char package_spec[MAXPATHLEN + 1];
  ComputePackageSpec(
      package_spec, sizeof(package_spec), fletch_root, sizeof(fletch_root));

  char package_option[sizeof("--packages=") + MAXPATHLEN + 1];
  StrCpy(package_option, sizeof(package_option),
         "--packages=", sizeof("--packages="));
  StrCat(package_option, sizeof(package_option),
         package_spec, sizeof(package_spec));

  int argc = 0;
  argv[argc++] = vm_path;
  argv[argc++] = "-c";
  argv[argc++] = package_option;
  argv[argc++] = "package:fletchc/src/driver/driver_main.dart";
  argv[argc++] = fletch_config_file;
  argv[argc++] = NULL;
  if (argc > kMaxArgv) Die("Internal error: increase argv size");

  int file_descriptors[2];
  if (pipe(file_descriptors) != 0) {
    Die("%s: pipe failed: %s", program_name, strerror(errno));
  }
  int parent_stdout = file_descriptors[0];
  int child_stdout = file_descriptors[1];

  if (pipe(file_descriptors) != 0) {
    Die("%s: pipe failed: %s", program_name, strerror(errno));
  }
  int parent_stderr = file_descriptors[0];
  int child_stderr = file_descriptors[1];

  pid_t pid = Fork();
  if (pid == 0) {
    // In child.
    Close(parent_stdout);
    Close(parent_stderr);
    Close(fletch_config_fd);
    ExecDaemon(child_stdout, child_stderr, argv);
    UNREACHABLE();
  } else {
    Close(child_stdout);
    Close(child_stderr);
    WaitForDaemonHandshake(pid, parent_stdout, parent_stderr);
  }
}

static void NewProcessSession() {
  pid_t sid = setsid();
  if (sid < 0) {
    Die("%s: setsid failed: %s", program_name, strerror(errno));
  }
}

static void Dup2(int source, int destination) {
  if (TEMP_FAILURE_RETRY(dup2(source, destination)) == -1) {
    Die("%s: dup2 failed: %s", program_name, strerror(errno));
  }
}

static void ExecDaemon(
    int child_stdout,
    int child_stderr,
    const char** argv) {
  Close(STDOUT_FILENO);

  // Calling fork one more time to create an indepent processs. This prevents
  // zombie processes, and ensures the server can continue running in the
  // background independently of the parent process.
  if (Fork() > 0) {
    // This process exits and leaves the new child as an independent process.
    exit(0);
  }

  // Create a new session (to avoid getting killed by Ctrl-C).
  NewProcessSession();

  // This is the child process that will exec the persistent server. We don't
  // want this server to be associated with the current terminal, so we must
  // close stdin (handled above), stdout, and stderr. This is accomplished by
  // redirecting stdout and stderr to the pipes to the parent process.
  Dup2(child_stdout, STDOUT_FILENO);  // Closes stdout.
  Dup2(child_stderr, STDERR_FILENO);  // Closes stderr.
  Close(child_stdout);
  Close(child_stderr);

  execv(argv[0], const_cast<char**>(argv));
  Die("%s: exec '%s' failed: %s", program_name, argv[0], strerror(errno));
}

static ssize_t Read(int fd, char* buffer, size_t buffer_length) {
  ssize_t bytes_read =
      TEMP_FAILURE_RETRY(read(fd, buffer, buffer_length));
  if (bytes_read < 0) {
    Die("%s: read failed: %s", program_name, strerror(errno));
  }
  return bytes_read;
}

// Forwards data on file descriptor "from" to "to" using the buffer. Errors are
// fatal. Returns true if "from" was closed.
static bool ForwardWithBuffer(
    int from,
    int to,
    char* buffer,
    ssize_t* buffer_length) {
  ssize_t bytes_read = Read(from, buffer, *buffer_length);
  *buffer_length = bytes_read;
  if (bytes_read == 0) return true;

  // Flushing all streams in case one of them has buffered data for "to" file
  // descriptor.
  FlushAllStreams();

  WriteFully(to, reinterpret_cast<uint8*>(buffer), bytes_read);
  return false;
}

static void WaitForDaemonHandshake(
    pid_t pid,
    int parent_stdout,
    int parent_stderr) {
  int status;
  waitpid(pid, &status, 0);
  if (!WIFEXITED(status)) {
    Die("%s: child process failed.", program_name);
  }
  status = WEXITSTATUS(status);
  if (status != 0) {
    Die("%s: child process exited with non-zero exit code %i.",
        program_name, status);
  }

  char stdout_buffer[4096];
  stdout_buffer[0] = '\0';
  bool stdout_is_closed = false;
  bool stderr_is_closed = false;
  while (!stdout_is_closed || !stderr_is_closed) {
    char buffer[4096];
    fd_set readfds;
    int max_fd = 0;
    FD_ZERO(&readfds);
    if (!stdout_is_closed) {
      FD_SET(parent_stdout, &readfds);
      max_fd = Utils::Maximum(max_fd, parent_stdout);
    }
    if (!stderr_is_closed) {
      FD_SET(parent_stderr, &readfds);
      max_fd = Utils::Maximum(max_fd, parent_stderr);
    }
    int ready_count =
        TEMP_FAILURE_RETRY(select(max_fd + 1, &readfds, NULL, NULL, NULL));
    if (ready_count < 0) {
      fprintf(stderr, "%s: select error: %s", program_name, strerror(errno));
      break;
    } else if (ready_count == 0) {
      // Timeout, shouldn't happen.
    } else {
      if (FD_ISSET(parent_stderr, &readfds)) {
        ssize_t bytes_read = sizeof(buffer);
        stderr_is_closed = ForwardWithBuffer(
            parent_stderr, STDERR_FILENO, buffer, &bytes_read);
      }
      if (FD_ISSET(parent_stdout, &readfds)) {
        ssize_t bytes_read = Read(parent_stdout, buffer, sizeof(buffer) - 1);
        stdout_is_closed = bytes_read == 0;
        buffer[bytes_read] = '\0';
        StrCat(stdout_buffer, sizeof(stdout_buffer), buffer, sizeof(buffer));
        // At this point, stdout_buffer contains all the data we have
        // received from the server process via its stdout. We're looking for
        // a handshake which is a file name on the first line. So we look for
        // a newline character.
        char* match = strchr(stdout_buffer, '\n');
        if (match != NULL) {
          // If we do not have a precise match the VM is printing
          // something unexpected and we print it out to make
          // debugging easier.
          if (match[1] != '\0') {
            FlushAllStreams();
            WriteFully(STDOUT_FILENO,
                       reinterpret_cast<uint8*>(buffer),
                       bytes_read);
          }
          match[0] = '\0';
          StrCpy(
              fletch_socket_file, sizeof(fletch_socket_file),
              stdout_buffer, sizeof(stdout_buffer));
          // We got the server handshake (the socket file). So we break to
          // eventually return from this function.
          break;
        }
      }
    }
  }
  Close(parent_stdout);
  Close(parent_stderr);
}

static void WriteFully(int fd, uint8* data, ssize_t length) {
  ssize_t offset = 0;
  while (offset < length) {
    int bytes = TEMP_FAILURE_RETRY(write(fd, data + offset, length - offset));
    if (bytes < 0) {
      Die("%s: write failed: %s", program_name, strerror(errno));
    }
    offset += bytes;
  }
}

static void SendArgv(DriverConnection* connection, int argc, char** argv) {
  WriteBuffer buffer;
  buffer.WriteInt(argc + 2);  // Also current directory, and absolute path to
                              // program.

  char* path = static_cast<char*>(malloc(MAXPATHLEN + 1));
  if (path == NULL) {
    Die("%s: malloc failed: %s", path, strerror(errno));
  }

  if (getcwd(path, MAXPATHLEN + 1) == NULL) {
    Die("%s: getcwd failed: %s", path, strerror(errno));
  }
  buffer.WriteInt(strlen(path));
  buffer.WriteString(path);

  // argv[0] is the name of the executable before path search. But the driver
  // needs the absolute location provided by GetPathOfExecutable.
  GetPathOfExecutable(path, MAXPATHLEN + 1);
  buffer.WriteInt(strlen(path));
  buffer.WriteString(path);

  free(path);
  path = NULL;

  for (int i = 0; i < argc; i++) {
    buffer.WriteInt(strlen(argv[i]));
    buffer.WriteString(argv[i]);
  }
  connection->Send(DriverConnection::kArguments, buffer);
}

static int CommandFileDescriptor(DriverConnection::Command command) {
  switch (command) {
    case DriverConnection::kStdin:
    case DriverConnection::kStdout:
    case DriverConnection::kStderr:
      return command;

    default:
      Die("%s: No file descriptor for command: %i\n", program_name, command);
      return -1;
  }
}

static DriverConnection::Command HandleCommand(DriverConnection* connection) {
  DriverConnection::Command command = connection->Receive();
  switch (command) {
    case DriverConnection::kExitCode:
      exit_code = connection->ReadInt();
      return command;

    case DriverConnection::kStdout:
    case DriverConnection::kStderr: {
      int size = 0;
      uint8* bytes = connection->ReadBytes(&size);
      WriteFully(CommandFileDescriptor(command), bytes, size);
      free(bytes);
      return command;
    }

    case DriverConnection::kDriverConnectionError:
    case DriverConnection::kDriverConnectionClosed:
      return command;

    default:
      break;
  }

  Die("%s: Unhandled command code: %i\n", program_name, command);
  return DriverConnection::kDriverConnectionError;
}

Socket* Connect() {
  struct sockaddr_un address;

  address.sun_family = AF_UNIX;
  StrCpy(
      address.sun_path, sizeof(address.sun_path),
      fletch_socket_file, sizeof(fletch_socket_file));

  int fd = socket(PF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) {
    Die("%s: socket failed: %s", program_name, strerror(errno));
  }
  Socket* socket = new Socket(fd);

  int connect_result = TEMP_FAILURE_RETRY(connect(
    fd, reinterpret_cast<struct sockaddr*>(&address), sizeof(address)));
  if (connect_result != 0) {
    delete socket;
    return NULL;
  } else {
    return socket;
  }
}

static void HandleSignal(int signal_pipe, DriverConnection* connection) {
  WriteBuffer buffer;
  int signal = ReadSignal(signal_pipe);
  buffer.WriteInt(signal);
  connection->Send(DriverConnection::kSignal, buffer);
}

static int Main(int argc, char** argv) {
  program_name = argv[0];
  DetectConfiguration();
  LockConfigFile();
  ReadDriverConfig();

  Socket* control_socket = Connect();

  if (control_socket == NULL) {
    StartDriverDaemon();
    control_socket = Connect();
    if (control_socket == NULL) {
      Die(
          "%s: Failed to start fletch server (%s).\n"
          "Use DART_VM environment variable to override location of Dart VM.",
          program_name, strerror(errno));
    }
  }

  UnlockConfigFile();

  int signal_pipe = SignalFileDescriptor();

  DriverConnection* connection = new DriverConnection(control_socket);

  SendArgv(connection, argc, argv);

  FlushAllStreams();

  struct termios term;
  tcgetattr(STDIN_FILENO, &term);
  term.c_lflag &= ~(ICANON);
  tcsetattr(STDIN_FILENO, TCSANOW, &term);

  int max_fd = Utils::Maximum(STDIN_FILENO, control_socket->FileDescriptor());
  max_fd = Utils::Maximum(max_fd, signal_pipe);
  bool stdin_closed = false;
  while (true) {
    fd_set readfds;
    FD_ZERO(&readfds);
    if (!stdin_closed) {
      FD_SET(STDIN_FILENO, &readfds);
    }
    FD_SET(control_socket->FileDescriptor(), &readfds);
    FD_SET(signal_pipe, &readfds);

    int ready_count =
        TEMP_FAILURE_RETRY(select(max_fd + 1, &readfds, NULL, NULL, NULL));
    if (ready_count < 0) {
      fprintf(stderr, "%s: select error: %s", program_name, strerror(errno));
      break;
    } else if (ready_count == 0) {
      // Timeout, shouldn't happen.
    } else {
      if (FD_ISSET(signal_pipe, &readfds)) {
        HandleSignal(signal_pipe, connection);
      }
      if (FD_ISSET(STDIN_FILENO, &readfds)) {
        uint8 buffer[4096];
        ssize_t bytes_count =
            TEMP_FAILURE_RETRY(read(STDIN_FILENO, &buffer, sizeof(buffer)));
        if (bytes_count >= 0) {
          WriteBuffer write_buffer;
          write_buffer.WriteBytes(buffer, bytes_count);
          connection->Send(DriverConnection::kStdin, write_buffer);
          if (bytes_count == 0) {
            close(STDIN_FILENO);
            stdin_closed = true;
          }
        } else if (bytes_count < 0) {
          Die("%s: Error reading from stdin: %s",
              program_name, strerror(errno));
        }
      }
      if (FD_ISSET(control_socket->FileDescriptor(), &readfds)) {
        DriverConnection::Command command = HandleCommand(connection);
        if (command == DriverConnection::kDriverConnectionError) {
          Die("%s: lost connection to persistent process: %s",
              program_name, strerror(errno));
        } else if (command == DriverConnection::kDriverConnectionClosed) {
          // Connection was closed.
          break;
        }
      }
    }
  }

  Exit(exit_code);
  return exit_code;
}

}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
