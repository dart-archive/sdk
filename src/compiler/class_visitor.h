// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_CLASS_VISITOR_H_
#define SRC_COMPILER_CLASS_VISITOR_H_

#include "src/compiler/tree.h"

namespace fletch {

class Zone;

class ClassVisitor {
 public:
  ClassVisitor(ClassNode* class_node, Zone* zone)
      : class_node_(class_node)
      , zone_(zone) {}

  virtual ~ClassVisitor() {}

  void Visit(MethodNode* constructor);

  virtual void DoThisInitializerField(VariableDeclarationNode* node,
                                      int index,
                                      int parameter_index,
                                      bool assigned) {}

  virtual void DoListInitializerField(VariableDeclarationNode* node,
                                      int index,
                                      AssignNode* initializer,
                                      bool assigned) {}

  virtual void DoSuperInitializerField(InvokeNode* node,
                                       int parameter_count) {}

  ClassNode* class_node() const { return class_node_; }
  Zone* zone() const { return zone_; }

 private:
  ClassNode* class_node_;
  Zone* zone_;
};

}  // namespace fletch

#endif  // SRC_COMPILER_CLASS_VISITOR_H_
