// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.errors;

import 'package:compiler/src/scanner/scannerlib.dart' show
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
  badFormal,
  badFunction,
  badListType,
  badPointerType,
  badServiceDefinition,
  badSimpleType,
  badStructDefinition,
  badTopLevel,
  badTypeParameter,
  badUnion,
  cyclicStruct,
  expectedPointerOrPrimitive,
  expectedPrimitiveFormal,
  multipleDefinitions,
  multipleUnions,
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

  List<int> lineStarts;

  ErrorReporter(this.absolutePath, this.relativePath) {
    String input = new File(absolutePath).readAsStringSync();

    lineStarts = <int>[0];

    for (int i = 0; i < input.length; ++i) {
      if ($LF == input.codeUnitAt(i)) {
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
      print("$type at $relativePath:$lineNumber:$lineOffset: $message");
    } else {
      print("$type in $relativePath: $message");
    }
  }

  void reportError(String message, [Token token]) {
    _reportMessage(message, token, "ERROR");
  }

  void reportInfo(String message, [Token token]) {
    _reportMessage(message, token, "INFO");
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
// TODO(stanm): better messages
abstract class CompilationError {
  ErrorTag get tag;
  void report(ErrorReporter reporter);
}

class UndefinedServiceError extends CompilationError {
  ErrorTag get tag => ErrorTag.undefinedService;
  void report(ErrorReporter reporter) {
    reporter.reportError("No service defined.");
  }
}

class SyntaxError extends CompilationError {
  ErrorNode node;
  ErrorTag get tag => node.tag;

  SyntaxError(this.node);

  void report(ErrorReporter reporter) {
    reporter.reportError(node.tag.toString(), node.begin);
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
        "Type of formal ${formal.identifier.value} is not primitive.",
        formal.identifier.token);
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

abstract class BadTypeError extends CompilationError {
  TypeNode type;
  String get message;

  BadTypeError(this.type);

  void report(ErrorReporter reporter) {
    print(message);
    reporter.reportError(message, type.identifier.token);
  }
}

class NotPointerOrPrimitiveError extends BadTypeError {
  ErrorTag get tag => ErrorTag.expectedPointerOrPrimitive;
  String get message => "Expected a pointer or a primitive.";

  NotPointerOrPrimitiveError(TypeNode type)
    : super(type);
}

class BadSimpleTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badSimpleType;
  // TODO(stanm): better message here
  String get message => "Expected a primitive type, a string, or a struct.";

  BadSimpleTypeError(TypeNode type)
    : super(type);
}

class BadPointerTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badPointerType;
  String get message => "Expected a pointer type.";

  BadPointerTypeError(TypeNode type)
    : super(type);
}

class BadListTypeError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badListType;
  String get message => "Expected a list type.";

  BadListTypeError(TypeNode type)
    : super(type);
}

class BadTypeParameterError extends BadTypeError {
  ErrorTag get tag => ErrorTag.badTypeParameter;
  // TODO(stanm): better message here
  String get message => "Type cannot be used as type parameter.";

  BadTypeParameterError(TypeNode type)
    : super(type);
}
