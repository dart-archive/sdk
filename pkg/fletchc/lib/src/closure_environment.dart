// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.closure_environment;

import 'package:compiler/src/resolution/semantic_visitor.dart' show
    SemanticSendVisitor,
    SemanticVisitor;

import 'package:compiler/src/resolution/operators.dart' show
    BinaryOperator,
    IncDecOperator;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/dart2jslib.dart' show
    MessageKind,
    Registry;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

import 'fletch_context.dart';

import 'fletch_constants.dart' show
    CompiledFunctionConstant,
    FletchClassConstant;

import '../bytecodes.dart' show
    Bytecode;

import 'compiled_function.dart' show
    CompiledFunction;

import 'fletch_selector.dart';

enum CaptureMode {
  /**
   * If a local is marked [ByValue], the local is read in closures.
   */
  ByValue,

  /**
   * If a local is marked [ByReference], a write to the local can be observed
   * from a closure.
   *
   * In this case, the local must be boxed.
   */
  ByReference,
}

/**
 * The computed infomation about a closures usage of locals and 'this'.
 */
class ClosureInfo {
  bool isThisFree = false;
  Set<LocalElement> free = new Set<LocalElement>();

  void markUsed(LocalElement element) {
    free.add(element);
  }
}

class ClosureEnvironment {
  /**
   * A map of locals that are captured, and how.
   */
  final Map<LocalElement, CaptureMode> captured = <LocalElement, CaptureMode>{};

  /**
   * A map of all nested closures of [function], and what locals they capture.
   */
  final Map<FunctionElement, ClosureInfo> closures =
      <FunctionElement, ClosureInfo>{};

  bool shouldBeBoxed(element) => captured[element] == CaptureMode.ByReference;
}

