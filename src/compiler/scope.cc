// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/builder.h"
#include "src/compiler/scope.h"

namespace fletch {

Scope::Scope(Zone* zone, int n, Scope* outer)
    : IdMap(zone, n)
    , outer_(outer)
    , locals_(0) {
}

int Scope::TotalLocals() const {
  const Scope* scope = this;
  int result = 0;
  do {
    result += scope->locals();
    scope = scope->outer();
  } while (scope != NULL);
  return result;
}

void Scope::AddLocalVariable(IdentifierNode* name, DeclarationEntry* entry) {
  entry->set_index(TotalLocals());
  locals_++;
  Add(name, entry);
}

void Scope::AddDeclaration(IdentifierNode* name, TreeNode* node) {
  Add(name, new(zone()) DeclarationEntry(node));
}

void Scope::Add(int id, ScopeEntry* entry) {
  IdMap::Add(id, entry);
}

void Scope::AddAll(Scope* scope) {
  // TODO(ajohnsen): Fail on duplicates.
  ASSERT(zone() == scope->zone());
  int capacity = scope->table_.length();
  for (int i = 0; i < capacity; i++) {
    int id = scope->table_[i].id;
    if (id != -1) {
      if (!Contains(id)) Add(id, scope->table_[i].value);
    }
  }
}

ScopeEntry* Scope::Lookup(int id) const {
  const Scope* scope = this;
  int depth = 0;
  do {
    ScopeEntry* result = scope->IdMap::Lookup(id);
    if (result != NULL) return result;
    scope = scope->outer();
    depth++;
  } while (scope != NULL);
  return NULL;
}

ScopeEntry* Scope::LookupLocal(int id) const {
  return IdMap::Lookup(id);
}

void Scope::Print(const char* name, Builder* builder) {
  printf("Scope %s:\n", name);
  Scope* scope = this;
  int depth = 0;
  do {
    scope->PrintLocally(builder, depth);
    scope = scope->outer();
    depth++;
  } while (scope != NULL);
}

void Scope::PrintLocally(Builder* builder, int depth) {
  printf(" [%d: size = %d]:\n", depth, size());
  for (int i = 0; i < table_.length(); i++) {
    int id = table_[i].id;
    if (id != -1) {
      IdentifierNode* identifier = builder->Lookup(id)->AsIdentifier();
      printf("  %s -> %p\n", identifier->value(), table_[i].value);
    }
  }
}

}  // namespace fletch
