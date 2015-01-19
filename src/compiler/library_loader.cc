// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/shared/flags.h"
#include "src/compiler/library_loader.h"
#include "src/compiler/os.h"
#include "src/compiler/scope.h"

namespace fletch {

void LibraryElement::AddImportOf(LibraryElement* element) {
  // TODO(ajohnsen): Use export scope.
  // TODO(ajohnsen): Use two layers, one for 'dart:', one for the remaining.
  outer_library_scope()->AddAll(element->library()->scope());
}

void LibraryElement::AddImportOf(LibraryElement* element,
                                 IdentifierNode* prefix,
                                 Zone* zone) {
  // TODO(ajohnsen): Use export scope.
  // TODO(ajohnsen): Use two layers, one for 'dart:', one for the remaining.
  LibraryEntry* entry = new(zone) LibraryEntry(prefix, element->library());
  outer_library_scope()->Add(prefix->id(), entry);
}

LibraryLoader::LibraryLoader(Builder* builder, const char* library_root)
    : builder_(builder),
      library_map_(builder->zone(), 0),
      library_root_(library_root) {
}

LibraryElement* LibraryLoader::LoadLibrary(
    const char* library_name,
    const char* source_uri) {
  IdentifierNode* identifier = builder()->Canonicalize(library_name);
  LibraryElement* element = LookupLibrary(identifier);
  if (element != NULL) return element;

  if (Flags::IsOn("trace_library")) {
    printf("Loading library '%s' from '%s'\n", library_name, source_uri);
  }

  LibraryNode* library = BuildLibrary(source_uri);
  if (library == NULL) return NULL;

  Scope* outer_library_scope = new(zone()) Scope(zone(), 0, NULL);
  Scope* library_scope = BuildLibraryScope(library, outer_library_scope);
  library->set_scope(library_scope);

  // Set library now, so we handle circular imports.
  int id = identifier->id();
  element = new(zone()) LibraryElement(id, library, outer_library_scope);
  library_map_.Add(id, element);

  if (Flags::IsOn("trace_library")) {
    printf("Loaded '%s' as %i\n", library_name, id);
  }

  // Add implicit import of dart:core.
  if (strcmp(library_name, "dart:core") != 0) {
    const char* core_source_uri =
        OS::UriResolve(library_root(), "core/core.dart", builder()->zone());
    LibraryElement* core = LoadLibrary("dart:core", core_source_uri);
    element->AddImportOf(core);
  }

  // Add implicit import of dart:system in dart:*.
  if (strncmp(library_name, "dart:", 5) == 0) {
    const char* system_source_uri =
        OS::UriResolve(library_root(), "system/system.dart", builder()->zone());
    LibraryElement* system = LoadLibrary("dart:system", system_source_uri);
    element->AddImportOf(system);
  }

  CompilationUnitNode* unit = library->unit();
  List<TreeNode*> declarations = unit->declarations();
  for (int i = 0; i < declarations.length(); i++) {
    if (declarations[i]->IsImport()) {
      ImportNode* import = declarations[i]->AsImport();
      const char* import_path = import->uri()->value();
      LibraryElement* imported_library = NULL;
      if (strncmp(import_path, "dart:", 5) == 0) {
        const char* io_lib = import_path + 5;
        int length = snprintf(NULL, 0, "%s/%s.dart", io_lib, io_lib);
        char* sub_path = reinterpret_cast<char*>(zone()->Allocate(length + 1));
        snprintf(sub_path, length + 1, "%s/%s.dart", io_lib, io_lib);
        const char* import_uri = OS::UriResolve(library_root(),
                                                sub_path,
                                                zone());
        imported_library = LoadLibrary(import_path, import_uri);
      } else {
        const char* resolve_uri = source_uri;
        if (strncmp(import_path, "package:", 8) == 0) {
          import_path += 8;
          resolve_uri = "package/";
        }
        const char* import_uri = OS::UriResolve(resolve_uri,
                                                import_path,
                                                zone());
        imported_library = LoadLibrary(import_uri, import_uri);
      }
      if (imported_library == NULL) return NULL;
      if (import->has_prefix()) {
        element->AddImportOf(imported_library, import->prefix(), zone());
      } else {
        element->AddImportOf(imported_library);
      }
    }
  }
  return element;
}

LibraryElement* LibraryLoader::FetchLibrary(const char* name) {
  IdentifierNode* identifier = builder()->Canonicalize(name);
  return LookupLibrary(identifier);
}

LibraryElement* LibraryLoader::LookupLibrary(IdentifierNode* library_name) {
  return library_map_.Lookup(library_name->id());
}

LibraryNode* LibraryLoader::BuildLibrary(const char* source_uri) const {
  Location location = builder()->source()->LoadFile(source_uri);
  if (location.IsInvalid()) return NULL;
  CompilationUnitNode* unit = builder()->BuildUnit(location);
  if (unit == NULL) return NULL;

  List<TreeNode*> declarations = unit->declarations();
  ListBuilder<CompilationUnitNode*, 4> parts(zone());
  for (int i = 0; i < declarations.length(); i++) {
    if (declarations[i]->IsPart()) {
      PartNode* part = declarations[i]->AsPart();
      const char* part_uri =
          OS::UriResolve(source_uri, part->uri()->value(), zone());
      Location part_location = builder()->source()->LoadFile(part_uri);
      if (Flags::IsOn("trace_library")) {
        printf(" - Part '%s' from '%s'\n", part->uri()->value(), part_uri);
      }
      if (part_location.IsInvalid()) return NULL;
      CompilationUnitNode* part_unit = builder()->BuildUnit(part_location);
      if (part_unit == NULL) return NULL;
      parts.Add(part_unit);
    }
  }

  return new(zone()) LibraryNode(unit, parts.ToList());
}

Scope* LibraryLoader::BuildLibraryScope(LibraryNode* library, Scope* outer) {
  Scope* scope = new(zone()) Scope(zone(), 0, outer);

  PopulateScope(library, library->unit(), scope);
  List<CompilationUnitNode*> parts = library->parts();
  for (int i = 0; i < parts.length(); i++) {
    PopulateScope(library, parts[i], scope);
  }

  return scope;
}

void LibraryLoader::AddSetterToScope(Scope* scope, MethodNode* method) {
  IdentifierNode* name = method->name()->AsIdentifier();
  ScopeEntry* entry = scope->LookupLocal(name);
  MemberEntry* member = NULL;
  if (entry != NULL) {
    member = entry->AsMember();
    if (member->has_setter() || member->member()->IsVariableDeclaration()) {
      builder()->ReportError(name->location(),
                             "Multiple setters with name '%s'",
                             name->value());
    }
  } else {
    member = new(zone()) MemberEntry(name);
    scope->Add(name, member);
  }
  member->set_setter(method);
}

void LibraryLoader::AddMemberToScope(Scope* scope,
                                     IdentifierNode* name,
                                     TreeNode* node) {
  ScopeEntry* entry = scope->LookupLocal(name);
  MemberEntry* member = NULL;
  if (entry != NULL) {
    member = entry->AsMember();
    if (member->has_member() || node->IsVariableDeclaration()) {
      builder()->ReportError(name->location(),
                             "Multiple declarations with name '%s'",
                             name->value());
    }
  } else {
    member = new(zone()) MemberEntry(name);
    scope->Add(name, member);
  }
  member->set_member(node);
}

void LibraryLoader::PopulateScope(LibraryNode* library,
                                  CompilationUnitNode* unit,
                                  Scope* scope) {
  List<TreeNode*> declarations = unit->declarations();
  for (int i = 0; i < declarations.length(); i++) {
    TreeNode* declaration = declarations[i];
    if (declaration->IsClass()) {
      ClassNode* clazz = declaration->AsClass();
      if (Flags::IsOn("trace_library")) {
        printf(" + Adding Class '%s' to scope\n", clazz->name()->value());
      }
      AddMemberToScope(scope, clazz->name(), clazz);
      Scope* class_scope = new(zone()) Scope(zone(), 0, scope);
      PopulateScope(clazz, class_scope);
      clazz->set_scope(class_scope);
      clazz->set_library(library);
    } else if (declaration->IsMethod()) {
      MethodNode* method = declarations[i]->AsMethod();
      IdentifierNode* name = method->name()->AsIdentifier();
      if (method->modifiers().is_static()) {
        builder()->ReportError(
            name->location(), "Top-level method can not be static");
      }
      if (!method->modifiers().is_external() &&
          !method->modifiers().is_native() &&
          method->body()->IsEmptyStatement()) {
        builder()->ReportError(
            name->location(), "A top-level method can not be abstract");
      }
      if (Flags::IsOn("trace_library")) {
        printf(" + Adding Method '%s' to scope\n", name->value());
      }
      method->set_owner(library);
      if (method->modifiers().is_set()) {
        AddSetterToScope(scope, method);
        continue;
      }
      AddMemberToScope(scope, name, method);
    } else if (declaration->IsVariableDeclarationStatement()) {
      VariableDeclarationStatementNode* stmt =
          declarations[i]->AsVariableDeclarationStatement();
      List<VariableDeclarationNode*> vars = stmt->declarations();
      for (int j = 0; j < vars.length(); j++) {
        VariableDeclarationNode* var = vars[j];
        IdentifierNode* name = var->name();
        if (var->modifiers().is_static()) {
          builder()->ReportError(
              name->location(), "Top-level field can not be static");
        }
        if (Flags::IsOn("trace_library")) {
          printf(" + Adding Field '%s' to scope\n", name->value());
        }
        AddMemberToScope(scope, name, var);
        var->set_owner(library);
      }
    }
  }
}

void LibraryLoader::PopulateScope(ClassNode* clazz, Scope* scope) {
  List<TreeNode*> declarations = clazz->declarations();
  ListBuilder<MethodNode*, 2> constructors(zone());
  for (int i = 0; i < declarations.length(); i++) {
    TreeNode* declaration = declarations[i];
    if (declaration->IsMethod()) {
      MethodNode* method = declarations[i]->AsMethod();
      method->set_owner(clazz);
      IdentifierNode* name = method->name()->AsIdentifier();
      // Skip constructors.
      if (name == NULL || name->id() == clazz->name()->id()) {
        constructors.Add(method);
        continue;
      }
      if (method->modifiers().is_factory()) {
        builder()->ReportError(
            name->location(), "A factory must be named after its class");
      }
      if (method->modifiers().is_static() &&
          !method->modifiers().is_external() &&
          !method->modifiers().is_native() &&
          method->body()->IsEmptyStatement()) {
        builder()->ReportError(
            name->location(), "A static method can not be abstract");
      }
      if (method->modifiers().is_set()) {
        AddSetterToScope(scope, method);
        continue;
      }
      if (Flags::IsOn("trace_library")) {
        printf("   - Adding Method '%s' to scope\n", name->value());
      }
      AddMemberToScope(scope, name, method);
    } else if (declaration->IsVariableDeclarationStatement()) {
      VariableDeclarationStatementNode* stmt =
          declarations[i]->AsVariableDeclarationStatement();
      List<VariableDeclarationNode*> vars = stmt->declarations();
      for (int j = 0; j < vars.length(); j++) {
        VariableDeclarationNode* var = vars[j];
        if (Flags::IsOn("trace_library")) {
          printf("   - Adding Field '%s' to scope\n", var->name()->value());
        }
        AddMemberToScope(scope, var->name(), var);
        var->set_owner(clazz);
      }
    }
  }
  // TODO(ajohnsen): Cache in class node?
  for (int i = 0; i < constructors.length(); i++) {
    MethodNode* constructor = constructors.Get(i);
    IdentifierNode* name = constructor->name()->AsIdentifier();
    if (constructor->modifiers().is_static()) {
      builder()->ReportError(
          name->location(), "A constructor can not be static");
    }
    if (name == NULL) {
      DotNode* dot = constructor->name()->AsDot();
      IdentifierNode* class_name = dot->object()->AsIdentifier();
      if (clazz->name()->id() != class_name->id()) {
        builder()->ReportError(
            class_name->location(),
            "Named constructor must start with the class name '%s'",
            clazz->name()->value());
      }
      name = dot->name();
    }
    ScopeEntry* entry = scope->LookupLocal(name);
    if (entry == NULL) continue;
    if (entry->AsMember()->has_member()) {
      builder()->ReportError(name->location(),
                             "Multiple declarations with name '%s'",
                             name->value());
    }
  }
}

}  // namespace fletch