class ClosureVisitor
    extends SemanticVisitor
    implements SemanticSendVisitor {
  final ClosureEnvironment closureEnvironment = new ClosureEnvironment();

  /**
   * A set of all locals that are assigned in [function] excluding nested
   * closures. This is the inverse of implicit final locals.
   */
  final Set<LocalElement> locallyAssigned = new Set<LocalElement>();

  final FunctionElement function;

  FunctionElement currentFunction;

  ClosureVisitor(this.function, TreeElements elements)
      : super(elements);

  SemanticSendVisitor get sendVisitor => this;

  ClosureEnvironment compute() {
    assert(function.memberContext == function);
    assert(currentFunction == null);
    currentFunction = function;
    if (function.node != null) function.node.body.accept(this);
    assert(currentFunction == function);
    return closureEnvironment;
  }

  void visitNode(Node node) {
    node.visitChildren(this);
  }

  void visitVariableDefinitions(VariableDefinitions node) {
    for (Node definition in node.definitions) {
      LocalElement element = elements[definition];
      Expression initializer = element.initializer;
      if (initializer != null) initializer.accept(this);
    }
  }

  void visitFunctionExpression(FunctionExpression node) {
    FunctionElement oldFunction = currentFunction;
    currentFunction = elements[node];
    ClosureInfo info = new ClosureInfo();
    closureEnvironment.closures[currentFunction] = info;
    node.body.accept(this);
    currentFunction = oldFunction;
  }

  void markUsed(LocalElement element, CaptureMode use) {
    if (currentFunction == element.executableContext) {
      // If a local is assigned in the declaring context, and it is captured
      // at this point, mark it as used by reference (we assign to the value
      // after it's captured).
      if (use == CaptureMode.ByReference) {
        if (closureEnvironment.captured.containsKey(element)) {
          closureEnvironment.captured[element] = use;
        } else {
          locallyAssigned.add(element);
        }
      }
    } else {
      if (locallyAssigned.contains(element)) use = CaptureMode.ByReference;
      // If the element is used by reference, upgrade it unconditionally.
      if (use == CaptureMode.ByReference) {
        closureEnvironment.captured[element] = use;
      } else {
        // If it's used by value, only add it to `captured` if it's not
        // there already - if it's in there it can be by reference.
        closureEnvironment.captured.putIfAbsent(element, () => use);
      }
      FunctionElement current = currentFunction;
      // Mark all closures from the current to the one where `element` is
      // defined, as used in that closure. That makes sure we capture it in
      // all intermidiate closures, thus making it available in the current.
      while (current != element.executableContext) {
        ClosureInfo info = closureEnvironment.closures[current];
        info.markUsed(element);
        current = current.executableContext;
      }
    }
  }

  void markThisUsed() {
    FunctionElement current = currentFunction;
    while (current != function) {
      ClosureInfo info = closureEnvironment.closures[current];
      info.isThisFree = true;
      current = current.executableContext;
    }
  }

  void visitLocalVariableGet(Send node, LocalVariableElement element, _) {
    markUsed(element, CaptureMode.ByValue);
  }

  void visitParameterGet(Send node, ParameterElement element, _) {
    markUsed(element, CaptureMode.ByValue);
  }

  void visitParameterSet(SendSet node, ParameterElement element, Node rhs, _) {
    rhs.accept(this);
    markUsed(element, CaptureMode.ByReference);
  }

  void visitThisPropertySet(Send node, Selector selector, Node rhs, _) {
    rhs.accept(this);
    markThisUsed();
  }

  void visitLocalVariableSet(
      SendSet node,
      LocalVariableElement element,
      Node rhs,
      _) {
    markUsed(element, CaptureMode.ByReference);
    rhs.accept(this);
  }

  void visitLocalVariableInvoke(
      Send node,
      LocalVariableElement element,
      NodeList arguments,
      Selector selector,
      _) {
    markUsed(element, CaptureMode.ByValue);
    arguments.accept(this);
  }

  void visitLocalVariablePrefix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    markUsed(element, CaptureMode.ByReference);
  }

  void visitLocalVariablePostfix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    markUsed(element, CaptureMode.ByReference);
  }

  void visitThisPropertyInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      _) {
    markThisUsed();
    arguments.accept(this);
  }

  void visitThisPropertyGet(
      Send node,
      Selector selector,
      _) {
    markThisUsed();
  }

  void visitThisGet(Node node, _) {
    markThisUsed();
  }

  void visitTopLevelFunctionInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitTopLevelFieldGet(Send node, FieldElement element, _) {
    // Intentionally empty: there is just nothing to visit in this case.
  }

  void visitTopLevelFieldInvoke(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitTopLevelFieldSet(
      SendSet node,
      FieldElement element,
      Node rhs,
      _) {
    rhs.accept(this);
  }

  void visitStaticFunctionInvoke(
      Send node,
      /* MethodElement */ element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitNewExpression(NewExpression node) {
    node.send.argumentsNode.accept(this);
  }

  void visitExpressionInvoke(
      Send node,
      Expression receiver,
      NodeList arguments,
      Selector selector,
      _) {
    receiver.accept(this);
    arguments.accept(this);
  }

  void visitDynamicPropertyInvoke(
      Send node,
      Node receiver,
      NodeList arguments,
      Selector selector,
      _) {
    receiver.accept(this);
    arguments.accept(this);
  }

  void visitDynamicPropertyGet(
      Send node,
      Node receiver,
      Selector selector,
      _) {
    receiver.accept(this);
  }

  void visitIs(Send node, Node expression, DartType type, _) {
    expression.accept(this);
  }

  void visitAs(Send node, Node expression, DartType type, _) {
    expression.accept(this);
  }

  void visitBinary(
      Send node,
      Node left,
      BinaryOperator operator,
      Node right,
      _) {
    left.accept(this);
    right.accept(this);
  }

  void visitIndexSet(
      SendSet node,
      Node receiver,
      Node index,
      Node value,
      _) {
    receiver.accept(this);
    index.accept(this);
    value.accept(this);
  }

  void visitEquals(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }

  void visitNotEquals(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }

  void visitLogicalAnd(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }
}
