// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.function_compiler;

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

import 'fletch_backend.dart';

import 'fletch_constants.dart' show
    CompiledFunctionConstant,
    FletchClassConstant;

import '../bytecodes.dart' show
    Bytecode;

import 'compiled_function.dart' show
    CompiledFunction;

import 'fletch_selector.dart';

import 'closure_environment.dart';

enum VisitState {
  Value,
  Effect,
  Test,
}

/**
 * A reference to a local value, including how it should be used
 * (loaded/stored).
 */
abstract class LocalValue {
  final int slot;
  final LocalElement element;
  LocalValue(this.slot, this.element);

  void initialize(BytecodeBuilder builder);

  void load(BytecodeBuilder builder);

  void store(BytecodeBuilder builder);
}

/**
 * A reference to a local value that is boxed.
 */
class BoxedLocalValue extends LocalValue {
  BoxedLocalValue(int slot, LocalElement element) : super(slot, element);

  void initialize(BytecodeBuilder builder) {
    builder.allocateBoxed();
  }

  void load(BytecodeBuilder builder) {
    builder.loadBoxedSlot(slot);
  }

  void store(BytecodeBuilder builder) {
    builder.storeBoxedSlot(slot);
  }

  String toString() => "Boxed($element, $slot)";
}

/**
 * A reference to a local value that is boxed.
 */
class UnboxedLocalValue extends LocalValue {
  UnboxedLocalValue(int slot, LocalElement element) : super(slot, element);

  void initialize(BytecodeBuilder builder) {}

  void load(BytecodeBuilder builder) {
    builder.loadSlot(slot);
  }

  void store(BytecodeBuilder builder) {
    builder.storeSlot(slot);
  }

  String toString() => "Local($element, $slot)";
}

class GotoTarget {
  final int stackSize;
  final BytecodeLabel continueLabel;
  final BytecodeLabel breakLabel;
  GotoTarget(this.stackSize, this.continueLabel, this.breakLabel);
}

class FunctionCompiler extends SemanticVisitor implements SemanticSendVisitor {
  final FletchContext context;

  final Registry registry;

  final ClosureEnvironment closureEnvironment;

  final FunctionElement function;

  final CompiledFunction compiledFunction;

  final Map<Element, LocalValue> scope = <Element, LocalValue>{};

  final List<GotoTarget> gotoTargets = <GotoTarget>[];

  VisitState visitState;
  BytecodeLabel trueLabel;
  BytecodeLabel falseLabel;

  // The slot at which 'this' is stored. In closures, this is overridden.
  int thisSlot;

  int blockLocals = 0;

  FunctionCompiler(int methodId,
                   this.context,
                   TreeElements elements,
                   this.registry,
                   this.closureEnvironment,
                   FunctionElement function)
      : super(elements),
        function = function,
        compiledFunction = new CompiledFunction(
            methodId,
            function.functionSignature,
            hasThisArgument(function)) {
    thisSlot = -1 - compiledFunction.builder.functionArity;
  }

  FunctionCompiler.forFactory(int methodId,
                              this.context,
                              TreeElements elements,
                              this.registry,
                              this.closureEnvironment,
                              FunctionElement function)
      : super(elements),
        function = function,
        compiledFunction = new CompiledFunction(
            methodId,
            function.functionSignature,
            false) {
    thisSlot = -1 - compiledFunction.builder.functionArity;
  }

  static bool hasThisArgument(FunctionElement function) {
    if (function.isInstanceMember ||
        function.isGenerativeConstructor) {
      // 'this' argument.
      return true;
    } else if (function.memberContext != function) {
      // 'closure' argument.
      return true;
    }
    return false;
  }

  BytecodeBuilder get builder => compiledFunction.builder;

  SemanticSendVisitor get sendVisitor => this;

  ConstantExpression compileConstant(Node node, {bool isConst}) {
    return context.compileConstant(node, elements, isConst: isConst);
  }

  int allocateConstantFromNode(Node node) {
    ConstantExpression expression = compileConstant(node, isConst: false);
    return compiledFunction.allocateConstant(expression.value);
  }

