// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include <ctype.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

#include "include/fletch_api.h"

#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/utils.h"
#include "src/shared/version.h"

#include "src/vm/session.h"
#include "src/vm/log_print_interceptor.h"

namespace fletch {

static int RunSession(Connection* connection) {
  Session session(connection);
  session.Initialize();
  session.StartMessageProcessingThread();
  int result = session.ProcessRun();
  session.JoinMessageProcessingThread();
  return result;
}

static Connection* WaitForCompilerConnection(
    const char* host, int port, const char* port_file) {
  // Listen for new connections.
  ConnectionListener listener(host, port);

  Print::Out("Waiting for compiler on %s:%i\n", host, listener.Port());
  if (port_file != NULL) {
    char value_string[20];
    snprintf(value_string, sizeof(value_string), "%d", listener.Port());
    Platform::WriteText(port_file, value_string, false);
  }
  return listener.Accept();
}

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static bool StartsWith(const char* s, const char* prefix) {
  return strncmp(s, prefix, strlen(prefix)) == 0;
}

static bool EndsWith(const char* s, const char* suffix) {
  int s_length = strlen(s);
  int suffix_length = strlen(suffix);
  return (suffix_length <= s_length)
      ? strncmp(s + s_length - suffix_length, suffix, suffix_length) == 0
      : false;
}

#ifdef DEBUG
static void WaitForGDB(const char* executable_name) {
  int fd = open("/dev/tty", O_WRONLY);
  if (fd >= 0) {
    FILE* terminal = fdopen(fd, "w");
    fprintf(terminal, "*** VM paused, debug with:\n");
    fprintf(
        terminal,
        "gdb %s --ex 'attach %d' --ex 'signal SIGCONT' --ex 'signal SIGCONT'\n",
        executable_name,
        getpid());
    kill(getpid(), SIGSTOP);
  }
}
#endif

static void PrintUsage() {
  Print::Out("fletch-vm - The embedded Dart virtual machine.\n\n");
  Print::Out("  fletch-vm [--port=<port>] [--host=<address>] "
             "[snapshot file]\n\n");
  Print::Out("When specifying a snapshot other options are ignored.\n\n");
  Print::Out("Options:\n");
  Print::Out("  --port: specifies which port to listen on. Defaults "
             "to random port.\n");
  Print::Out("  --host: specifies which host address to listen on. "
             "Defaults to 127.0.0.1.\n");
  Print::Out("  --help: print out 'fletch-vm' usage.\n");
  Print::Out("  --version: print the version.\n");
  Print::Out("\n");
}

static void PrintVersion() {
  Print::Out("%s\n", GetVersion());
}

static int Main(int argc, char** argv) {
#ifdef DEBUG
  if (getenv("FLETCH_VM_WAIT") != NULL) {
    WaitForGDB(argv[0]);
  }
#endif
  Flags::ExtractFromCommandLine(&argc, argv);
  FletchSetup();

  if (argc > 5) {
    Print::Out("Too many arguments.\n\n");
    PrintUsage();
    exit(1);
  } else if (argc < 1) {
    Print::Out("Not enough arguments.\n\n");
    PrintUsage();
    exit(1);
  }

  // Handle the arguments.
  const char* host = "127.0.0.1";
  const char* log_dir = NULL;
  const char* port_file = NULL;
  int port = 0;
  const char* input = NULL;

  // We run a snapshot only if the arguments contain a file name.
  bool run_snapshot = false;
  bool invalid_option = false;

  for (int i = 1; i < argc; ++i) {
    const char* argument = argv[i];
    if (StartsWith(argument, "--port=")) {
      port = atoi(argument + 7);
    } else if (StartsWith(argument, "--host=")) {
      host = argument + 7;
    } else if (strcmp(argument, "--help") == 0) {
      PrintUsage();
      exit(0);
    } else if (strcmp(argument, "--version") == 0) {
      PrintVersion();
      exit(0);
    } else if (StartsWith(argument, "--log-dir=")) {
      log_dir = argument + 10;
    } else if (StartsWith(argument, "--port-file=")) {
      port_file = argument + 12;
    } else if (StartsWith(argument, "-")) {
      Print::Out("Invalid option: %s.\n", argument);
      invalid_option = true;
    } else {
      // No matching option given, assume it is a snapshot.
      input = argument;
      run_snapshot = true;
    }
  }
  if (invalid_option) {
    // Don't continue if one or more invalid/unknown options were passed.
    Print::Out("\n");
    PrintUsage();
    exit(1);
  }
  bool interactive = true;

  int result = 0;

  // Check if we should add a log print interceptor.
  int pid = Platform::GetPid();
  if (log_dir != NULL) {
    // Generate a vm specific log name with the given path.
    char log_path[MAXPATHLEN + 1];
    snprintf(log_path, sizeof(log_path), "%s/vm-%d.log", log_dir, pid);
    Print::RegisterPrintInterceptor(new LogPrintInterceptor(log_path));
  }

  // Check if we're passed an snapshot file directly.
  if (run_snapshot) {
    List<uint8> bytes = Platform::LoadFile(input);
    if (bytes.is_empty()) {
      Print::Out("\n");  // Separate error from Platform::LoadFile from usage.
      PrintUsage();
      exit(1);
    }
    if (IsSnapshot(bytes)) {
      FletchProgram program = FletchLoadSnapshot(bytes.data(), bytes.length());
      result = FletchRunMain(program);
      FletchDeleteProgram(program);
      interactive = false;
    } else {
      Print::Out("The file '%s' is not a snapshot.\n\n");
      if (EndsWith(input, ".dart")) {
        Print::Out("Try: 'fletch run %s'\n\n", input);
      } else {
        PrintUsage();
      }
      exit(1);
    }
    bytes.Delete();
  }

  // If we haven't already run from a snapshot, we start an
  // interactive programming session that talks to a separate
  // compiler process.
  if (interactive) {
    // When interactive and a pid directory is specified write the port we are
    // listening on to the file vm-<pid>.port in the pid directory.
    Connection* connection = WaitForCompilerConnection(host, port, port_file);
    result = RunSession(connection);
  }

  FletchTearDown();
  return result;
}

}  // namespace fletch


// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}

#endif  // FLETCH_ENABLE_LIVE_CODING
