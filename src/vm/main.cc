// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#include "include/fletch_api.h"

#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/native_process.h"

#include "src/vm/session.h"

namespace fletch {

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
                       const char* library_path,
                       const char* package_root,
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

  const char* args[6] =
      { executable, input, port, library_path, package_root, NULL };
  const char* args_out[7] =
      { executable, input, port, out, library_path, package_root, NULL };

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

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  FletchSetup();

  if (argc > 5) {
    FATAL("Too many arguments.");
  } else if (argc < 2) {
    FATAL("Not enough arguments.");
  }

  // Handle the arguments.
  bool compile = false;
  bool bridge_session = false;
  const char* input = argv[1];
  const char* out = NULL;
  const char* library_path = NULL;
  const char* package_root = NULL;

  if (strncmp(input, "--port=", 7) == 0) {
    compile = true;
    bridge_session = true;
  } else if (argc > 2) {
    for (int i = 2; i < argc; i++) {
      if (strncmp(argv[i], "--out=", 6) == 0) {
        compile = true;
        out = argv[i];
      } else if (strncmp(argv[i], "--lib=", 6) == 0) {
        library_path = argv[i];
      } else if (strncmp(argv[i], "--packages=", 11) == 0) {
        package_root = argv[i];
      }
    }
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
    if (bridge_session) {
      success = RunBridgeSession(atoi(input + 7));
    } else {
      success =
          RunSession(argv[0], input, out, library_path, package_root, compile);
    }
  }

  FletchTearDown();
  return success ? 0 : 1;
}

}  // namespace fletch


// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