  int allocateStringConstant(String string) {
    return compiledFunction.allocateConstant(
        context.backend.constantSystem.createString(
            new DartString.literal(string)));
  }

  ClosureInfo get closureInfo => closureEnvironment.closures[function];

  LocalValue createLocalValueFor(
      LocalElement element,
      [int slot]) {
    if (slot == null) slot = builder.stackSize;
    if (closureEnvironment.shouldBeBoxed(element)) {
      return new BoxedLocalValue(slot, element);
    }
    return new UnboxedLocalValue(slot, element);
  }

  void compile() {
    FunctionSignature functionSignature = function.functionSignature;
    int parameterCount = functionSignature.parameterCount;
    int i = 0;
    functionSignature.orderedForEachParameter((FormalElement parameter) {
      int slot = i++ - parameterCount - 1;
      scope[parameter] = createLocalValueFor(parameter, slot);
    });

    ClosureInfo info = closureEnvironment.closures[function];
    if (info != null) {
      int index = 0;
      if (info.isThisFree) {
        thisSlot = builder.stackSize;
        builder.loadParameter(0);
        builder.loadField(index++);
      }
      for (LocalElement local in info.free) {
        scope[local] = createLocalValueFor(local);
        // TODO(ajohnsen): Use a specialized helper for loading the closure.
        builder.loadParameter(0);
        builder.loadField(index++);
      }
    }

    Node node = function.node;
    if (node != null) {
      node.body.accept(this);
    }

    // Emit implicit 'return null' if no terminator is present.
    if (!builder.endsWithTerminator) {
      builder.loadLiteralNull();
      builder.ret();
    }

    builder.methodEnd();
  }

  void invokeMethod(Selector selector) {
    registry.registerDynamicInvocation(selector);
    String symbol = context.getSymbolFromSelector(selector);
    int id = context.getSymbolId(symbol);
    int arity = selector.argumentCount;
    int fletchSelector = FletchSelector.encodeMethod(id, arity);
    builder.invokeMethod(fletchSelector, arity);
  }

  void invokeGetter(Selector selector) {
    registry.registerDynamicGetter(selector);
    String symbol = context.getSymbolFromSelector(selector);
    int id = context.getSymbolId(symbol);
    int fletchSelector = FletchSelector.encodeGetter(id);
    builder.invokeMethod(fletchSelector, 0);
  }

  void invokeSetter(Selector selector) {
    registry.registerDynamicSetter(selector);
    String symbol = context.getSymbolFromSelector(selector);
    int id = context.getSymbolId(symbol);
    int fletchSelector = FletchSelector.encodeSetter(id);
    builder.invokeMethod(fletchSelector, 1);
  }

  /**
   * Load the [arguments] for caling [function].
   *
   * Return the number of arguments pushed onto the stack.
   */
  int loadArguments(
      NodeList arguments,
      FunctionElement function) {
    assert(!function.isInstanceMember);
    FunctionSignature signature = function.functionSignature;
    if (signature.hasOptionalParameters &&
        signature.optionalParametersAreNamed) {
      generateUnimplementedError(
          function,
          "Unimplemented load of named arguments");
      return 1;
    }
    return loadPositionalArguments(arguments, function);
  }

  void loadThis() {
    builder.loadSlot(thisSlot);
  }

  /**
   * Load the [arguments] for caling [function], with potential optional
   * positional parameters.
   *
   * Return the number of arguments pushed onto the stack.
   */
  int loadPositionalArguments(
      NodeList arguments,
      FunctionElement function) {
    FunctionSignature signature = function.functionSignature;
    assert(!signature.optionalParametersAreNamed);
    int argumentCount = 0;
    for (Node argument in arguments) {
      argumentCount++;
      visitForValue(argument);
    }
    // TODO(ajohnsen): Create a generic way of loading arguments (including
    // named).
    if (signature.parameterCount > argumentCount) {
      int parameterCount = 0;
      signature.orderedForEachParameter((ParameterElement parameter) {
        if (parameterCount >= argumentCount) {
          assert(!parameter.isNamed);
          if (parameter.isOptional) {
            Expression initializer = parameter.initializer;
            if (initializer == null) {
              builder.loadLiteralNull();
            } else {
              visitForValue(initializer);
            }
          } else {
            generateUnimplementedError(
                arguments,
                "Arguments doesn't match parameters");
          }
        }
        parameterCount++;
      });
    }
    return signature.parameterCount;
  }

