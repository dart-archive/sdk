// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_SCOPE_H_
#define SRC_COMPILER_SCOPE_H_

#include "src/compiler/map.h"
#include "src/compiler/tree.h"
#include "src/compiler/zone.h"

namespace fletch {

class ScopeEntry;
class LibraryEntry;
class MemberEntry;
class FormalParameterEntry;
class LocalVariableEntry;
class DeclarationEntry;
class Builder;

class Scope : public IdMap<ScopeEntry*> {
 public:
  Scope(Zone* zone, int n, Scope* outer);

  Scope* outer() const { return outer_; }

  int locals() const { return locals_; }
  int TotalLocals() const;

  void Add(int id, ScopeEntry* definition);
  void Add(IdentifierNode* name, ScopeEntry* entry) {
    Add(name->id(), entry);
  }

  void AddAll(Scope* scope);

  void AddLocalVariable(IdentifierNode* name, DeclarationEntry* entry);
  void AddDeclaration(IdentifierNode* name, TreeNode* node);

  ScopeEntry* Lookup(int id) const;
  ScopeEntry* Lookup(IdentifierNode* name) const {
    return Lookup(name->id());
  }
  ScopeEntry* LookupLocal(int id) const;
  ScopeEntry* LookupLocal(IdentifierNode* name) const {
    return LookupLocal(name->id());
  }

  void Print(const char* name, Builder* builder);

 private:
  Scope* const outer_;
  int locals_;

  void PrintLocally(Builder* builder, int depth);
};

class ScopeEntry : public ZoneAllocated {
 public:
  virtual bool IsLibrary() const { return false; }
  virtual bool IsMember() const { return false; }
  virtual bool IsFormalParameter() const { return false; }
  virtual bool IsDeclaration() const { return false; }
  virtual LibraryEntry* AsLibrary() { return NULL; }
  virtual MemberEntry* AsMember() { return NULL; }
  virtual FormalParameterEntry* AsFormalParameter() { return NULL; }
  virtual DeclarationEntry* AsDeclaration() { return NULL; }
};

class LibraryEntry : public ScopeEntry {
 public:
  LibraryEntry(IdentifierNode* name, LibraryNode* library)
      : name_(name), library_(library) { }

  virtual bool IsLibrary() const { return true; }
  virtual LibraryEntry* AsLibrary() { return this; }

  IdentifierNode* name() const { return name_; }
  LibraryNode* library() const { return library_; }

 private:
  IdentifierNode* const name_;
  LibraryNode* const library_;
};

class MemberEntry : public ScopeEntry {
 public:
  explicit MemberEntry(IdentifierNode* name)
      : name_(name)
      , member_(NULL)
      , setter_(NULL) { }

  virtual bool IsMember() const { return true; }
  virtual MemberEntry* AsMember() { return this; }

  bool has_member() const { return member_ != NULL; }
  bool has_setter() const { return setter_ != NULL; }

  IdentifierNode* name() const { return name_; }
  TreeNode* member() const { return member_; }
  MethodNode* setter() const { return setter_; }

  void set_member(TreeNode* node) { member_ = node; }
  void set_setter(MethodNode* node) { setter_ = node; }

 private:
  IdentifierNode* const name_;
  TreeNode* member_;
  MethodNode* setter_;
};

class FormalParameterEntry : public ScopeEntry {
 public:
  explicit FormalParameterEntry(int index) : index_(index) { }

  virtual bool IsFormalParameter() const { return true; }
  virtual FormalParameterEntry* AsFormalParameter() { return this; }

  int index() const { return index_; }

 private:
  const int index_;
};

class DeclarationEntry : public ScopeEntry {
 public:
  explicit DeclarationEntry(TreeNode* node)
      : node_(node)
      , index_(-1)
      , captured_(kNotCaptured) { }

  virtual bool IsDeclaration() const { return true; }
  virtual DeclarationEntry* AsDeclaration() { return this; }

  TreeNode* node() const { return node_; }

  int index() const { return index_; }
  void set_index(int value) { index_ = value; }

  bool IsCaptured() const { return captured_ != kNotCaptured; }
  bool IsCapturedByValue() const { return captured_ == kCapturedByValue; }
  bool IsCapturedByReference() const {
    return captured_ == kCapturedByReference;
  }
  void MarkCapturedByValue() {
    if (captured_ == kNotCaptured) captured_ = kCapturedByValue;
  }
  void MarkCapturedByReference() { captured_ = kCapturedByReference; }

 private:
  enum Captured {
    kNotCaptured,
    kCapturedByValue,
    kCapturedByReference,
  };

  TreeNode* const node_;
  int index_;
  Captured captured_;
};

}  // namespace fletch

#endif  // SRC_COMPILER_SCOPE_H_
