// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.errors;

import 'package:compiler/src/tokens/token.dart' show
    Token;

import 'package:compiler/src/util/characters.dart' show
    $LF;

import 'dart:io' show
    File;

import 'node.dart' show
    FunctionNode,
    FormalNode,
    IdentifierNode,
    ListType,
    FieldNode,
    MemberNode,
    Node,
    NodeVisitor,
    ServiceNode,
    StructNode,
    TopLevelNode,
    TypeNode,
    UnionNode;

enum ErrorTag {
  badField,
  badFieldType,
  badFormal,
  badFunction,
  badListType,
  badPointerType,
  badReturnType,
  badServiceDefinition,
  badSingleFormal,
  badStructDefinition,
  badTopLevel,
  badTypeParameter,
  badUnion,
  cyclicStruct,
  expectedPrimitiveFormal,
  multipleDefinitions,
  multipleUnions,
  serviceStructNameClash,
  undefinedService
}

// A reverse map from error names to errors.
final Map<String, ErrorTag> compilerErrorTypes =
  new Map<String, ErrorTag>.fromIterables(
    ErrorTag.values.map((value) => value.toString()),
    ErrorTag.values
  );

// Error nodes.
class ServiceErrorNode extends ServiceNode with ErrorNode {
  ServiceErrorNode(IdentifierNode identifier,
                   List<FunctionNode> functions,
                   Token begin)
    : super(identifier, functions) {
    this.begin = begin;
    tag = ErrorTag.badServiceDefinition;
  }
}

class StructErrorNode extends StructNode with ErrorNode {
  StructErrorNode(IdentifierNode identifier,
                  List<MemberNode> members,
                  Token begin)
    : super(identifier, members) {
    this.begin = begin;
    tag = ErrorTag.badStructDefinition;
  }
}

class TopLevelErrorNode extends TopLevelNode with ErrorNode {
  TopLevelErrorNode(Token begin)
    : super(null) {
    this.begin = begin;
    tag = ErrorTag.badTopLevel;
  }

  void accept(NodeVisitor visitor) {
    visitor.visitError(this);
  }
}

class FunctionErrorNode extends FunctionNode
    with ErrorNode {
  FunctionErrorNode(TypeNode type,
                    IdentifierNode identifier,
                    List<FormalNode> formals,
                    Token begin)
    : super(type, identifier, formals) {
    this.begin = begin;
    tag = ErrorTag.badFunction;
  }
}

class UnionErrorNode extends UnionNode with ErrorNode {
  UnionErrorNode(List<FieldNode> fields, Token begin)
    : super(fields) {
    this.begin = begin;
    tag = ErrorTag.badUnion;
  }
}

class FieldErrorNode extends FieldNode with ErrorNode {
  FieldErrorNode(TypeNode type, IdentifierNode identifier, Token begin)
    : super(type, identifier) {
    this.begin = begin;
    tag = ErrorTag.badField;
  }
}

class FormalErrorNode extends FormalNode with ErrorNode {
  FormalErrorNode(TypeNode type, IdentifierNode identifier, Token begin)
    : super(type, identifier) {
    this.begin = begin;
    tag = ErrorTag.badFormal;
  }
}

class ListTypeError extends ListType with ErrorNode {
  ListTypeError(IdentifierNode identifier, TypeNode typeParameter, Token begin)
    : super(identifier, typeParameter) {
    this.begin = begin;
    tag = ErrorTag.badListType;
  }
}

class ErrorNode {
  Token begin;
  ErrorTag tag;
}

class InternalCompilerError extends Error {
  String message;
  InternalCompilerError(this.message);

  String toString() => "InternalCompilerError: $message";
}

// Error reporter.
class ErrorReporter {
  String absolutePath;
  String relativePath;
  String fileContents;

  List<int> lineStarts;

  ErrorReporter(this.absolutePath, this.relativePath) {
    fileContents = new File(absolutePath).readAsStringSync();

    lineStarts = <int>[-1];

    for (int i = 0; i < fileContents.length; ++i) {
      if ($LF == fileContents.codeUnitAt(i)) {
        lineStarts.add(i);
      }
    }
  }