  // Visit the expression [node] with the result pushed on top of the stack.
  void visitForValue(Node node) {
    VisitState oldState = visitState;
    visitState = VisitState.Value;
    node.accept(this);
    visitState = oldState;
  }

  // Visit the expression [node] without the result pushed on top of the stack.
  void visitForEffect(Node node) {
    VisitState oldState = visitState;
    visitState = VisitState.Effect;
    node.accept(this);
    visitState = oldState;
  }

  // Visit the expression [node] with the result being a branch to either
  // [trueLabel] or [falseLabel].
  void visitForTest(
      Node node,
      BytecodeLabel trueLabel,
      BytecodeLabel falseLabel) {
    VisitState oldState = visitState;
    visitState = VisitState.Test;
    BytecodeLabel oldTrueLabel = this.trueLabel;
    this.trueLabel = trueLabel;
    BytecodeLabel oldFalseLabel = this.falseLabel;
    this.falseLabel = falseLabel;
    node.accept(this);
    visitState = oldState;
    this.trueLabel = oldTrueLabel;
    this.falseLabel = oldFalseLabel;
  }

  void applyVisitState() {
    if (visitState == VisitState.Effect) {
      builder.pop();
    } else if (visitState == VisitState.Test) {
      builder.branchIfTrue(trueLabel);
      builder.branch(falseLabel);
    }
  }

  void handleBinaryOperator(
      Node left,
      Node right,
      BinaryOperator operator,
      _) {
    visitForValue(left);
    visitForValue(right);
    Selector selector = new Selector.binaryOperator(operator.name);
    invokeMethod(selector);
  }

  void visitEquals(
      Send node,
      Node left,
      Node right,
      _) {
    // TODO(ajohnsen): Inject null check (in callee).
    handleBinaryOperator(left, right, BinaryOperator.EQ, _);
    applyVisitState();
  }

  void visitNotEquals(
      Send node,
      Node left,
      Node right,
      _) {
    handleBinaryOperator(left, right, BinaryOperator.EQ, _);
    builder.negate();
    applyVisitState();
  }

  void visitBinary(
      Send node,
      Node left,
      BinaryOperator operator,
      Node right,
      _) {
    handleBinaryOperator(left, right, operator, _);
    applyVisitState();
  }

  void visitLogicalAnd(
      Send node,
      Node left,
      Node right,
      _) {
    BytecodeLabel isFirstTrue = new BytecodeLabel();
    BytecodeLabel isTrue = new BytecodeLabel();
    BytecodeLabel isFalse = new BytecodeLabel();
    BytecodeLabel done = new BytecodeLabel();

    builder.loadLiteralFalse();

    visitForTest(left, isFirstTrue, isFalse);

    builder.bind(isFirstTrue);
    visitForTest(right, isTrue, isFalse);

    builder.bind(isTrue);
    builder.pop();
    builder.loadLiteralTrue();
    builder.bind(isFalse);

    applyVisitState();
  }

  void visitConditional(Conditional node) {
    BytecodeLabel isTrue = new BytecodeLabel();
    BytecodeLabel isFalse = new BytecodeLabel();
    BytecodeLabel done = new BytecodeLabel();

    builder.loadLiteralNull();

    visitForTest(node.condition, isTrue, isFalse);

    builder.bind(isTrue);
    builder.pop();
    visitForValue(node.thenExpression);
    builder.branch(done);

    builder.bind(isFalse);
    builder.pop();
    visitForValue(node.elseExpression);

    builder.bind(done);

    applyVisitState();
  }

