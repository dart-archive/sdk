// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/resolver.h"
#include "src/compiler/scope.h"

namespace fletch {

TreeNode* Resolver::ResolveIdentifier(IdentifierNode* node, Scope* scope) {
  ScopeEntry* entry = scope->Lookup(node);
  if (entry == NULL) {
    return NULL;
  } else if (entry->IsFormalParameter()) {
    return NULL;
  } else if (entry->IsMember()) {
    return entry->AsMember()->member();
  } else if (entry->IsDeclaration()) {
    return entry->AsDeclaration()->node();
  } else if (entry->IsLibrary()) {
    return NULL;
  } else {
    UNIMPLEMENTED();
  }
  return NULL;
}

TreeNode* Resolver::ResolveDot(DotNode* node, Scope* scope) {
  ScopeEntry* entry = ResolveDotEntry(node, scope);
  if (entry == NULL) {
    return NULL;
  } else if (entry->IsFormalParameter()) {
    return NULL;
  } else if (entry->IsMember()) {
    return entry->AsMember()->member();
  } else if (entry->IsDeclaration()) {
    return entry->AsDeclaration()->node();
  } else {
    UNIMPLEMENTED();
  }
  return NULL;
}

TreeNode* Resolver::Resolve(TreeNode* node, Scope* scope) {
  IdentifierNode* id = node->AsIdentifier();
  if (id != NULL) return ResolveIdentifier(id, scope);
  DotNode* dot = node->AsDot();
  if (dot != NULL) return ResolveDot(dot, scope);
  return NULL;
}

ClassNode* Resolver::ResolveSuperClass(const ClassNode* node) {
  if (!node->has_super()) return NULL;
  TreeNode* super = Resolve(node->super(), node->scope());
  if (super == NULL) return NULL;
  return super->AsClass();
}

TreeNode* Resolver::ResolveSuperMember(const ClassNode* node,
                                       IdentifierNode* name) {
  ClassNode* super = ResolveSuperClass(node);
  if (super == NULL) return NULL;
  TreeNode* member = ResolveIdentifier(name, super->scope());
  if (member == NULL) return ResolveSuperMember(super, name);
  ASSERT(!member->IsMethod() || member->AsMethod()->owner() == super);
  ASSERT(!member->IsVariableDeclaration() ||
         member->AsVariableDeclaration()->owner() == super);
  return member;
}

ScopeEntry* Resolver::ResolveIdentifierEntry(IdentifierNode* node,
                                             Scope* scope) {
  return scope->Lookup(node);
}

ScopeEntry* Resolver::ResolveDotEntry(DotNode* node, Scope* scope) {
  ScopeEntry* entry = ResolveEntry(node->object(), scope);
  if (entry == NULL) {
    return NULL;
  } else if (entry->IsDeclaration()) {
    return NULL;
  } else if (entry->IsMember()) {
    TreeNode* declaration = entry->AsMember()->member();
    if (declaration == NULL) {
      return NULL;
    }
    if (declaration->IsClass()) {
      ClassNode* clazz = declaration->AsClass();
      return ResolveIdentifierEntry(node->name(), clazz->scope());
    }
    if (declaration->IsVariableDeclaration()) {
      return NULL;
    }
  } else if (entry->IsLibrary()) {
    LibraryNode* library = entry->AsLibrary()->library();
    return ResolveIdentifierEntry(node->name(), library->scope());
  } else {
    return NULL;
  }
  UNIMPLEMENTED();
  return NULL;
}

ScopeEntry* Resolver::ResolveEntry(TreeNode* node, Scope* scope) {
  IdentifierNode* id = node->AsIdentifier();
  if (id != NULL) return ResolveIdentifierEntry(id, scope);
  DotNode* dot = node->AsDot();
  if (dot != NULL) return ResolveDotEntry(dot, scope);
  return NULL;
}

}  // namespace fletch
