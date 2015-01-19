// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/class_visitor.h"
#include "src/compiler/list_builder.h"
#include "src/compiler/map.h"
#include "src/compiler/resolver.h"

namespace fletch {

struct Field : public ZoneAllocated {
  Field(VariableDeclarationNode* var, bool assigned, int index)
      : var(var), assigned(assigned), index(index) { }
  VariableDeclarationNode* var;
  bool assigned;
  int index;
};

void ClassVisitor::Visit(MethodNode* constructor) {
  ListBuilder<VariableDeclarationNode*, 2> fields_builder(zone());
  List<TreeNode*> declarations = class_node()->declarations();
  IdMap<Field*> fields(zone(), 0);
  for (int i = 0; i < declarations.length(); i++) {
    VariableDeclarationStatementNode* decl =
        declarations[i]->AsVariableDeclarationStatement();
    if (decl == NULL) continue;
    List<VariableDeclarationNode*> vars = decl->declarations();
    for (int j = 0; j < vars.length(); j++) {
      VariableDeclarationNode* var = vars[j];
      if (var->modifiers().is_static()) continue;
      Field* field = new(zone()) Field(var,
                                       false,
                                       fields.size());
      fields.Add(var->name()->id(), field);
    }
  }

  List<VariableDeclarationNode*> parameters = constructor->parameters();
  for (int i = 0; i < parameters.length(); i++) {
    VariableDeclarationNode* parameter = parameters[i];
    if (parameter->modifiers().is_this()) {
      int id = parameter->name()->id();
      if (fields.Contains(id)) {
        Field* field = fields.Lookup(id);
        DoThisInitializerField(field->var, field->index, i, field->assigned);
        field->assigned = true;
      } else {
        UNIMPLEMENTED();
      }
    }
  }

  bool seen_super = false;
  List<TreeNode*> initializers = constructor->initializers();
  for (int i = 0; i < initializers.length(); i++) {
    TreeNode* initializer = initializers[i];
    InvokeNode* invoke = initializer->AsInvoke();
    AssignNode* assign = initializer->AsAssign();
    if (invoke != NULL) {
      if (!invoke->target()->IsSuper()) {
        DotNode* dot = invoke->target()->AsDot();
        if (dot == NULL) UNIMPLEMENTED();
        if (!dot->object()->IsSuper()) UNIMPLEMENTED();
      }
      if (seen_super) UNIMPLEMENTED();
      DoSuperInitializerField(invoke, parameters.length());
      seen_super = true;
    } else if (assign != NULL) {
      TreeNode* target = assign->target();
      if (target->IsDot()) {
        ASSERT(target->AsDot()->object()->IsThis());
        target = target->AsDot()->name();
      }
      target = Resolver::Resolve(target, class_node()->scope());
      if (target == NULL) UNIMPLEMENTED();
      VariableDeclarationNode* var = target->AsVariableDeclaration();
      if (var == NULL) UNIMPLEMENTED();
      if (var->owner() != class_node()) UNIMPLEMENTED();
      int id = var->name()->id();
      if (fields.Contains(id)) {
        Field* field = fields.Lookup(id);
        DoListInitializerField(field->var,
                               field->index,
                               assign,
                               field->assigned);
        field->assigned = true;
      } else {
        UNIMPLEMENTED();
      }
    } else {
      UNIMPLEMENTED();
    }
  }
  if (class_node()->has_super() && !seen_super) {
    DoSuperInitializerField(NULL, parameters.length());
  }
}

}  // namespace fletch
