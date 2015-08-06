// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

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

static Connection* ConnectToExistingCompiler(int port) {
  return Connection::Connect("127.0.0.1", port);
}

static Connection* WaitForCompilerConnection() {
  const char* host = "127.0.0.1";
  // Listen for new connections.
  ConnectionListener listener(host, 0);

  Print::Out("Waiting for compiler on %s:%i\n", host, listener.Port());

  return listener.Accept();
}

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
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
  bool compile = false;
  bool attach_to_existing_compiler = false;
  const char* input = NULL;

  if (argc > 1) {
    input = argv[1];
    if (strncmp(input, "--port=", 7) == 0) {
      compile = true;
      attach_to_existing_compiler = true;
    }
  } else {
    compile = true;
  }

  bool success = true;
  bool interactive = true;

  // Check if we're passed an snapshot file directly.
  if (!compile) {
    List<uint8> bytes = Platform::LoadFile(input);
    if (IsSnapshot(bytes)) {
      FletchRunSnapshot(bytes.data(), bytes.length());
      interactive = false;
    }
    bytes.Delete();
  }

  // If we haven't already run from a snapshot, we start an
  // interactive programming session that talks to a separate
  // compiler process.
  if (interactive) {
    Connection* connection = attach_to_existing_compiler
      ? ConnectToExistingCompiler(atoi(input + 7))
      : WaitForCompilerConnection();
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
