// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "include/fletch_api.h"

#include "src/shared/bytecodes.h"
#include "src/shared/selectors.h"

#include "src/vm/assembler.h"
#include "src/vm/codegen.h"

namespace fletch {

static int Main(int argc, char** argv) {
  if (argc != 3) {
    fprintf(stderr, "Usage: %s <snapshot> <output file name>\n", argv[0]);
    exit(1);
  }

  if (freopen(argv[2], "w", stdout) == NULL) {
    fprintf(stderr, "%s: Cannot open '%s' for writing.\n", argv[0], argv[2]);
    exit(1);
  }

  FletchSetup();
  FletchProgram api_program = FletchLoadSnapshotFromFile(argv[1]);

  Assembler assembler;
  Program* program = reinterpret_cast<Program*>(api_program);
  Array* methods = program->static_methods();
  for (int i = 0; i < methods->length(); i++) {
    Codegen codegen(program, Function::cast(methods->get(i)), &assembler);
    codegen.Generate();
  }

  FletchDeleteProgram(api_program);
  FletchTearDown();
  return 0;
}

void Codegen::Generate() {
  DoEntry();

  int bci = 0;
  while (bci < function_->bytecode_size()) {
    uint8* bcp = function_->bytecode_address_for(bci);
    Opcode opcode = static_cast<Opcode>(*bcp);

    switch (opcode) {
      case kLoadLocal0:
      case kLoadLocal1:
      case kLoadLocal2:
      case kLoadLocal3:
      case kLoadLocal4:
      case kLoadLocal5: {
        DoLoadLocal(opcode - kLoadLocal0);
        break;
      }

      case kLoadLocal: {
        DoLoadLocal(*(bcp + 1));
        break;
      }

      case kLoadLocalWide: {
        DoLoadLocal(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kStoreLocal: {
        DoStoreLocal(*(bcp + 1));
        break;
      }

      case kLoadLiteralNull: {
        DoLoadProgramRoot(Program::kNullObjectOffset);
        break;
      }

      case kLoadLiteralTrue: {
        DoLoadProgramRoot(Program::kTrueObjectOffset);
        break;
      }

      case kLoadLiteralFalse: {
        DoLoadProgramRoot(Program::kFalseObjectOffset);
        break;
      }

      case kLoadLiteral0:
      case kLoadLiteral1: {
        DoLoadInteger(opcode - kLoadLiteral0);
        break;
      }

      case kLoadLiteral: {
        DoLoadInteger(*(bcp + 1));
        break;
      }

      case kLoadLiteralWide: {
        DoLoadInteger(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kLoadConst: {
        DoLoadProgramConstant(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kInvokeMethod: {
        int selector = Utils::ReadInt32(bcp + 1);
        int arity = Selector::ArityField::decode(selector);
        int offset = Selector::IdField::decode(selector);
        DoInvokeMethod(arity, offset);
        break;
      }

      case kPop: {
        DoDrop(1);
        break;
      }

      case kDrop: {
        DoDrop(*(bcp + 1));
        break;
      }

      case kReturn: {
        DoReturn();
        break;
      }

      case kReturnNull: {
        DoLoadProgramRoot(Program::kNullObjectOffset);
        DoReturn();
        break;
      }

      case kMethodEnd: {
        return;
      }

      default: {
        printf("\t// Unhandled: ");
        Bytecode::Print(bcp);
        printf("\n");
        break;
      }
    }

    bci += Bytecode::Size(opcode);
  }
}

}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
