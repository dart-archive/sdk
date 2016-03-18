// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_system_base;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FieldElement,
    LibraryElement,
    Name;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'dartino_system_builder.dart' show
    SchemaChange;

import '../dartino_class_base.dart' show
    DartinoClassBase;

import '../dartino_system.dart' show
    DartinoFunctionBase,
    ParameterStubSignature;

import 'dartino_selector.dart' show
    DartinoSelector,
    SelectorKind;

abstract class DartinoSystemBase {
  const DartinoSystemBase();

  int toDartinoSelector(Selector selector) {
    String symbol = getSymbolFromSelector(selector);
    int id = getSymbolId(symbol);
    SelectorKind kind = getDartinoSelectorKind(selector);
    return DartinoSelector.encode(id, kind, selector.argumentCount);
  }

  int toDartinoIsSelector(ClassElement classElement, [int arity]) {
    LibraryElement library = classElement.library;
    StringBuffer buffer = new StringBuffer();
    buffer.write("?is?");
    buffer.write(classElement.name);
    buffer.write("?");
    buffer.write(getLibraryTag(library));
    int id = getSymbolId(buffer.toString());
    if (arity == null) return DartinoSelector.encodeGetter(id);
    return DartinoSelector.encodeMethod(id, arity);
  }

  String getSymbolFromSelector(Selector selector);

  int getSymbolId(String symbol);

  // TODO(ahe): Rename to getClassBase.
  DartinoClassBase getClassBuilder(
      ClassElement element,
      {Map<ClassElement, SchemaChange> schemaChanges});

  String mangleName(Name name);

  DartinoFunctionBase lookupFunctionByElement(Element element);

  DartinoClassBase lookupClassById(int classId);

  String getLibraryTag(LibraryElement library);

  String lookupSymbolById(int id);

  SelectorKind getDartinoSelectorKind(Selector selector) {
    if (selector.isGetter) return SelectorKind.Getter;
    if (selector.isSetter) return SelectorKind.Setter;
    return SelectorKind.Method;
  }

  int getStaticFieldIndex(FieldElement element, Element referrer);

  DartinoFunctionBase lookupParameterStub(ParameterStubSignature signature);
}
