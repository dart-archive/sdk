// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_context;

import 'package:compiler/src/tree/tree.dart' show
    Node;

import 'package:compiler/src/universe/universe.dart' show
    Selector;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FieldElement,
    FunctionElement,
    FunctionSignature,
    LibraryElement,
    ParameterElement;

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    ConstructedConstantValue,
    FunctionConstantValue;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenRegistry,
    isPrivateName;

import 'package:compiler/src/compile_time_constants.dart' show
    DartConstantCompiler;

import 'fletch_compiler.dart' show
    FletchCompiler;

export 'fletch_compiler.dart' show
    FletchCompiler;

import 'fletch_backend.dart' show
    FletchBackend;

export 'fletch_backend.dart' show
    FletchBackend;

import 'fletch_resolution_callbacks.dart' show
    FletchResolutionCallbacks;

export 'fletch_resolution_callbacks.dart' show
    FletchResolutionCallbacks;

export 'bytecode_assembler.dart' show
    BytecodeAssembler,
    BytecodeLabel;

import 'fletch_native_descriptor.dart' show
    FletchNativeDescriptor;

import 'fletch_selector.dart' show
    FletchSelector,
    SelectorKind;

export 'fletch_native_descriptor.dart' show
    FletchNativeDescriptor;

class FletchContext {
  final FletchCompiler compiler;

  FletchResolutionCallbacks resolutionCallbacks;

  Map<String, FletchNativeDescriptor> nativeDescriptors;

  Map<String, String> names;

  Map<FieldElement, int> staticIndices = <FieldElement, int>{};

  Map<LibraryElement, String> libraryTag = <LibraryElement, String>{};
  List<String> symbols = <String>[];
  Map<String, int> symbolIds = <String, int>{};
  Map<Selector, String> selectorToSymbol = <Selector, String>{};

  FletchContext(this.compiler);

  FletchBackend get backend => compiler.backend;

  void setNames(Map<String, String> names) {
    // Generate symbols of the values.
    for (String name in names.values) {
      getSymbolId(name);
    }
    this.names = names;
  }

  String mangleName(String name, LibraryElement library) {
    if (!isPrivateName(name)) return name;
    return name + getLibraryTag(library);
  }

  String getLibraryTag(LibraryElement library) {
    return libraryTag.putIfAbsent(library, () {
      // Give the core library the unique mangling of the empty string. That
      // will make the VM able to create selector into core (used for e.g.
      // _noSuchMethodTrampoline).
      if (library == compiler.coreLibrary) return "";
      return "%${libraryTag.length}";
    });
  }

  int getStaticFieldIndex(FieldElement element, Element referrer) {
    return staticIndices.putIfAbsent(element, () => staticIndices.length);
  }

  String getSymbolFromSelector(Selector selector) {
    return selectorToSymbol.putIfAbsent(selector, () {
        StringBuffer buffer = new StringBuffer();
        buffer.write(mangleName(selector.name, selector.library));
        for (String namedArgument in selector.namedArguments) {
          buffer.write(":");
          buffer.write(namedArgument);
        }
        return buffer.toString();
      });
  }

  void writeNamedArguments(StringBuffer buffer, FunctionSignature signature) {
    signature.orderedForEachParameter((ParameterElement parameter) {
      if (parameter.isNamed) {
        buffer.write(":");
        buffer.write(parameter.name);
      }
    });
  }

  String getSymbolForFunction(
      String name,
      FunctionSignature signature,
      LibraryElement library) {
    StringBuffer buffer = new StringBuffer();
    buffer.write(mangleName(name, library));
    writeNamedArguments(buffer, signature);
    return buffer.toString();
  }

  String getCallSymbol(FunctionSignature signature) {
    return getSymbolForFunction('call', signature, null);
  }

  int getSymbolId(String symbol) {
    return symbolIds.putIfAbsent(symbol, () {
      int id = symbols.length;
      assert(id == symbolIds.length);
      symbols.add(symbol);
      return id;
    });
  }

  void forEachStatic(f(FieldElement element, int index)) {
    staticIndices.forEach(f);
  }

  int toFletchSelector(Selector selector) {
    String symbol = getSymbolFromSelector(selector);
    int id = getSymbolId(symbol);
    SelectorKind kind = getFletchSelectorKind(selector);
    return FletchSelector.encode(id, kind, selector.argumentCount);
  }

  int toFletchIsSelector(ClassElement classElement, [int arity]) {
    LibraryElement library = classElement.library;
    StringBuffer buffer = new StringBuffer();
    buffer.write("?is?");
    buffer.write(classElement.name);
    buffer.write("?");
    buffer.write(getLibraryTag(library));
    int id = getSymbolId(buffer.toString());
    if (arity == null) return FletchSelector.encodeGetter(id);
    return FletchSelector.encodeMethod(id, arity);
  }

  int toFletchTearoffIsSelector(
      String functionName,
      ClassElement classElement) {
    LibraryElement library = classElement.library;
    StringBuffer buffer = new StringBuffer();
    buffer.write("?is?");
    buffer.write(functionName);
    buffer.write("?");
    buffer.write(classElement.name);
    buffer.write("?");
    buffer.write(getLibraryTag(library));
    int id = getSymbolId(buffer.toString());
    return FletchSelector.encodeMethod(id, 0);
  }

  SelectorKind getFletchSelectorKind(Selector selector) {
    if (selector.isGetter) return SelectorKind.Getter;
    if (selector.isSetter) return SelectorKind.Setter;
    return SelectorKind.Method;
  }

  void registerConstructedConstantValue(ConstructedConstantValue value) {
    ClassElement classElement = value.type.element;
    backend.registerClassElement(classElement);
    // TODO(ahe): This should not be required. Also, instantiate type,
    // not class.
    var registry = new CodegenRegistry(
        compiler,
        classElement.resolvedAst.elements);
    registry.registerInstantiatedClass(classElement);
  }

  void registerFunctionConstantValue(FunctionConstantValue value) {
    backend.markFunctionConstantAsUsed(value);
  }

  void markConstantUsed(ConstantValue constant) {
    backend.systemBuilder.registerNewConstant(constant, this);
  }

  // TODO(ajohnsen): Remove this getter and use the systemBuilder in backend
  // directly.
  Map<ConstantValue, int> get compiledConstants =>
      backend.systemBuilder.getCompiledConstants();

  /// If [isConst] is true, a compile-time error is reported.
  ConstantExpression compileConstant(
      Node node,
      TreeElements elements,
      {bool isConst}) {
    assert(isConst != null);
    // TODO(johnniwinther): Should be handled in resolution.
    ConstantExpression expression =
        compiler.resolver.constantCompiler.compileNode(
            node, elements, enforceConst: isConst);
    if (expression == null) return null;
    ConstantValue value = getConstantValue(expression);
    markConstantUsed(value);
    return expression;
  }

  ConstantValue getConstantValue(ConstantExpression expression) {
    return compiler.constants.getConstantValue(expression);
  }
}