  void visitIs(
      Send node,
      Node expression,
      DartType type,
      _) {
    // TODO(ajohnsen): Implement.
    builder.loadLiteralFalse();
    applyVisitState();
  }

  void visitAs(
      Send node,
      Node expression,
      DartType type,
      _) {
    // TODO(ajohnsen): To actual type check.
    visitForValue(expression);
    applyVisitState();
  }

  void visitThisGet(
      Node node,
      _) {
    loadThis();
    applyVisitState();
  }

  void inlineIdenticalCall(NodeList arguments) {
    assert(arguments.slowLength() == 2);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    builder.identical();
    applyVisitState();
  }

  void visitTopLevelFunctionInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      Selector selector,
      _) {
    if (element == context.compiler.identicalFunction) {
      inlineIdenticalCall(arguments);
      return;
    }
    if (element.isExternal) {
      // Patch known functions directly.
      if (element == context.compiler.backend.fletchExternalInvokeMain) {
        element = context.compiler.mainFunction;
      }
      // TODO(ajohnsen): Define a known set of external functions we allow
      // calls to?
    }
    int arity = loadArguments(arguments, element);
    registry.registerStaticInvocation(element);
    int methodId = context.backend.allocateMethodId(element);
    int constId = compiledFunction.allocateConstantFromFunction(methodId);
    builder.invokeStatic(constId, arity);
    applyVisitState();
  }

  void visitStaticFunctionInvoke(
      Send node,
      /* MethodElement */ element,
      NodeList arguments,
      Selector selector,
      _) {
    visitTopLevelFunctionInvoke(node, element, arguments, selector, _);
  }

  void visitTopLevelFieldInvoke(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector,
      _) {
    // TODO(ajohnsen): Handle initializer.
    int index = context.getStaticFieldIndex(element, function);
    builder.loadStatic(index);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(selector);
    applyVisitState();
  }

  void visitDynamicPropertyInvoke(
      Send node,
      Node receiver,
      NodeList arguments,
      Selector selector,
      _) {
    visitForValue(receiver);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(selector);
    applyVisitState();
  }

  void visitExpressionInvoke(
      Send node,
      Expression receiver,
      NodeList arguments,
      Selector selector,
      _) {
    visitForValue(receiver);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(selector);
    applyVisitState();
  }

  void visitThisPropertyInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      _) {
    loadThis();
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(selector);
    applyVisitState();
  }

  void visitDynamicPropertyGet(
      Send node,
      Node receiver,
      Selector selector,
      _) {
    visitForValue(receiver);
    invokeGetter(selector);
    applyVisitState();
  }

  void visitThisPropertyGet(
      Send node,
      Selector selector,
      _) {
    loadThis();
    invokeGetter(selector);
    applyVisitState();
  }

  void visitThisPropertySet(
      Send node,
      Selector selector,
      Node rhs,
      _) {
    builder.loadParameter(0);
    visitForValue(rhs);
    invokeSetter(selector);
    applyVisitState();
  }

  void visitTopLevelFieldGet(
      Send node,
      FieldElement element,
      _) {
    // TODO(ajohnsen): Handle initializer.
    int index = context.getStaticFieldIndex(element, function);
    builder.loadStatic(index);
    applyVisitState();
  }

  void visitDynamicPropertySet(
      Send node,
      Node receiver,
      Selector selector,
      Node rhs,
      _) {
    visitForValue(receiver);
    visitForValue(rhs);
    invokeSetter(selector);
    applyVisitState();
  }

  void visitTopLevelFieldSet(
      SendSet node,
      FieldElement element,
      Node rhs,
      _) {
    visitForValue(rhs);
    int index = context.getStaticFieldIndex(element, function);
    builder.storeStatic(index);
    applyVisitState();
  }

  void visitStringJuxtaposition(StringJuxtaposition node) {
    visitForValue(node.first);
    visitForValue(node.second);
    // TODO(ajohnsen): Cache these in context/backend.
    Selector concat = new Selector.binaryOperator('+');
    invokeMethod(concat);
    applyVisitState();
  }

  void visitStringInterpolation(StringInterpolation node) {
    // TODO(ajohnsen): Cache these in context/backend.
    Selector toString = new Selector.call('toString', null, 0);
    Selector concat = new Selector.binaryOperator('+');
    visitForValue(node.string);
    for (StringInterpolationPart part in node.parts) {
      visitForValue(part.expression);
      invokeMethod(toString);
      visitForValue(part.string);
      invokeMethod(concat);
      invokeMethod(concat);
    }
    applyVisitState();
  }

  void visitLiteralNull(LiteralNull node) {
    if (visitState == VisitState.Value) {
      builder.loadLiteralNull();
    } else if (visitState == VisitState.Test) {
      builder.branch(falseLabel);
    }
  }

  void visitLiteralBool(LiteralBool node) {
    var expression = compileConstant(node, isConst: false);
    bool isTrue = expression != null && expression.value.isTrue;

    if (visitState == VisitState.Value) {
      if (isTrue) {
        builder.loadLiteralTrue();
      } else {
        builder.loadLiteralFalse();
      }
    } else if (visitState == VisitState.Test) {
      builder.branch(isTrue ? trueLabel : falseLabel);
    }
  }

  void visitLiteral(Literal node) {
    if (visitState == VisitState.Value) {
      builder.loadConst(allocateConstantFromNode(node));
    } else if (visitState == VisitState.Test) {
      builder.branch(falseLabel);
    }
  }

  void visitLiteralString(LiteralString node) {
    if (visitState == VisitState.Value) {
      builder.loadConst(allocateConstantFromNode(node));
      registry.registerInstantiatedClass(
          context.compiler.backend.stringImplementation);
    } else if (visitState == VisitState.Test) {
      builder.branch(falseLabel);
    }
  }

  void visitParenthesizedExpression(ParenthesizedExpression node) {
    // Visit expression in the same VisitState.
    node.expression.accept(this);
  }

  void visitLocalVariableGet(
      Send node,
      LocalVariableElement element,
      _) {
    scope[element].load(builder);
    applyVisitState();
  }

  void visitLocalVariableSet(
      SendSet node,
      LocalVariableElement element,
      Node rhs,
      _) {
    visitForValue(rhs);
    scope[element].store(builder);
    applyVisitState();
  }

  void visitLocalVariableInvoke(
      Send node,
      LocalVariableElement element,
      NodeList arguments,
      Selector selector,
      _) {
    scope[element].load(builder);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(selector);
    applyVisitState();
  }

  void doLocalVariableIncrement(
      LocalVariableElement element,
      IncDecOperator operator,
      bool prefix) {
    // TODO(ajohnsen): Candidate for bytecode: Inc/Dec local with non-Smi
    // bailout.
    LocalValue value = scope[element];
    value.load(builder);
    // For postfix, keep local, unmodified version, to 'return' after store.
    if (!prefix) builder.dup();
    builder.loadLiteral(1);
    Selector selector = new Selector.binaryOperator(
        operator == IncDecOperator.INC ? '+' : '-');
    invokeMethod(selector);
    value.store(builder);
    if (!prefix) builder.pop();
    applyVisitState();
  }

  void visitLocalVariablePrefix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    doLocalVariableIncrement(element, operator, true);
  }

  void visitLocalVariablePostfix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    // If visitState is for effect, we can ignore the return value, thus always
    // generate code for the simpler 'prefix' case.
    bool prefix = (visitState == VisitState.Effect);
    doLocalVariableIncrement(element, operator, prefix);
  }

  void visitParameterGet(
      Send node,
      ParameterElement element,
      _) {
    visitLocalVariableGet(node, element, _);
  }

  void visitParameterSet(
      SendSet node,
      ParameterElement element,
      Node rhs,
      _) {
    visitLocalVariableSet(node, element, rhs, _);
  }

  void visitThrow(Throw node) {
    visitForValue(node.expression);
    builder.emitThrow();
    // TODO(ahe): It seems suboptimal that each throw is followed by a pop.
    applyVisitState();
  }

  void visitNewExpression(NewExpression node) {
    ConstructorElement constructor = elements[node.send];
    int arity = loadArguments(node.send.argumentsNode, constructor);
    if (constructor.isFactoryConstructor) {
      registry.registerStaticInvocation(constructor);
      int methodId = context.backend.allocateMethodId(constructor);
      int constId = compiledFunction.allocateConstantFromFunction(methodId);
      builder.invokeFactory(constId, arity);
    } else {
      int constructorId = context.backend.compileConstructor(
          constructor,
          elements,
          registry);
      int constId = compiledFunction.allocateConstantFromFunction(
          constructorId);
      registry.registerStaticInvocation(constructor);
      registry.registerInstantiatedType(elements.getType(node));
      builder.invokeStatic(constId, arity);
    }
    applyVisitState();
  }

  void visitFunctionExpression(FunctionExpression node) {
    FunctionElement function = elements[node];
    ClosureInfo info = closureEnvironment.closures[function];
    int fields = info.free.length;
    if (info.isThisFree) {
      fields++;
      loadThis();
    }
    CompiledClass compiledClass = context.backend.createStubClass(
        fields,
        context.backend.compiledObjectClass);
    for (LocalVariableElement element in info.free) {
      // Load the raw value (the 'Box' when by reference).
      builder.loadSlot(scope[element].slot);
    }
    int classConstant = compiledFunction.allocateConstantFromClass(
        compiledClass.id);
    builder.allocate(classConstant, fields);

    int methodId = context.backend.allocateMethodId(function);
    int arity = function.functionSignature.parameterCount;
    Selector selector = new Selector.call('call', null, arity);
    int fletchSelector = context.toFletchSelector(selector);
    compiledClass.methodTable[fletchSelector] = methodId;

    registry.registerStaticInvocation(function);
  }

  void visitExpression(Expression node) {
    generateUnimplementedError(
        node, "Missing visit of expression: ${node.runtimeType}");
  }

  void visitStatement(Node node) {
    Visitstate oldState = visitState;
    visitState = VisitState.Effect;
    generateUnimplementedError(
        node, "Missing visit of statement: ${node.runtimeType}");
    visitState = oldState;
  }

  void visitBlock(Block node) {
    int oldBlockLocals = blockLocals;
    blockLocals = 0;
    int stackSize = builder.stackSize;

    for (Node statement in node.statements) {
      statement.accept(this);
    }

    int stackSizeDifference = builder.stackSize - stackSize;
    if (stackSizeDifference != blockLocals) {
      internalError(
          node,
          "Unbalanced number of block locals and stack slots used by block.");
    }

    for (int i = 0; i < blockLocals; i++) {
      // TODO(ajohnsen): Pop range bytecode?
      builder.pop();
    }

    blockLocals = oldBlockLocals;
  }

  void visitEmptyStatement(EmptyStatement node) {
  }

  void visitExpressionStatement(ExpressionStatement node) {
    visitForEffect(node.expression);
  }

  void visitReturn(Return node) {
    Expression expression = node.expression;
    if (expression == null) {
      builder.loadLiteralNull();
    } else {
      visitForValue(expression);
    }
    builder.ret();
  }

  void visitBreakStatement(BreakStatement node) {
    // TODO(ajohnsen): Unify gotoTargets lookup.
    // TODO(ajohnsen): Handle break target.
    for (int i = gotoTargets.length - 1; i >= 0; i--) {
      GotoTarget target = gotoTargets[i];
      BytecodeLabel label = target.breakLabel;
      if (label == null) continue;
      int diff = builder.stackSize - target.stackSize;
      for (int j = 0; j < diff; j++) {
        builder.pop();
      }
      builder.branch(label);
      builder.applyStackSizeFix(diff);
      return;
    }
    generateUnimplementedError(node, "'break' not in loop");
  }

  void visitContinueStatement(ContinueStatement node) {
    // TODO(ajohnsen): Unify gotoTargets lookup.
    // TODO(ajohnsen): Handle continue target.
    for (int i = gotoTargets.length - 1; i >= 0; i--) {
      GotoTarget target = gotoTargets[i];
      BytecodeLabel label = target.continueLabel;
      if (label == null) continue;
      int diff = builder.stackSize - target.stackSize;
      for (int j = 0; j < diff; j++) {
        builder.pop();
      }
      builder.branch(label);
      builder.applyStackSizeFix(diff);
      return;
    }
    generateUnimplementedError(node, "'continue' not in loop");
  }

  void visitIf(If node) {
    BytecodeLabel ifTrue = new BytecodeLabel();
    BytecodeLabel ifFalse = new BytecodeLabel();
    visitForTest(node.condition, ifTrue, ifFalse);
    builder.bind(ifTrue);
    node.thenPart.accept(this);
    if (node.hasElsePart) {
      BytecodeLabel end = new BytecodeLabel();
      builder.branch(end);
      builder.bind(ifFalse);
      node.elsePart.accept(this);
      builder.bind(end);
    } else {
      builder.bind(ifFalse);
    }
  }

  void visitFor(For node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel ifTrue = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();

    Node initializer = node.initializer;
    if (initializer != null) visitForValue(initializer);

    builder.bind(start);

    Expression condition = node.condition;
    if (condition != null) {
      visitForTest(condition, ifTrue, end);
      builder.bind(ifTrue);
    }

    gotoTargets.add(new GotoTarget(builder.stackSize, start, end));
    node.body.accept(this);
    gotoTargets.removeLast();

    for (Node update in node.update) {
      visitForEffect(update);
    }
    builder.branch(start);

    builder.bind(end);
  }

  void visitWhile(While node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel ifTrue = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    builder.bind(start);
    visitForTest(node.condition, ifTrue, end);
    builder.bind(ifTrue);
    gotoTargets.add(new GotoTarget(builder.stackSize, start, end));
    node.body.accept(this);
    gotoTargets.removeLast();
    builder.branch(start);
    builder.bind(end);
  }

  void visitDoWhile(DoWhile node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    BytecodeLabel skipBody = new BytecodeLabel();
    builder.bind(start);
    gotoTargets.add(new GotoTarget(builder.stackSize, skipBody, end));
    node.body.accept(this);
    gotoTargets.removeLast();
    builder.bind(skipBody);
    visitForTest(node.condition, start, end);
    builder.bind(end);
  }

  void visitVariableDefinitions(VariableDefinitions node) {
    for (Node definition in node.definitions) {
      int slot = builder.stackSize;
      LocalVariableElement element = elements[definition];
      Expression initializer = element.initializer;
      if (initializer == null) {
        builder.loadLiteralNull();
      } else {
        visitForValue(initializer);
      }
      LocalValue value = createLocalValueFor(element, slot);
      value.initialize(builder);
      scope[element] = value;
      blockLocals++;
    }
  }

  void visitParameterInvocation(
      Send node,
      ParameterElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitParameterInvocation] isn't implemented.");
  }

  void visitLocalVariableInvocation(
      Send node,
      LocalVariableElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitLocalVariableInvocation] isn't implemented.");
  }

  void visitLocalFunctionAccess(
      Send node,
      LocalFunctionElement element) {
    generateUnimplementedError(
        node, "[visitLocalFunctionAccess] isn't implemented.");
  }

  void visitLocalFunctionAssignment(
      SendSet node,
      LocalFunctionElement element,
      Node rhs,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitLocalFunctionAssignment] isn't implemented.");
  }

  void visitLocalFunctionInvocation(
      Send node,
      LocalFunctionElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitLocalFunctionInvocation] isn't implemented.");
  }

  void visitDynamicAssignment(
      SendSet node,
      Selector selector,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitDynamicAssignment] isn't implemented.");
  }

  void visitStaticFieldInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitStaticFieldInvocation] isn't implemented.");
  }

  void visitStaticMethodAccess(
      Send node,
      MethodElement element) {
    generateUnimplementedError(
        node, "[visitStaticMethodAccess] isn't implemented.");
  }

  void visitStaticPropertyAccess(
      Send node,
      FunctionElement element) {
    generateUnimplementedError(
        node, "[visitStaticPropertyAccess] isn't implemented.");
  }

  void visitStaticPropertyAssignment(
      SendSet node,
      FunctionElement element,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitStaticPropertyAssignment] isn't implemented.");
  }

  void visitStaticPropertyInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitStaticPropertyInvocation] isn't implemented.");
  }

  void visitTopLevelFieldAccess(
      Send node,
      FieldElement element) {
    generateUnimplementedError(
        node, "[visitTopLevelFieldAccess] isn't implemented.");
  }

  void visitTopLevelFieldAssignment(
      SendSet node,
      FieldElement element,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitTopLevelFieldAssignment] isn't implemented.");
  }

  void visitTopLevelFieldInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitTopLevelFieldInvocation] isn't implemented.");
  }

  void visitTopLevelMethodAccess(
      Send node,
      MethodElement element) {
    generateUnimplementedError(
        node, "[visitTopLevelMethodAccess] isn't implemented.");
  }

  void visitTopLevelMethodInvocation(
      Send node,
      MethodElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitTopLevelMethodInvocation] isn't implemented.");
  }

  void visitTopLevelPropertyAccess(
      Send node,
      FunctionElement element) {
    generateUnimplementedError(
        node, "[visitTopLevelPropertyAccess] isn't implemented.");
  }

  void visitTopLevelPropertyAssignment(
      SendSet node,
      FunctionElement element,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitTopLevelPropertyAssignment] isn't implemented.");
  }

  void visitTopLevelPropertyInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitTopLevelPropertyInvocation] isn't implemented.");
  }

  void visitClassTypeLiteralAccess(
      Send node,
      ClassElement element) {
    generateUnimplementedError(
        node, "[visitClassTypeLiteralAccess] isn't implemented.");
  }

  void visitClassTypeLiteralInvocation(
      Send node,
      ClassElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitClassTypeLiteralInvocation] isn't implemented.");
  }

  void visitClassTypeLiteralAssignment(
      SendSet node,
      ClassElement element,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitClassTypeLiteralAssignment] isn't implemented.");
  }

  void visitTypedefTypeLiteralAccess(
      Send node,
      TypedefElement element) {
    generateUnimplementedError(
        node, "[visitTypedefTypeLiteralAccess] isn't implemented.");
  }

  void visitTypedefTypeLiteralInvocation(
      Send node,
      TypedefElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitTypedefTypeLiteralInvocation] isn't implemented.");
  }

  void visitTypedefTypeLiteralAssignment(
      SendSet node,
      TypedefElement element,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitTypedefTypeLiteralAssignment] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralAccess(
      Send node,
      TypeVariableElement element) {
    generateUnimplementedError(
        node, "[visitTypeVariableTypeLiteralAccess] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralInvocation(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      Selector selector) {
    generateUnimplementedError(
        node, "[visitTypeVariableTypeLiteralInvocation] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralAssignment(
      SendSet node,
      TypeVariableElement element,
      Node rhs) {
    generateUnimplementedError(
        node, "[visitTypeVariableTypeLiteralAssignment] isn't implemented.");
  }

  void visitDynamicTypeLiteralAccess(
      Send node) {
    generateUnimplementedError(
        node, "[visitDynamicTypeLiteralAccess] isn't implemented.");
  }

  void visitAssert(
      Send node,
      Node expression) {
    generateUnimplementedError(
        node, "[visitAssert] isn't implemented.");
  }

  void internalError(Spannable spannable, String reason) {
    context.compiler.internalError(spannable, reason);
  }

  void generateUnimplementedError(Spannable spannable, String reason) {
    context.compiler.backend.generateUnimplementedError(
        spannable,
        reason,
        compiledFunction);
    applyVisitState();
  }

  String toString() => "FunctionCompiler(${function.name})";
}
