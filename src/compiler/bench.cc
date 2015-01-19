// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/compiler/builder.h"
#include "src/compiler/compiler.h"
#include "src/compiler/emitter.h"
#include "src/shared/flags.h"
#include "src/shared/fletch.h"
#include "src/shared/globals.h"
#include "src/compiler/os.h"
#include "src/compiler/scanner.h"

namespace fletch {

void Scan(const char* filename) {
  Zone zone;

  Builder builder(&zone);
  Location location = builder.source()->LoadFile(filename);

  const char* source = builder.source()->GetSource(location);

  printf("Compiling %s (%d bytes)\n",
         filename,
         static_cast<int>(strlen(source)));

  // Scan the file.
  const int kIterations = 10000;
  int64 start = OS::CurrentTime();
  for (int i = 0; i < kIterations; i++) {
    Zone zone;
    Scanner scanner(&builder, &zone);
    scanner.Scan(source, location);
  }
  int64 end = OS::CurrentTime();
  int64 scanTime = (end - start) / kIterations;
  printf("  - scanned in %" PRId64 " us.\n", scanTime);

  // Parse it.
  start = OS::CurrentTime();
  for (int i = 0; i < kIterations; i++) {
    Zone zone;
    Builder builder(&zone);
    builder.BuildUnit(location);
  }
  end = OS::CurrentTime();
  int64 parseTime = (end - start) / kIterations;
  printf("  - parsed in %" PRId64 " us.\n", parseTime - scanTime);

  // Compile it.
  int bytes = 0;
  start = OS::CurrentTime();
  for (int i = 0; i < kIterations; i++) {
    Zone zone;
    Builder builder(&zone);
    CompilationUnitNode* unit = builder.BuildUnit(location);
    MethodNode* method = unit->declarations()[0]->AsMethod();
    Compiler compiler(&zone, &builder, "");
    Emitter emitter(&zone, method->parameters().length());
    compiler.CompileMethod(method, &emitter);
    if (i == 0) {
      bytes = emitter.GetCode()->bytes().length();
    }
  }
  end = OS::CurrentTime();
  int64 compileTime = (end - start) / kIterations;
  printf("  - compiled in %" PRId64 " us.\n", compileTime - parseTime);
  printf("Total time: %" PRId64 " us (output = %d bytes).\n",
      compileTime, bytes);
}

}  // namespace fletch

int main(int argc, char** argv) {
  fletch::Flags::ExtractFromCommandLine(&argc, argv);
  fletch::Fletch::Setup();
  for (int i = 1; i < argc; i++) fletch::Scan(argv[i]);
  fletch::Fletch::TearDown();
  return 0;
}