  void report(List<CompilationError> errors) {
    print("Number of errors: ${errors.length}");
    for (CompilationError error in errors) {
      error.report(this);
    }
  }

  void _reportMessage(String message, Token token, String type) {
    if (null != token) {
      int lineNumber = getLineNumber(token);
      int lineOffset = getLineOffset(token, lineNumber);
      print("$relativePath:$lineNumber:$lineOffset: $type: $message");
      int end = lineNumber < lineStarts.length ? lineStarts[lineNumber]
          : fileContents.length;
      print(fileContents.substring(lineStarts[lineNumber - 1] + 1, end));
      print(" " * (lineOffset - 1) + "^");
    } else {
      print("$relativePath: $type: $message");
    }
  }

  void reportError(String message, [Token token]) {
    _reportMessage(message, token, "error");
  }

  void reportWarning(String message, [Token token]) {
    _reportMessage(message, token, "warning");
  }

  void reportInfo(String message, [Token token]) {
    _reportMessage(message, token, "info");
  }

  int getLineNumber(Token token) {
    for (int i = 1; i < lineStarts.length; ++i) {
      if (lineStarts[i] >= token.charOffset) {
        return i;
      }
    }
    return lineStarts.length;
  }

  int getLineOffset(Token token, int currentLine) {
    return token.charOffset - lineStarts[currentLine - 1];
  }
}

// Compilation errors.
abstract class CompilationError {
  ErrorTag get tag;
  void report(ErrorReporter reporter);
}

class UndefinedServiceError extends CompilationError {
  ErrorTag get tag => ErrorTag.undefinedService;
  void report(ErrorReporter reporter) {
    reporter.reportError("There should be at least one service per " +
                         "compilation unit.");
  }
}

class SyntaxError extends CompilationError {
  ErrorNode node;
  ErrorTag get tag => node.tag;

  SyntaxError(this.node);

  Map<ErrorTag, String> errorMessages = {
    ErrorTag.badField: "Unfinished field declaration.",
    ErrorTag.badFormal: "Unfinished formal argument declaration.",
    ErrorTag.badFunction: "Unfinished function declaration.",
    ErrorTag.badListType: "Unexpected token while parsing type parameter.",
    ErrorTag.badServiceDefinition: "Unfinished service definition.",
    ErrorTag.badStructDefinition: "Unfinished struct definition.",
    ErrorTag.badTopLevel: "Unexpected token while parsing top-level " +
                          "definition."
  };

  Map<ErrorTag, String> infoMessages = {
    ErrorTag.badField: null,
    ErrorTag.badFormal: null,
    ErrorTag.badFunction: null,
    ErrorTag.badListType: "Expected a primitive type, a string, or a " +
                          "structure as the List type parameter",
    ErrorTag.badServiceDefinition: null,
    ErrorTag.badStructDefinition: null,
    ErrorTag.badTopLevel: "Top-level defintions start with `service` or " +
                          "`struct`."
  };

  void report(ErrorReporter reporter) {
    reporter.reportError(errorMessages[node.tag], node.begin);
    if (null != infoMessages[node.tag]) {
      reporter.reportInfo(infoMessages[node.tag], node.begin);
    }
  }

}

class CyclicStructError extends CompilationError {
  Iterable<StructNode> chain;
  ErrorTag get tag => ErrorTag.cyclicStruct;

  CyclicStructError(this.chain);

  void report(ErrorReporter reporter) {
    String message;
    StructNode struct = chain.first;
    if (chain.length == 1) {
      message = "Struct ${struct.identifier.value} references itself.";
    } else {
      message = "Struct ${struct.identifier.value} has a cyclic reference;";
    }
    reporter.reportError(message, struct.identifier.token);
    for (StructNode struct in chain) {
      if (struct == chain.first) continue;
      message = "references ${struct.identifier.value}";
      if (struct == chain.last) {
        message += ".";
      } else {
        message += " which in turn";
      }
      reporter.reportInfo(message, struct.identifier.token);
    }
  }
}

