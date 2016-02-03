// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/vm/assembler.h"
#include "src/vm/generator.h"

namespace dartino {

Generator* Generator::first_ = NULL;
Generator* Generator::current_ = NULL;

Generator::Generator(Function* function, const char* name)
    : next_(NULL), function_(function), name_(name) {
  if (first_ == NULL) {
    first_ = this;
  } else {
    current_->next_ = this;
  }
  current_ = this;
}

void Generator::Generate(Assembler* assembler) {
  assembler->Bind("", name());
  (*function_)(assembler);
}

void Generator::GenerateAll(Assembler* assembler) {
  Generator* generator = first_;
  while (generator != NULL) {
    generator->Generate(assembler);
    generator = generator->next_;
  }
}

static int Main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <output file name>\n", argv[0]);
    exit(1);
  }
  if (freopen(argv[1], "w", stdout) == NULL) {
    fprintf(stderr, "%s: Cannot open '%s' for writing.\n", argv[0], argv[1]);
    exit(1);
  }

  Assembler assembler;
  Generator::GenerateAll(&assembler);
  return 0;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) { return dartino::Main(argc, argv); }
