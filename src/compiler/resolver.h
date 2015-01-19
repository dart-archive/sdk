// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_RESOLVER_H_
#define SRC_COMPILER_RESOLVER_H_

#include "src/compiler/tree.h"

namespace fletch {

class Scope;
class ScopeEntry;

class Resolver {
 public:
  static TreeNode* ResolveIdentifier(IdentifierNode* node, Scope* scope);
  static TreeNode* ResolveDot(DotNode* node, Scope* scope);
  static TreeNode* Resolve(TreeNode* node, Scope* scope);
  static ClassNode* ResolveSuperClass(const ClassNode* node);
  static TreeNode* ResolveSuperMember(const ClassNode* node,
                                      IdentifierNode* name);

  static ScopeEntry* ResolveIdentifierEntry(IdentifierNode* node, Scope* scope);
  static ScopeEntry* ResolveDotEntry(DotNode* node, Scope* scope);
  static ScopeEntry* ResolveEntry(TreeNode* node, Scope* scope);
};

}  // namespace fletch

#endif  // SRC_COMPILER_RESOLVER_H_
