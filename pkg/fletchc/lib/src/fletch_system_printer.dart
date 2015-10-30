// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system_printer;

import '../fletch_system.dart' show
    FletchClass,
    FletchFunction,
    FletchSystem;

import 'package:compiler/src/util/uri_extras.dart' show
    relativize;

import 'fletch_selector.dart' show
    FletchSelector,
    SelectorKind;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    CompilationUnitElement;

class FletchSystemPrinter {
  final FletchSystem system;
  final Uri base;
  final StringBuffer buffer = new StringBuffer();
  final String baseIndentation = "  ";

  bool beginningOfLine = true;

  int indentationLevel = 0;

  FletchSystemPrinter(this.system, this.base);

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

  void writeFletchFunctionAsBody(FletchFunction function) {
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
      DecodedFletchSelector selector, int functionId) {
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
    FletchFunction function = system.functionsById[functionId];
    writeFletchFunctionAsBody(function);
  }

  void writeFletchClass(FletchClass cls) {
    // TODO(ahe): Important if class is builtin or not. Information lost in
    // FletchNewClassBuilder.finalizeClass.
    if (cls.element != null) {
      writeLine("class ${cls.element.name} {");
    } else {
      writeLine("$cls {");
    }
    indented(() {
      Map<DecodedFletchSelector, int> methodTable =
          <DecodedFletchSelector, int>{};
      for (var pair in cls.methodTable) {
        DecodedFletchSelector selector =
            new DecodedFletchSelector.fromEncodedSelector(pair.fst, system);
        methodTable[selector] = pair.snd;
      }
      List<DecodedFletchSelector> selectors = methodTable.keys.toList()..sort();
      for (DecodedFletchSelector selector in selectors) {
        writeMethodTableEntry(selector, methodTable[selector]);
      }
    });
    writeLine("}");
  }

  String generateDebugString() {
    buffer.clear();

    Map<String, List<Element>> elementsByPath = <String, List<Element>>{};

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
            writeFletchClass(system.classesByElement[element]);
          } else if (!element.isInstanceMember) {
            // TODO(ahe): It would probably be better to call
            // writeFletchFunctionAsBody here, but we have an element, not an
            // ID.
            writeLine("$element");
          }
        }
      });
    }

    writeLine("Classes without an element:");
    indented(() {
      for (var pair in system.classesById) {
        FletchClass fletchClass = pair.snd;
        if (system.classesByElement[fletchClass.element] != fletchClass) {
          writeFletchClass(fletchClass);
        }
      }
    });

    writeLine("Functions without an element:");
    indented(() {
      for (var pair in system.functionsById) {
        FletchFunction fletchFunction = pair.snd;
        if (system.functionsByElement[fletchFunction.element] !=
            fletchFunction) {
          // TODO(ahe): This test isn't accurate, we should keep all
          // fletchFunctions in a set an remove them when they have been
          // printed above.
          writeLine("$fletchFunction");
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

class DecodedFletchSelector implements Comparable<DecodedFletchSelector> {
  final FletchSelector selector;

  final String symbol;

  const DecodedFletchSelector(this.selector, this.symbol);

  factory DecodedFletchSelector.fromEncodedSelector(
      int encodedSelector,
      FletchSystem system) {
    FletchSelector selector = new FletchSelector(encodedSelector);
    return new DecodedFletchSelector(
        selector, system.symbolByFletchSelectorId[selector.id]);
  }

  int get id => selector.id;

  SelectorKind get kind => selector.kind;

  int get arity => selector.arity;

  String toString() => "DecodedFletchSelector($id, $symbol, $kind, $arity)";

  int compareTo(DecodedFletchSelector other) {
    int result = this.symbol.compareTo(other.symbol);
    if (result != 0) return result;
    result = this.kind.index.compareTo(other.kind.index);
    if (result != 0) return result;
    return this.arity.compareTo(other.arity);
  }
}
