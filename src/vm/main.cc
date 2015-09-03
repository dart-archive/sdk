// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#include "include/fletch_api.h"

#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/utils.h"

#include "src/vm/session.h"

namespace fletch {

static bool RunSession(Connection* connection) {
  Session session(connection);
  session.Initialize();
  session.StartMessageProcessingThread();
  bool result = session.ProcessRun();
  session.JoinMessageProcessingThread();
  return result;
}

static Connection* WaitForCompilerConnection(const char* host, int port) {
  // Listen for new connections.
  ConnectionListener listener(host, port);

  Print::Out("Waiting for compiler on %s:%i\n", host, listener.Port());

  return listener.Accept();
}

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static void printUsage() {
  Print::Out("fletch-vm - The Dart virtual machine for IOT.\n\n");
  Print::Out("  fletch-vm [--port=<port>] [--host=<address>] "
             "[snaphost file]\n\n");
  Print::Out("When specifying a snapshot other options are ignored.\n\n");
  Print::Out("Options:\n");
  Print::Out("  --port: specifies which port to listen on. Defaults "
             "to random port.\n");
  Print::Out("  --host: specifies which host address to listen on. "
             "Defaults to 127.0.0.1.\n");
  Print::Out("  --help: print out 'fletch-vm' usage.\n");
  Print::Out("\n");
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  FletchSetup();

  if (argc > 5) {
    FATAL("Too many arguments.");
  } else if (argc < 1) {
    FATAL("Not enough arguments.");
  }

  // Handle the arguments.
  const char* host = "127.0.0.1";
  int port = 0;
  const char* input = NULL;

  // We run a snapshot only if the arguments contain a file name.
  bool runSnapshot = false;
  bool invalidOption = false;

  for (int i = 1; i < argc; ++i) {
    const char* argument = argv[i];
    if (strncmp(argument, "--port=", 7) == 0) {
      port = atoi(argument + 7);
    } else if (strncmp(argument, "--host=", 7) == 0) {
      host = argument + 7;
    } else if (strncmp(argument, "--help", 6) == 0) {
      printUsage();
      exit(0);
    } else if (strncmp(argument, "-", 1) == 0) {
      Print::Out("Invalid option: %s.\n", argument);
      invalidOption = true;
    } else {
      // No matching option given, assume it is a snapshot.
      input = argument;
      runSnapshot = true;
    }
  }
  if (invalidOption) {
    // Don't continue if one or more invalid/unknown options were passed.
    Print::Out("\n");
    printUsage();
    exit(1);
  }
  bool success = true;
  bool interactive = true;

  // Check if we're passed an snapshot file directly.
  if (runSnapshot) {
    List<uint8> bytes = Platform::LoadFile(input);
    if (IsSnapshot(bytes)) {
      FletchProgram program = FletchLoadSnapshot(bytes.data(), bytes.length());
      FletchRunMain(program);
      FletchDeleteProgram(program);
      interactive = false;
    }
    bytes.Delete();
  }

  // If we haven't already run from a snapshot, we start an
  // interactive programming session that talks to a separate
  // compiler process.
  if (interactive) {
    Connection* connection = WaitForCompilerConnection(host, port);
    success = RunSession(connection);
  }

  FletchTearDown();
  return success ? 0 : 1;
}

}  // namespace fletch


// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}

#endif  // FLETCH_ENABLE_LIVE_CODING