class MultipleUnionsError extends CompilationError {
  StructNode struct;
  ErrorTag get tag => ErrorTag.multipleUnions;

  MultipleUnionsError(this.struct);

  void report(ErrorReporter reporter) {
    reporter.reportError(
        "Struct ${struct.identifier.value} contains multiple unions.",
        struct.identifier.token);
  }
}

class NotPrimitiveFormalError extends CompilationError {
  FormalNode formal;
  ErrorTag get tag => ErrorTag.expectedPrimitiveFormal;

  NotPrimitiveFormalError(this.formal);

  void report(ErrorReporter reporter) {
    reporter.reportError(
        "Unexpected type of formal argument '${formal.identifier.value}'.",
        formal.type.identifier.token);
    reporter.reportInfo(
        "All formal arguments should have primitive types when the function " +
        "has more than one formal argument.",
        formal.type.identifier.token);
  }
}

class MultipleDefinitionsError extends CompilationError {
  IdentifierNode original;
  IdentifierNode redefined;
  ErrorTag get tag => ErrorTag.multipleDefinitions;

  MultipleDefinitionsError(this.original, this.redefined);

  void report(ErrorReporter reporter) {
    reporter.reportError("Redefined symbol ${redefined.value};",
                         redefined.token);
    reporter.reportInfo("Original definition found here.", original.token);
  }
}

class ServiceStructNameClashError extends CompilationError {
  IdentifierNode original;
  IdentifierNode redefined;
  ErrorTag get tag => ErrorTag.serviceStructNameClash;

  ServiceStructNameClashError(this.original, this.redefined);

  void report(ErrorReporter reporter) {
    reporter.reportError("Identifier ${redefined.value} used both as a " +
                         "service name and as a struct name;",
                         redefined.token);
    reporter.reportInfo("Original definition found here.", original.token);
  }
}

abstract class BadTypeError extends CompilationError {
  TypeNode type;
  String get errorMessage;
  String get infoMessage;

  BadTypeError(this.type);

  void report(ErrorReporter reporter) {
    reporter.reportError(errorMessage, type.identifier.token);
    reporter.reportInfo(infoMessage, type.identifier.token);
  }
}

class BadReturnTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badReturnType;
  String get errorMessage => "Unexpected return type.";
  String get infoMessage => "Expected a pointer type or a primitive type as " +
                            "the return type of a function.";

  BadReturnTypeError(TypeNode type)
    : super(type);
}

class BadSingleFormalError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badSingleFormal;
  String get errorMessage => "Unexpected type of formal argument.";
  String get infoMessage => "Expected a primitive type or a pointer type for " +
                            "a function with just one formal argument.";

  BadSingleFormalError(TypeNode type)
    : super(type);
}

class BadFieldTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badFieldType;
  String get errorMessage => "Unexpected field type.";
  String get infoMessage =>
    "A field type should be one of the following:\n" +
    "  * a primitive type, e.g. int32;\n" +
    "  * a String;\n" +
    "  * a struct type, e.g. Foo.\n" +
    "  * a pointer to a struct, e.g. Foo*;\n" +
    "  * a list of structs, e.g. List<Foo>.";

  BadFieldTypeError(TypeNode type)
    : super(type);
}

class BadPointerTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badPointerType;
  String get errorMessage => "Undefined struct '${type.identifier.value}'.";
  String get infoMessage => "Expected a pointer to a known struct type.";

  BadPointerTypeError(TypeNode type)
    : super(type);
}

class BadListTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badListType;
  String get errorMessage =>
    "Unexpected generic type '${type.identifier.value}'.";
  String get infoMessage => "'List' is the only supported generic type.";

  BadListTypeError(TypeNode type)
    : super(type);
}

class BadTypeParameterError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badTypeParameter;
  String get errorMessage => "Unexpected type parameter.";
  String get infoMessage => "Expected a primitive type or a structure as " +
                            "the List type parameter.";

  BadTypeParameterError(TypeNode type)
    : super(type);
}
