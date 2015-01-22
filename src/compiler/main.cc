// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <cstdlib>

#include "src/compiler/builder.h"
#include "src/compiler/compiler.h"
#include "src/compiler/library_loader.h"
#include "src/compiler/os.h"
#include "src/compiler/session.h"

#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/fletch.h"
#include "src/shared/names.h"

namespace fletch {

void Compile(const char* lib, const char* uri, int port, const char* out) {
  Connection* connection = Connection::Connect("127.0.0.1", port);

  Zone zone;
  Builder builder(&zone, connection);
  Compiler compiler(&zone, &builder, lib);

  LibraryElement* root = NULL;
  if (!Flags::IsOn("simple-system")) {
    root = compiler.loader()->LoadLibrary(uri, uri);
    if (root == NULL) {
      Location location;
      builder.ReportError(location, "Cannot load code.");
    }
  }

  Session session(connection);
  session.BuildProgram(&compiler, root);
  if (out == NULL) {
    session.RunMain();
  } else {
    session.WriteSnapshot(out);
  }
  delete connection;
}

void ReportUsage(const char* executable) {
  fprintf(stderr,
          "Usage: %s <entry> --port=<port> [--out=<file>]\n",
          executable);
  exit(1);
}

int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  Fletch::Setup();

  if (argc < 3 || argc > 4) ReportUsage(argv[0]);
  const char* entry = argv[1];

  if (strncmp(argv[2], "--port=", 7) != 0) ReportUsage(argv[0]);
  int port = atoi(argv[2] + 7);

  const char* out = NULL;
  if (argc == 4) {
    if (strncmp(argv[3], "--out=", 6) != 0) ReportUsage(argv[0]);
    out = argv[3] + 6;
  }

  const char* lib = OS::UriResolve(argv[0], "../../lib/", NULL);
  Compile(lib, entry, port, out);
  Fletch::TearDown();
  return 0;
}

}  // namespace fletch

int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
