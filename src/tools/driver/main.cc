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
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

#include "src/shared/globals.h"

#include "src/shared/native_socket.h"

#include "src/tools/driver/get_path_of_executable.h"

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
// If the persistent process isn't running, it will be started by this
// program. This is done with two forks, see, for example:
// http://stackoverflow.com/questions/881388/what-is-the-reason-for-performing-a-double-fork-when-creating-a-daemon // NOLINT
//
// Consequently, this process always communicates with a server process that
// isn't considered a child of itself.
//
// TODO(ahe): Send the command line arguments of this process to the persistent
// process.

namespace fletch {


static const char* driver_env_name = "FLETCH_DRIVER_PORT";


static char* program_name = NULL;


static char fletch_config_file[MAXPATHLEN];


static const char fletch_config_name[] = ".fletch";


static bool fletch_config_file_exists = false;


static const char* dart_vm_name = "/dart/sdk/bin/dart";


void Die(const char *format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  fprintf(stderr, "\n");
  exit(255);
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


void FletchConfigFile(char *result, const char* directory) {
  char* ptr = stpncpy(result, directory, MAXPATHLEN);
  if (ptr[-1] != '/') {
    ptr[0] = '/';
    ptr++;
  }
  strncpy(ptr, fletch_config_name, sizeof(fletch_config_name));
}


void ParentDir(char *directory) {
  char copy[MAXPATHLEN + 1];
  // On Linux, dirname's argument may be modified. On Mac OS X, it returns a
  // pointer to internal memory. Probably not thread safe. So we first copy
  // directory to a place we don't mind getting modified.
  strncpy(copy, directory, MAXPATHLEN);
  char* parent = dirname(copy);
  if (parent == NULL) {
    Die("%s: Unable to compute parent directory of '%s': %s",
        program_name, directory, strerror(errno));
  }
  strncpy(directory, parent, MAXPATHLEN);
}

// Detect the configuration and initialize the following variables:
//
// * fletch_config_file
// * fletch_config_file_exists
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
  strncpy(directory, cwd, MAXPATHLEN);

  dev_t starting_device = GetDevice(cwd);

  do {
    FletchConfigFile(path, directory);

    if (FileExists(path)) {
      strncpy(fletch_config_file, path, MAXPATHLEN);
      fletch_config_file_exists = true;
      return;
    }
    if (strlen(directory) == 1) {
      break;
    }
    ParentDir(directory);
  } while (starting_device == GetDevice(directory));

  FletchConfigFile(path, cwd);
  strncpy(fletch_config_file, path, MAXPATHLEN);
  fletch_config_file_exists = false;
}


static void ReadDriverConfig(char* config_string, size_t length) {
  DetectConfiguration();
  if (fletch_config_file_exists) {
    printf("Using config file: %s\n", fletch_config_file);

    FILE* file = fopen(fletch_config_file, "r");
    if (file == NULL) {
      Die("%s: Unable to read '%s': %s", program_name, fletch_config_file,
          strerror(errno));
    }
    size_t read = fread(config_string, sizeof(char), length - 1, file);
    config_string[read] = '\0';
  } else {
    printf("Creating config file: %s\n", fletch_config_file);
  }
}


static int ComputeDriverPort() {
  char buffer[1024];
  char* port_string = getenv(driver_env_name);

  const char* what = "Value of environment variable";
  const char* who = driver_env_name;

  if (port_string == NULL) {
    buffer[0] = '\0';
    ReadDriverConfig(buffer, sizeof(buffer));
    if (buffer[0] == '\0') return -1;
    port_string = buffer;
    what = "Contents of file";
    who = fletch_config_file;
  }

  // Socket ports are in the range 0..65k.
  size_t max_length = 5;

  size_t port_string_length = strnlen(port_string, max_length + 1);
  if (port_string_length > max_length) {
    fprintf(stderr, "%s: %s '%s' is too large.\n", program_name, what, who);
    return -2;
  }
  char* end = NULL;
  intmax_t port = strtoimax(port_string, &end, 10);
  if (port_string + port_string_length != end) {
    fprintf(stderr,
            "%s: %s '%s' isn't a number: '%s'.\n",
            program_name, what, who, port_string);
    return -2;
  }

  if (port < -1) {
    fprintf(stderr,
            "%s: %s '%s' is less than -1: '%ji'.\n",
            program_name, what, who, port);
    return -2;
  }

  if (port > USHRT_MAX) {
    fprintf(stderr,
            "%s: %s '%s' is larger than %i: '%ji'.\n",
            program_name, what, who, USHRT_MAX, port);
    return -2;
  }

  // We have determined that the port number is in the range [-1, USHRT_MAX],
  // and can safely cast it to an int.
  return (int)port;
}


static void ComputeDartVmPath(char* buffer, size_t buffer_length) {
  char resolved[buffer_length];
  GetPathOfExecutable(buffer, buffer_length);
  if (realpath(buffer, resolved) == NULL) {
    Die("%s: realpath of '%s' failed: %s", program_name, buffer,
        strerror(errno));
  }
  strncpy(buffer, resolved, buffer_length);
  ParentDir(buffer);
  ParentDir(buffer);
  ParentDir(buffer);
  ParentDir(buffer);
  size_t length = strlen(buffer);
  strncpy(buffer + length, dart_vm_name, buffer_length - length);
}


static int StartFletchDriverServer() {
  const char* argv[6];

  char vm_path[MAXPATHLEN + 1];
  ComputeDartVmPath(vm_path, sizeof(vm_path));

  argv[0] = vm_path;
  argv[1] = "-c";
  argv[2] = "-ppackage/";
  argv[3] = "package:fletchc/src/driver.dart";
  argv[4] = fletch_config_file;
  argv[5] = NULL;

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

  pid_t pid = fork();
  if (pid == 0) {
    // In child.
    close(parent_stdout);
    close(parent_stderr);
    fclose(stdin);

    // Create an indepent processs.
    pid = fork();
    if (pid < 0) {
      Die("%s: fork failed: %s", program_name, strerror(errno));
    }
    if (pid > 0) {
      exit(0);
    }

    // Create a new session (to avoid getting killed by Ctrl-C).
    pid_t sid = setsid();
    if (sid < 0) {
      Die("%s: setsid failed: %s", program_name, strerror(errno));
    }

    // This is the child process that will exec the persistent server. We don't
    // want this server to be associated with the current terminal, so we must
    // close stdin (handled above), stdout, and stderr.
    fflush(stdout);
    fflush(stderr);

    // Now redirect stdout and stderr to the pipes to the parent process.
    dup2(child_stdout, STDOUT_FILENO);  // Closes stdout.
    dup2(child_stderr, STDERR_FILENO);  // Closes stderr.
    close(child_stdout);
    close(child_stderr);

    execv(vm_path, const_cast<char**>(argv));
    Die("%s: exec '%s' failed: %s", program_name, vm_path, strerror(errno));
  } else {
    // In parent.
    if (pid == -1) {
      Die("%s: fork failed: %s", program_name, strerror(errno));
    }
    close(child_stdout);
    close(child_stderr);

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

    // TODO(ahe): Use select to empty parent_stdout and parent_stderr until a
    // port number has been successfully read.
    char buffer[10];
    ssize_t bytes_read =
      TEMP_FAILURE_RETRY(read(parent_stdout, buffer, sizeof(buffer) - 1));
    if (bytes_read < 0) {
      Die("%s: error reading from child process: %s",
          program_name, strerror(errno));
    }
    buffer[bytes_read] = '\0';
    close(parent_stdout);
    close(parent_stderr);
    char *end;
    intmax_t port = strtoimax(buffer, &end, 10);
    printf("Started persistent driver process on port %i\n", port);
    return port;
  }
  return -1;
}


static int ReadInt(Socket *socket) {
  uint32* data = reinterpret_cast<uint32*>(socket->Read(4));
  uint32 result = ntohl(*data);
  free(data);
  return (int)result;
}


static void Forward(Socket* socket, FILE* file) {
  uint8 buffer[1500];
  size_t bytes_count = read(socket->FileDescriptor(), &buffer, sizeof(buffer));
  // TODO(ahe): Check return values.
  fwrite(&buffer, bytes_count, 1, file);
}


static int Main(int argc, char** argv) {
  program_name = argv[0];
  int port = ComputeDriverPort();
  Socket *socket = new Socket();

  if (port < -1) {
    return 1;
  }

  if (!socket->Connect("127.0.0.1", port)) {
    port = StartFletchDriverServer();

    delete socket;
    socket = new Socket();
    if (!socket->Connect("127.0.0.1", port)) {
      Die("%s: Failed to start fletch server.", program_name);
    }
  }

  int io_port = ReadInt(socket);

  Socket *stdio_socket = new Socket();
  Socket *stderr_socket = new Socket();

  if (!stdio_socket->Connect("127.0.0.1", io_port)) {
    Die("%s: Failed to connect stdio.", program_name);
  }

  if (!stderr_socket->Connect("127.0.0.1", io_port)) {
    Die("%s: Failed to connect stderr.", program_name);
  }

  struct termios term;
  tcgetattr(STDIN_FILENO, &term);
  term.c_lflag &= ~(ICANON);
  tcsetattr(STDIN_FILENO, TCSANOW, &term);


  int nfds = stdio_socket->FileDescriptor();
  if (nfds < stderr_socket->FileDescriptor()) {
    nfds = stderr_socket->FileDescriptor();
  }
  if (nfds < socket->FileDescriptor()) {
    nfds = socket->FileDescriptor();
  }
  nfds++;
  while (true) {
    fd_set readfds;
    fd_set writefds;
    fd_set errorfds;
    FD_ZERO(&readfds);
    FD_ZERO(&writefds);
    FD_ZERO(&errorfds);
    FD_SET(STDIN_FILENO, &readfds);
    FD_SET(socket->FileDescriptor(), &readfds);
    FD_SET(stdio_socket->FileDescriptor(), &readfds);
    FD_SET(stderr_socket->FileDescriptor(), &readfds);

    int ready_count = select(nfds, &readfds, &writefds, &errorfds, NULL);
    if (ready_count < 0) {
      fprintf(stderr, "%s: select error: %s", program_name, strerror(errno));
      break;
    } else if (ready_count == 0) {
      // Timeout, shouldn't happen.
    } else {
      if (FD_ISSET(stdio_socket->FileDescriptor(), &readfds)) {
        Forward(stdio_socket, stdout);
      }
      if (FD_ISSET(stderr_socket->FileDescriptor(), &readfds)) {
        Forward(stderr_socket, stderr);
      }
      if (FD_ISSET(STDIN_FILENO, &readfds)) {
        uint8 buffer[1500];
        size_t bytes_count = read(STDIN_FILENO, &buffer, sizeof(buffer));
        // TODO(ahe): Check return values.
        write(stdio_socket->FileDescriptor(), &buffer, bytes_count);
      }
      if (FD_ISSET(socket->FileDescriptor(), &readfds)) {
        exit(ReadInt(socket));
      }
    }
  }

  return 0;
}


}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
