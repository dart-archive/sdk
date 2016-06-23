// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef DARTINO_ENABLE_DEBUGGING

#include <stddef.h>  // for size_t

#include "include/dartino_api.h"
#include "include/socket_connection_api.h"

#include "src/shared/flags.h"
#include "src/shared/utils.h"
#include "src/shared/version.h"
#include "src/shared/platform.h"
#include "src/shared/globals.h"

#include "src/vm/session.h"
#include "src/vm/log_print_interceptor.h"

namespace dartino {

static DartinoConnection WaitForCompilerConnection(
    const char* host, int port, const char* port_file) {
  DartinoSocketConnectionListener listener =
      DartinoCreateSocketConnectionListener(host, port);

  int actual_port = DartinoSocketConnectionListenerPort(listener);

  Print::Out("Waiting for compiler on %s:%i\n", host, actual_port);

  if (port_file != NULL) {
    char value_string[20];
    snprintf(value_string, sizeof(value_string), "%d", actual_port);
    Platform::WriteText(port_file, value_string, false);
  }
  DartinoConnection connection =
      DartinoSocketConnectionListenerAccept(listener);

  DartinoDeleteSocketConnectionListener(listener);
  return connection;
}

struct ConnectionArguments {
  const char* host;
  int port;
  const char* port_file;
};

static DartinoConnection WaitForCompilerConnectionCallback(void* data) {
  ConnectionArguments* arguments = reinterpret_cast<ConnectionArguments*>(data);
  return WaitForCompilerConnection(
      arguments->host, arguments->port, arguments->port_file);
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

static void PrintUsage() {
  Print::Out("dartino-vm - The embedded Dart virtual machine.\n\n");
  Print::Out("Run snapshot non-interactively:\n");
  Print::Out("  dartino-vm snapshot-file\n\n");
  Print::Out("Run snapshot interactively, waiting for debugger-connection:\n");
  Print::Out("  dartino-vm --interactive [--port=<port>] "
      "[--host=<address>] snapshot-file\n\n");
  Print::Out("Run snapshot interactively, run right away:\n");
  Print::Out("  dartino-vm --interactive --no-wait [--port=<port>] "
      "[--host=<address>] snapshot-file\n\n");
  Print::Out("Run interactively without snapshot:\n");
  Print::Out("  dartino-vm [--interactive] [--port=<port>] "
      "[--host=<address>]\n\n");

  Print::Out("Options:\n");
  Print::Out(
      "  --interactive: tells the VM to listen for a debugger connection on \n"
      "    the specified port and host.\n"
      "    This is the default when no snapshot file is given.\n");
  Print::Out(
      "  --no-wait: start running the program before a connection is "
      "obtained.\n");
  Print::Out(
      "  --host: specifies which host address to listen on. "
      "Defaults to 127.0.0.1.\n");
  Print::Out(
      "  --port: specifies which port to listen on. Defaults "
      "to a random available port.\n");
  Print::Out("  --help: print out 'dartino-vm' usage.\n");
  Print::Out("  --version: print the version.\n");
  Print::Out("\n");
}

static void PrintVersion() { Print::Out("%s\n", GetVersion()); }

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  DartinoSetup();

  if (argc < 1) {
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

  // Skip program name;
  argc--;
  argv++;

  bool interactive = false;
  bool wait_for_connection = true;

  // Process all options including the snapshot file name.
  while (argc > 0) {
    const char* argument = argv[0];
    argc--;
    argv++;
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
    } else if (strcmp(argument, "--interactive") == 0) {
      interactive = true;
    } else if (strcmp(argument, "--no-wait") == 0) {
      wait_for_connection = false;
    } else if (StartsWith(argument, "-")) {
      Print::Out("Invalid option: %s.\n", argument);
      invalid_option = true;
    } else {
      // No matching option given, assume it is a snapshot.
      input = argument;
      run_snapshot = true;
    }
  }

  if (!run_snapshot && !wait_for_connection) {
    Print::Out("Invalid option: '--no-wait' requires a snapshot.");
    invalid_option = true;
  }

  if (invalid_option) {
    // Don't continue if one or more invalid/unknown options were passed.
    Print::Out("\n");
    PrintUsage();
    exit(1);
  }

  int result = 0;

  // Check if we should add a log print interceptor.
  if (log_dir != NULL) {
    int pid = Platform::GetPid();
    // Generate a vm specific log name with the given path.
    char log_path[MAXPATHLEN + 1];
    Platform::FormatString(log_path, sizeof(log_path), "%s/vm-%d.log",
                           log_dir, pid);
    Print::RegisterPrintInterceptor(new LogPrintInterceptor(log_path));
  }

  DartinoProgram program;

  // Check if we're passed an snapshot file directly.
  if (run_snapshot) {
    List<uint8> bytes = Platform::LoadFile(input);
    if (bytes.is_empty()) {
      Print::Out("\n");  // Separate error from Platform::LoadFile from usage.
      PrintUsage();
      exit(1);
    }
    if (IsSnapshot(bytes)) {
      program = DartinoLoadSnapshot(bytes.data(), bytes.length());
    } else {
      Print::Out("The file '%s' is not a snapshot.\n\n");
      if (EndsWith(input, ".dart")) {
        Print::Out("Try: 'dartino run %s'\n\n", input);
      } else {
        PrintUsage();
      }
      exit(1);
    }
    bytes.Delete();
  } else {
    dartino::Program *p =
        new dartino::Program(dartino::Program::kBuiltViaSession);
    p->Initialize();
    program = reinterpret_cast<DartinoProgram>(p);
    // If there was no snapshot, run in interactive mode.
    interactive = true;
  }

  if (interactive) {
    struct ConnectionArguments* listener_arguments = new ConnectionArguments();
    listener_arguments->host = host;
    listener_arguments->port = port;
    listener_arguments->port_file = port_file;
    result = DartinoRunWithDebuggerConnection(
        program,
        WaitForCompilerConnectionCallback,
        listener_arguments,
        wait_for_connection);
    delete listener_arguments;
  } else {
    // Otherwise, run the program.
    result = DartinoRunMain(program, argc, argv);
  }

  DartinoDeleteProgram(program);

  DartinoTearDown();
  return result;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) { return dartino::Main(argc, argv); }

#endif  // DARTINO_ENABLE_DEBUGGING
