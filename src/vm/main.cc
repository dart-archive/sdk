// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/fletch.h"
#include "src/shared/native_process.h"

#include "src/vm/platform.h"
#include "src/vm/program.h"
#include "src/vm/session.h"
#include "src/vm/snapshot.h"

namespace fletch {

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static Program* ReadFromSnapshot(List<uint8> snapshot) {
  ASSERT(IsSnapshot(snapshot));
  SnapshotReader reader(snapshot);
  Program* program = reader.ReadProgram();
  return program;
}

static bool RunBridgeSession(int port) {
  Connection* connection = Connection::Connect("127.0.0.1", port);
  Session session(connection);
  session.Initialize();
  session.StartMessageProcessingThread();
  return session.RunMain();
}

static bool RunSession(const char* argv0,
                       const char* input,
                       const char* out,
                       bool compile) {
  // Listen for new connections.
  ConnectionListener listener("127.0.0.1", 0);

  // Prepare the executable argument.
  int executable_length = strlen(argv0) + 2;
  char* executable = static_cast<char*>(malloc(executable_length));
  snprintf(executable, executable_length, "%sc", argv0);

  // Prepare the --port=1234 argument.
  char port[256];
  snprintf(port, ARRAY_SIZE(port), "--port=%d", listener.Port());

  const char* args[4] = { executable, input, port, NULL };
  const char* args_out[5] = { executable, input, port, out, NULL };

  NativeProcess process(executable, compile ? args_out : args);
  process.Start();

  Session session(listener.Accept());
  session.Initialize();
  session.StartMessageProcessingThread();
  bool success = session.RunMain();

  process.Wait();
  free(executable);
  return success;
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  Fletch::Setup();

  if (argc > 3) {
    FATAL("Too many arguments.");
  } else if (argc < 2) {
    FATAL("Not enough arguments.");
  }

  // Handle the arguments.
  bool compile = false;
  bool bridge_session = false;
  const char* input = argv[1];
  const char* out = NULL;

  if (strncmp(input, "--port=", 7) == 0) {
    compile = true;
    bridge_session = true;
  } else if (argc > 2) {
    if (strncmp(argv[2], "--out=", 6) == 0) {
      compile = true;
      out = argv[2];
    } else {
      FATAL("Too many arguments.");
    }
  }

  bool success = true;
  bool interactive = true;

  // Check if we're passed an snapshot file directly.
  if (!compile) {
    List<uint8> snapshot = Platform::LoadFile(input);
    if (IsSnapshot(snapshot)) {
      Program* program = ReadFromSnapshot(snapshot);
      success = program->RunMainInNewProcess();
      interactive = false;
    }
    snapshot.Delete();
  }

  // If we haven't already run from a snapshot, we start an
  // interactive programming session that talks to a separate
  // compiler process.
  if (interactive) {
    if (bridge_session) {
      success = RunBridgeSession(atoi(input + 7));
    } else {
      success = RunSession(argv[0], input, out, compile);
    }
  }

  Fletch::TearDown();
  return success ? 0 : 1;
}

}  // namespace fletch


// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
