// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_system_printer;

import '../dartino_system.dart' show
    DartinoFunction,
    DartinoSystem;

import '../dartino_class.dart' show
    DartinoClass;

import 'package:compiler/src/util/uri_extras.dart' show
    relativize;

import 'dartino_selector.dart' show
    DartinoSelector,
    SelectorKind;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    CompilationUnitElement;

class DartinoSystemPrinter {
  final DartinoSystem system;
  final Uri base;
  final StringBuffer buffer = new StringBuffer();
  final String baseIndentation = "  ";

  bool beginningOfLine = true;

  int indentationLevel = 0;

  DartinoSystemPrinter(this.system, this.base);

  void indent() {
    for (int i = 0; i < indentationLevel; i++) {
      buffer.write(baseIndentation);
    }
  }

  void indented(f()) {
    ++indentationLevel;
    try {
      f();
    } finally {
      --indentationLevel;
    }
  }

  void write(String text) {
    if (beginningOfLine) {
      indent();
      beginningOfLine = false;
    }
    buffer.write(text);
  }

  void writeLine([String line = ""]) {
    write("$line\n");
    beginningOfLine = true;
  }

  void writeDartinoFunctionAsBody(DartinoFunction function) {
    if (function.element != null) {
      writeLine("=> ${function.element};");
    } else {
      writeLine("{");
      indented(() {
        for (String line in function.verboseToString().trim().split("\n")) {
          writeLine("// $line");
        }
      });
      writeLine("}");
    }
  }

  void writeMethodTableEntry(
      DecodedDartinoSelector selector, int functionId) {
    switch (selector.kind) {
      case SelectorKind.Method:
        write("${selector.symbol}#${selector.arity}()");
        break;

      case SelectorKind.Getter:
        assert(selector.arity == 0);
        if (selector.symbol.startsWith("?is?")) {
          writeLine("type test ${selector.symbol.substring(4)}");
          return;
        }
        write("get ${selector.symbol}");
        break;

      case SelectorKind.Setter:
        assert(selector.arity == 1);
        write("set ${selector.symbol}");
        break;
    }
    write(" ");
    DartinoFunction function = system.functionsById[functionId];
    writeDartinoFunctionAsBody(function);
  }

  void writeDartinoClass(DartinoClass cls, Set<DartinoFunction> unseen) {
    // TODO(ahe): Important if class is builtin or not. Information lost in
    // DartinoNewClassBuilder.finalizeClass.
    if (cls.element != null) {
      writeLine("class ${cls.element.name} {");
    } else {
      writeLine("$cls {");
    }
    indented(() {
      Map<DecodedDartinoSelector, int> methodTable =
          <DecodedDartinoSelector, int>{};
      for (var pair in cls.methodTable) {
        DecodedDartinoSelector selector =
            new DecodedDartinoSelector.fromEncodedSelector(pair.fst, system);
        methodTable[selector] = pair.snd;
      }
      List<DecodedDartinoSelector> selectors =
          methodTable.keys.toList()..sort();
      for (DecodedDartinoSelector selector in selectors) {
        int methodId = methodTable[selector];
        unseen.remove(system.lookupFunctionById(methodId));
        writeMethodTableEntry(selector, methodId);
      }
    });
    writeLine("}");
  }

  String generateDebugString() {
    buffer.clear();

    Map<String, List<Element>> elementsByPath = <String, List<Element>>{};
    Set<DartinoFunction> unseenFunctions = new Set<DartinoFunction>();

    for (var pair in system.functionsById) {
      unseenFunctions.add(pair.snd);
    }

    groupByPath(pair) {
      Element element = pair.fst;
      String path =
          relativize(base, element.compilationUnit.script.resourceUri, false);
      List<Element> elements =
          elementsByPath.putIfAbsent(path, () => <Element>[]);
      elements.add(element);
    }
    system.functionsByElement.forEach(groupByPath);
    system.classesByElement.forEach(groupByPath);
    List paths = elementsByPath.keys.toList();
    paths.sort();
    for (String path in paths) {
      writeLine("$path");
      indented(() {
        List<Element> elements = elementsByPath[path];
        elements.sort((a, b) => "$a".compareTo("$b"));
        for (Element element in elements) {
          if (element.isClass) {
            writeDartinoClass(system.classesByElement[element],
                              unseenFunctions);
          } else if (!element.isInstanceMember) {
            unseenFunctions.remove(system.functionsByElement[element]);
            // TODO(ahe): It would probably be better to call
            // writeDartinoFunctionAsBody here, but we have an element, not an
            // ID.
            writeLine("$element");
          }
        }
      });
    }

    writeLine("Classes without an element:");
    indented(() {
      for (var pair in system.classesById) {
        DartinoClass dartinoClass = pair.snd;
        if (system.classesByElement[dartinoClass.element] != dartinoClass) {
          writeDartinoClass(dartinoClass, unseenFunctions);
        }
      }
    });

    writeLine("Other functions:");
    indented(() {
      for (var pair in system.functionsById) {
        DartinoFunction dartinoFunction = pair.snd;
        if (unseenFunctions.remove(dartinoFunction)) {
          write("$dartinoFunction ");
          writeDartinoFunctionAsBody(dartinoFunction);
        }
      }
    });

    return "$buffer";
  }

  int compareUnits(CompilationUnitElement a, CompilationUnitElement b) {
    String aPath = relativize(base, a.script.resourceUri, false);
    String bPath = relativize(base, b.script.resourceUri, false);
    return aPath.compareTo(bPath);
  }
}

class DecodedDartinoSelector implements Comparable<DecodedDartinoSelector> {
  final DartinoSelector selector;

  final String symbol;

  const DecodedDartinoSelector(this.selector, this.symbol);

  factory DecodedDartinoSelector.fromEncodedSelector(
      int encodedSelector,
      DartinoSystem system) {
    DartinoSelector selector = new DartinoSelector(encodedSelector);
    return new DecodedDartinoSelector(
        selector, system.symbolByDartinoSelectorId[selector.id]);
  }

  int get id => selector.id;

  SelectorKind get kind => selector.kind;

  int get arity => selector.arity;

  String toString() => "DecodedDartinoSelector($id, $symbol, $kind, $arity)";

  int compareTo(DecodedDartinoSelector other) {
    int result = this.symbol.compareTo(other.symbol);
    if (result != 0) return result;
    result = this.kind.index.compareTo(other.kind.index);
    if (result != 0) return result;
    return this.arity.compareTo(other.arity);
  }
}
