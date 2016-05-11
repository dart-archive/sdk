// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_FOLDER_NO_LIVE_CODING_H_
#define SRC_VM_PROGRAM_FOLDER_NO_LIVE_CODING_H_

#ifndef SRC_VM_PROGRAM_FOLDER_H_
#error "Do not import program_folder_no_live_coding.h directly, "
    "import program_folder.h"
#endif  // SRC_VM_PROGRAM_FOLDER_H_

namespace dartino {

class Program;

// ProgramFolder used for folding and unfolding a Program.
class ProgramFolder {
 public:
  explicit ProgramFolder(Program* program) : program_(program) {
    UNIMPLEMENTED();
  }

  void Fold() {
    UNIMPLEMENTED();
  }

  void Unfold() {
    UNIMPLEMENTED();
  }

  Program* program() const {
    UNIMPLEMENTED();
    return NULL;
  }

  static void FoldProgramByDefault(Program* program) {
     UNIMPLEMENTED();
  }

 private:
  Program* const program_;
};

}  // namespace dartino

#endif  // SRC_VM_PROGRAM_FOLDER_NO_LIVE_CODING_H_
