// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_GENERATOR_H_
#define SRC_VM_GENERATOR_H_

namespace fletch {

class Assembler;

#define GENERATE(p, n)                                           \
  static void Generate##p##n(Assembler* assembler);              \
  static const Generator kRegister##p##n(Generate##p##n, #p #n); \
  static void Generate##p##n(Assembler* assembler)

#define GENERATE_NATIVE(n) GENERATE(Native_, n)

class Generator {
 public:
  typedef void(Function)(Assembler*);

  Generator(Function* function, const char* name);

  const char* name() const { return name_; }

  void Generate(Assembler* assembler);
  static void GenerateAll(Assembler* assembler);

 private:
  static Generator* first_;
  static Generator* current_;
  Generator* next_;

  Function* const function_;
  const char* name_;

  DISALLOW_COPY_AND_ASSIGN(Generator);
};

}  // namespace fletch

#endif  // SRC_VM_GENERATOR_H_
