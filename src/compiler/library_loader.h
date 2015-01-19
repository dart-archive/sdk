// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_LIBRARY_LOADER_H_
#define SRC_COMPILER_LIBRARY_LOADER_H_

#include "src/compiler/builder.h"
#include "src/compiler/list_builder.h"
#include "src/compiler/map.h"

namespace fletch {

class LibraryElement : public ZoneAllocated {
 public:
  LibraryElement(int id,
                 LibraryNode* library,
                 Scope* outer_library_scope)
      : library_(library)
      , outer_library_scope_(outer_library_scope) {
  }

  void AddImportOf(LibraryElement* element);
  void AddImportOf(LibraryElement* element, IdentifierNode* prefix, Zone* zone);

  LibraryNode* library() const { return library_; }
  Scope* outer_library_scope() const { return outer_library_scope_; }

 private:
  LibraryNode* const library_;
  Scope* const outer_library_scope_;

  friend class LibraryLoader;
};

class LibraryLoader : public StackAllocated {
 public:
  explicit LibraryLoader(Builder* builder, const char* library_root);

  LibraryElement* LoadLibrary(const char* library_name, const char* source_uri);

  LibraryElement* FetchLibrary(const char* name);

  Builder* builder() const { return builder_; }
  Zone* zone() const { return builder()->zone(); }
  const char* library_root() const { return library_root_; }

 private:
  Builder* builder_;
  IdMap<LibraryElement*> library_map_;
  const char* library_root_;

  LibraryElement* LookupLibrary(IdentifierNode* library_name);
  LibraryNode* BuildLibrary(const char* source_uri) const;
  Scope* BuildLibraryScope(LibraryNode* library, Scope* outer);
  void AddSetterToScope(Scope* scope, MethodNode* method);
  void AddMemberToScope(Scope* scope, IdentifierNode* name, TreeNode* node);
  void PopulateScope(LibraryNode* library,
                     CompilationUnitNode* unit,
                     Scope* scope);
  void PopulateScope(ClassNode* clazz, Scope* scope);
};

}  // namespace fletch

#endif  // SRC_COMPILER_LIBRARY_LOADER_H_

