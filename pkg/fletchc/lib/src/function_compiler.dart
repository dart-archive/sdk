// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.function_compiler;

import 'package:compiler/src/resolution/semantic_visitor.dart' show
    SemanticSendVisitor,
    SemanticVisitor;

import 'package:compiler/src/resolution/operators.dart' show
    AssignmentOperator,
    BinaryOperator,
    IncDecOperator,
    UnaryOperator;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression,
    TypeConstantExpression;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenRegistry,
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
  final Element element;
  LocalValue(this.slot, this.element);

  void initialize(BytecodeBuilder builder);

  void load(BytecodeBuilder builder);

  void store(BytecodeBuilder builder);
}

/**
 * A reference to a local value that is boxed.
 */
class BoxedLocalValue extends LocalValue {
  BoxedLocalValue(int slot, Element element) : super(slot, element);

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
  UnboxedLocalValue(int slot, Element element) : super(slot, element);

  void initialize(BytecodeBuilder builder) {}

  void load(BytecodeBuilder builder) {
    builder.loadSlot(slot);
  }

  void store(BytecodeBuilder builder) {
    builder.storeSlot(slot);
  }

  String toString() => "Local($element, $slot)";
}

class JumpInfo {
  final int stackSize;
  final BytecodeLabel continueLabel;
  final BytecodeLabel breakLabel;
  JumpInfo(this.stackSize, this.continueLabel, this.breakLabel);
}

class FunctionCompiler extends SemanticVisitor implements SemanticSendVisitor {
  final FletchContext context;

  final CodegenRegistry registry;

  final ClosureEnvironment closureEnvironment;

  final FunctionElement function;

  final CompiledFunction compiledFunction;

  final Map<Element, LocalValue> scope = <Element, LocalValue>{};

  final Map<Node, JumpInfo> jumpInfo = <Node, JumpInfo>{};

  VisitState visitState;
  BytecodeLabel trueLabel;
  BytecodeLabel falseLabel;

  // TODO(ajohnsen): Merge computation into constructor.
  // The slot at which 'this' is stored. In closures, this is overwritten.
  int thisSlot;

  int blockLocals = 0;

  FunctionCompiler(CompiledFunction compiledFunction,
                   this.context,
                   TreeElements elements,
                   this.registry,
                   this.closureEnvironment,
                   this.function)
      : super(elements),
        this.compiledFunction = compiledFunction,
        thisSlot = -1 - compiledFunction.builder.functionArity;

  FunctionCompiler.forFactory(CompiledFunction compiledFunction,
                              this.context,
                              TreeElements elements,
                              this.registry,
                              this.closureEnvironment,
                              this.function)
      : super(elements),
        this.compiledFunction = compiledFunction,
        thisSlot = -1 - compiledFunction.builder.functionArity;

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
    functionSignature.orderedForEachParameter((ParameterElement parameter) {
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

    FunctionExpression node = function.node;
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

  void staticFunctionCall(
      FunctionElement function,
      NodeList arguments,
      Selector selector) {
    registry.registerStaticInvocation(function);
    assert(!function.isInstanceMember);
    FunctionSignature signature = function.functionSignature;
    int methodId;
    int arity;
    if (signature.hasOptionalParameters &&
        signature.optionalParametersAreNamed) {
      CompiledFunction target = context.backend.createCompiledFunction(
          function,
          null,
          null);
      if (target.matchesSelector(selector)) {
        methodId = target.methodId;
      } else {
        // TODO(ajohnsen): Inline parameter mapping?
        CompiledFunction stub = target.createParameterMappingFor(
            selector, context);
        methodId = stub.methodId;
      }
      for (Node argument in arguments) {
        visitForValue(argument);
      }
      arity = selector.argumentCount;
    } else {
      methodId = context.backend.allocateMethodId(function);
      arity = loadPositionalArguments(arguments, function);
    }
    int constId = compiledFunction.allocateConstantFromFunction(methodId);
    builder.invokeStatic(constId, arity);
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

  void visitNamedArgument(NamedArgument node) {
    Expression expression = node.expression;
    if (expression != null) {
      visitForValue(expression);
    } else {
      builder.loadLiteralNull();
    }
    applyVisitState();
  }

  void handleBinaryOperator(
      Node left,
      Node right,
      BinaryOperator operator,
      _) {
    visitForValue(left);
    visitForValue(right);
    Selector selector;
    // TODO(ajohnsen): Remove once SemanticVisitor handle IndexGet seperately.
    if (operator == BinaryOperator.INDEX) {
      selector = new Selector.index();
    } else {
      selector = new Selector.binaryOperator(operator.name);
    }
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

  void visitUnary(
      Send node,
      UnaryOperator operator,
      Node value,
      _) {
    visitForValue(value);
    Selector selector = new Selector.unaryOperator(operator.name);
    invokeMethod(selector);
    applyVisitState();
  }

  void visitNot(
      Send node,
      Node value,
      _) {
    visitForValue(value);
    builder.negate();
    applyVisitState();
  }

  void visitIndexSet(
      SendSet node,
      Node receiver,
      Node index,
      Node value,
      _) {
    visitForValue(receiver);
    visitForValue(index);
    visitForValue(value);
    Selector selector = new Selector.indexSet();
    invokeMethod(selector);
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

  void visitLogicalOr(
      Send node,
      Node left,
      Node right,
      _) {
    BytecodeLabel isFirstFalse = new BytecodeLabel();
    BytecodeLabel isTrue = new BytecodeLabel();
    BytecodeLabel isFalse = new BytecodeLabel();
    BytecodeLabel done = new BytecodeLabel();

    builder.loadLiteralTrue();

    visitForTest(left, isTrue, isFirstFalse);

    builder.bind(isFirstFalse);
    visitForTest(right, isTrue, isFalse);

    builder.bind(isFalse);
    builder.pop();
    builder.loadLiteralFalse();
    builder.bind(isTrue);

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
      if (element == context.backend.fletchExternalInvokeMain) {
        element = context.compiler.mainFunction;
      }
      // TODO(ajohnsen): Define a known set of external functions we allow
      // calls to?
    }
    staticFunctionCall(element, arguments, selector);
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
    if (selector == null) {
      // TODO(ajohnsen): Remove hack - dart2js has a problem with generating
      // selectors in initializer bodies.
      selector = new Selector.getter(
          node.selector.asIdentifier().source,
          function.library);
    }
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

  void visitStaticFieldGet(
      Send node,
      FieldElement element,
      _) {
    // TODO(ajohnsen): Handle initializer.
    int index = context.getStaticFieldIndex(element, function);
    builder.loadStatic(index);
    applyVisitState();
  }

  void visitAssert(Send node, Node expression, _) {
    // TODO(ajohnsen): Emit assert in checked mode.
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
    // TODO(ajohnsen): This could probably be optimized to string constants in
    // some cases.
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

  void visitLiteralList(LiteralList node) {
    ClassElement growableClass = context.backend.growableListClass;
    ConstructorElement constructor = growableClass.lookupDefaultConstructor();
    if (constructor == null) {
      internalError(growableClass, "Failed to lookup default list constructor");
    }
    // Call with 0 arguments, as we call the default constructor.
    callConstructor(constructor, 0);
    Selector add = new Selector.call('add', null, 1);
    for (Node element in node.elements) {
      builder.dup();
      visitForValue(element);
      invokeMethod(add);
      builder.pop();
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

  void visitLocalFunctionGet(
      Send node,
      LocalFunctionElement element,
      _) {
    scope[element].load(builder);
    applyVisitState();
  }

  void visitLocalVariableSet(
      SendSet node,
      VariableElement element,
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

  void visitLocalFunctionInvoke(
      Send node,
      LocalFunctionElement element,
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
      VariableElement element,
      _) {
    visitLocalVariableGet(node, element, _);
  }

  void visitParameterSet(
      SendSet node,
      VariableElement element,
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

  void callConstructor(ConstructorElement constructor, int arity) {
    // TODO(ajohnsen): Use staticFunctionCall.
    int constructorId = context.backend.compileConstructor(
        constructor,
        elements,
        registry);
    int constId = compiledFunction.allocateConstantFromFunction(constructorId);
    registry.registerStaticInvocation(constructor);
    registry.registerInstantiatedClass(constructor.enclosingClass);
    builder.invokeStatic(constId, arity);
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
      callConstructor(constructor, arity);
    }
    applyVisitState();
  }

  /**
   * Load the captured variables of [function], expressed in [info].
   *
   * If [function] captures itself, its field index is returned.
   */
  int pushCapturedVariables(FunctionElement function) {
    ClosureInfo info = closureEnvironment.closures[function];
    int index = 0;
    if (info.isThisFree) {
      loadThis();
      index++;
    }
    int thisClosureIndex = -1;
    for (LocalElement element in info.free) {
      if (element == function) {
        // If we capture ourself, remember index and assign into closure after
        // allocation.
        builder.loadLiteralNull();
        assert(thisClosureIndex == -1);
        thisClosureIndex = index;
      } else {
        // Load the raw value (the 'Box' when by reference).
        builder.loadSlot(scope[element].slot);
      }
      index++;
    }
    return thisClosureIndex;
  }

  void visitFunctionExpression(FunctionExpression node) {
    FunctionElement function = elements[node];

    // If the closure captures itself, thisClosureIndex is the field-index in
    // the closure.
    int thisClosureIndex = pushCapturedVariables(function);

    CompiledClass compiledClass = context.backend.createClosureClass(
        function,
        closureEnvironment);
    int classConstant = compiledFunction.allocateConstantFromClass(
        compiledClass.id);
    builder.allocate(classConstant, compiledClass.fields);

    if (thisClosureIndex >= 0) {
      builder.dup();
      builder.storeField(thisClosureIndex);
    }

    registry.registerStaticInvocation(function);
  }

  void visitExpression(Expression node) {
    generateUnimplementedError(
        node, "Missing visit of expression: ${node.runtimeType}");
  }

  void visitStatement(Node node) {
    VisitState oldState = visitState;
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

  JumpInfo getJumpInfo(GotoStatement node) {
    JumpTarget target = elements.getTargetOf(node);
    if (target == null) {
      generateUnimplementedError(node, "'$node' not in loop");
      builder.pop();
      return null;
    }
    Node statement = target.statement;
    JumpInfo info = jumpInfo[statement];
    if (info == null) {
      generateUnimplementedError(node, "'$node' has no target");
      builder.pop();
    }
    return info;
  }

  void unbalancedBranch(GotoStatement node, bool isBreak) {
    JumpInfo info = getJumpInfo(node);
    if (info == null) return;
    BytecodeLabel label = isBreak ? info.breakLabel : info.continueLabel;
    int diff = builder.stackSize - info.stackSize;
    builder.popMany(diff);
    builder.branch(label);
    builder.applyStackSizeFix(diff);
  }

  void visitBreakStatement(BreakStatement node) {
    unbalancedBranch(node, true);
  }

  void visitContinueStatement(ContinueStatement node) {
    unbalancedBranch(node, false);
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

    jumpInfo[node] = new JumpInfo(builder.stackSize, start, end);

    builder.bind(start);

    Expression condition = node.condition;
    if (condition != null) {
      visitForTest(condition, ifTrue, end);
      builder.bind(ifTrue);
    }

    node.body.accept(this);

    for (Node update in node.update) {
      visitForEffect(update);
    }
    builder.branch(start);

    builder.bind(end);
  }

  void visitLabeledStatement(LabeledStatement node) {
    node.statement.accept(this);
  }

  void visitWhile(While node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel ifTrue = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    jumpInfo[node] = new JumpInfo(builder.stackSize, start, end);
    builder.bind(start);
    visitForTest(node.condition, ifTrue, end);
    builder.bind(ifTrue);
    node.body.accept(this);
    builder.branch(start);
    builder.bind(end);
  }

  void visitDoWhile(DoWhile node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    BytecodeLabel skipBody = new BytecodeLabel();
    jumpInfo[node] = new JumpInfo(builder.stackSize, skipBody, end);
    builder.bind(start);
    node.body.accept(this);
    builder.bind(skipBody);
    visitForTest(node.condition, start, end);
    builder.bind(end);
  }

  void initializeLocal(LocalElement element, Expression initializer) {
    int slot = builder.stackSize;
    if (initializer != null) {
      visitForValue(initializer);
    } else {
      builder.loadLiteralNull();
    }
    LocalValue value = createLocalValueFor(element, slot);
    value.initialize(builder);
    scope[element] = value;
    blockLocals++;
  }

  void visitVariableDefinitions(VariableDefinitions node) {
    for (Node definition in node.definitions) {
      LocalVariableElement element = elements[definition];
      initializeLocal(element, element.initializer);
    }
  }

  void visitFunctionDeclaration(FunctionDeclaration node) {
    FunctionExpression function = node.function;
    initializeLocal(elements[function], function);
  }

  void internalError(Spannable spannable, String reason) {
    context.compiler.internalError(spannable, reason);
  }

  void generateUnimplementedError(Spannable spannable, String reason) {
    context.backend.generateUnimplementedError(
        spannable,
        reason,
        compiledFunction);
    applyVisitState();
  }

  String toString() => "FunctionCompiler(${function.name})";


  void visitNode(Node node) {
    internalError(node, "[visitNode] isn't implemented.");
  }

  void apply(Node node, _) {
    internalError(node, "[apply] isn't implemented.");
  }

  void errorFinalParameterSet(
      SendSet node,
      ParameterElement parameter,
      Node rhs,
      _) {
    internalError(node, "[errorFinalParameterSet] isn't implemented.");
  }

  void visitParameterInvoke(
      Send node,
      ParameterElement parameter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitParameterInvoke] isn't implemented.");
  }

  void errorLocalFunctionSet(
      SendSet node,
      LocalFunctionElement function,
      Node rhs,
      _) {
    internalError(node, "[errorLocalFunctionSet] isn't implemented.");
  }

  void visitThisInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitThisInvoke] isn't implemented.");
  }

  void visitSuperFieldGet(
      Send node,
      FieldElement field,
      _) {
    internalError(node, "[visitSuperFieldGet] isn't implemented.");
  }

  void visitSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    internalError(node, "[visitSuperFieldSet] isn't implemented.");
  }

  void errorFinalSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    internalError(node, "[errorFinalSuperFieldSet] isn't implemented.");
  }

  void visitSuperFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitSuperFieldInvoke] isn't implemented.");
  }

  void visitSuperMethodGet(
      Send node,
      MethodElement method,
      _) {
    internalError(node, "[visitSuperMethodGet] isn't implemented.");
  }

  void visitSuperMethodInvoke(
      Send node,
      MethodElement method,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitSuperMethodInvoke] isn't implemented.");
  }

  void errorSuperMethodSet(
      Send node,
      MethodElement method,
      Node rhs,
      _) {
    internalError(node, "[errorSuperMethodSet] isn't implemented.");
  }

  void visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    internalError(node, "[visitSuperGetterGet] isn't implemented.");
  }

  void errorSuperSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    internalError(node, "[errorSuperSetterGet] isn't implemented.");
  }

  void visitSuperSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    internalError(node, "[visitSuperSetterSet] isn't implemented.");
  }

  void errorFinalLocalVariableSet(
      SendSet node,
      LocalVariableElement variable,
      Node rhs,
      _){
    internalError(node, "[errorFinalLocalVariableSet] isn't implemented.");
  }

  void errorSuperGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _){
    internalError(node, "[errorSuperGetterSet] isn't implemented.");
  }

  void visitSuperGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitSuperGetterInvoke] isn't implemented.");
  }

  void errorSuperSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[errorSuperSetterInvoke] isn't implemented.");
  }

  void visitStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _){
    internalError(node, "[visitStaticFieldSet] isn't implemented.");
  }

  void errorFinalStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _){
    internalError(node, "[errorFinalStaticFieldSet] isn't implemented.");
  }

  void visitStaticFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitStaticFieldInvoke] isn't implemented.");
  }

  void visitStaticFunctionGet(
      Send node,
      MethodElement function,
      _){
    internalError(node, "[visitStaticFunctionGet] isn't implemented.");
  }

  void errorStaticFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      _){
    internalError(node, "[errorStaticFunctionSet] isn't implemented.");
  }

  void visitStaticGetterGet(
      Send node,
      FunctionElement getter,
      _){
    internalError(node, "[visitStaticGetterGet] isn't implemented.");
  }

  void errorStaticSetterGet(
      Send node,
      FunctionElement setter,
      _){
    internalError(node, "[errorStaticSetterGet] isn't implemented.");
  }

  void visitStaticSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _){
    internalError(node, "[visitStaticSetterSet] isn't implemented.");
  }

  void errorStaticGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _){
    internalError(node, "[errorStaticGetterSet] isn't implemented.");
  }

  void visitStaticGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitStaticGetterInvoke] isn't implemented.");
  }

  void errorStaticSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[errorStaticSetterInvoke] isn't implemented.");
  }

  void errorFinalTopLevelFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _){
    internalError(node, "[errorFinalTopLevelFieldSet] isn't implemented.");
  }

  void visitTopLevelFunctionGet(
      Send node,
      MethodElement function,
      _){
    internalError(node, "[visitTopLevelFunctionGet] isn't implemented.");
  }

  void errorTopLevelFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      _){
    internalError(node, "[errorTopLevelFunctionSet] isn't implemented.");
  }

  void visitTopLevelGetterGet(
      Send node,
      FunctionElement getter,
      _){
    internalError(node, "[visitTopLevelGetterGet] isn't implemented.");
  }

  void errorTopLevelSetterGet(
      Send node,
      FunctionElement setter,
      _){
    internalError(node, "[errorTopLevelSetterGet] isn't implemented.");
  }

  void visitTopLevelSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _){
    internalError(node, "[visitTopLevelSetterSet] isn't implemented.");
  }

  void errorTopLevelGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _){
    internalError(node, "[errorTopLevelGetterSet] isn't implemented.");
  }

  void visitTopLevelGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitTopLevelGetterInvoke] isn't implemented.");
  }

  void errorTopLevelSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[errorTopLevelSetterInvoke] isn't implemented.");
  }

  void visitClassTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _){
    internalError(node, "[visitClassTypeLiteralGet] isn't implemented.");
  }

  void visitClassTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitClassTypeLiteralInvoke] isn't implemented.");
  }

  void errorClassTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _){
    internalError(node, "[errorClassTypeLiteralSet] isn't implemented.");
  }

  void visitTypedefTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _){
    internalError(node, "[visitTypedefTypeLiteralGet] isn't implemented.");
  }

  void visitTypedefTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitTypedefTypeLiteralInvoke] isn't implemented.");
  }

  void errorTypedefTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _){
    internalError(node, "[errorTypedefTypeLiteralSet] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralGet(
      Send node,
      TypeVariableElement element,
      _){
    internalError(node, "[visitTypeVariableTypeLiteralGet] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralInvoke(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      Selector selector,
      _){
    internalError(
        node, "[visitTypeVariableTypeLiteralInvoke] isn't implemented.");
  }

  void errorTypeVariableTypeLiteralSet(
      SendSet node,
      TypeVariableElement element,
      Node rhs,
      _){
    internalError(node, "[errorTypeVariableTypeLiteralSet] isn't implemented.");
  }

  void visitDynamicTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _){
    internalError(node, "[visitDynamicTypeLiteralGet] isn't implemented.");
  }

  void visitDynamicTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitDynamicTypeLiteralInvoke] isn't implemented.");
  }

  void errorDynamicTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _){
    internalError(node, "[errorDynamicTypeLiteralSet] isn't implemented.");
  }

  void errorInvalidAssert(
      Send node,
      NodeList arguments,
      _){
    internalError(node, "[errorInvalidAssert] isn't implemented.");
  }

  void visitSuperBinary(
      Send node,
      FunctionElement function,
      BinaryOperator operator,
      Node argument,
      _){
    internalError(node, "[visitSuperBinary] isn't implemented.");
  }

  void visitSuperNotEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _){
    internalError(node, "[visitSuperNotEquals] isn't implemented.");
  }

  void visitSuperEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _){
    internalError(node, "[visitSuperEquals] isn't implemented.");
  }

  void visitSuperUnary(
      Send node,
      UnaryOperator operator,
      FunctionElement function,
      _){
    internalError(node, "[visitSuperUnary] isn't implemented.");
  }

  void visitSuperIndexSet(
      Send node,
      FunctionElement function,
      Node index,
      Node rhs,
      _){
    internalError(node, "[visitSuperIndexSet] isn't implemented.");
  }

  void visitIsNot(
      Send node,
      Node expression,
      DartType type,
      _){
    internalError(node, "[visitIsNot] isn't implemented.");
  }

  void visitDynamicPropertyCompound(
      Send node,
      Node receiver,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      _){
    internalError(node, "[visitDynamicPropertyCompound] isn't implemented.");
  }

  void visitThisPropertyCompound(
      Send node,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      _){
    internalError(node, "[visitThisPropertyCompound] isn't implemented.");
  }

  void visitParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitParameterCompound] isn't implemented.");
  }

  void errorFinalParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorFinalParameterCompound] isn't implemented.");
  }

  void visitLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitLocalVariableCompound] isn't implemented.");
  }

  void errorFinalLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorFinalLocalVariableCompound] isn't implemented.");
  }

  void errorLocalFunctionCompound(
      Send node,
      LocalFunctionElement function,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorLocalFunctionCompound] isn't implemented.");
  }

  void visitStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitStaticFieldCompound] isn't implemented.");
  }

  void errorFinalStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorFinalStaticFieldCompound] isn't implemented.");
  }

  void visitStaticGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitStaticGetterSetterCompound] isn't implemented.");
  }

  void visitStaticMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitStaticMethodSetterCompound] isn't implemented.");
  }

  void visitTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitTopLevelFieldCompound] isn't implemented.");
  }

  void errorFinalTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorFinalTopLevelFieldCompound] isn't implemented.");
  }

  void visitTopLevelGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(
        node, "[visitTopLevelGetterSetterCompound] isn't implemented.");
  }

  void visitTopLevelMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(
        node, "[visitTopLevelMethodSetterCompound] isn't implemented.");
  }

  void visitSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitSuperFieldCompound] isn't implemented.");
  }

  void errorFinalSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorFinalSuperFieldCompound] isn't implemented.");
  }

  void visitSuperGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitSuperGetterSetterCompound] isn't implemented.");
  }

  void visitSuperMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitSuperMethodSetterCompound] isn't implemented.");
  }

  void visitSuperFieldSetterCompound(
      Send node,
      FieldElement field,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitSuperFieldSetterCompound] isn't implemented.");
  }

  void visitSuperGetterFieldCompound(
      Send node,
      FunctionElement getter,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitSuperGetterFieldCompound] isn't implemented.");
  }

  void visitClassTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitClassTypeLiteralCompound] isn't implemented.");
  }

  void visitTypedefTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitTypedefTypeLiteralCompound] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralCompound(
      Send node,
      TypeVariableElement element,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(
        node, "[visitTypeVariableTypeLiteralCompound] isn't implemented.");
  }

  void visitDynamicTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitDynamicTypeLiteralCompound] isn't implemented.");
  }

  void visitCompoundIndexSet(
      Send node,
      Node receiver,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitCompoundIndexSet] isn't implemented.");
  }

  void visitSuperCompoundIndexSet(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[visitSuperCompoundIndexSet] isn't implemented.");
  }

  void visitDynamicPropertyPrefix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _){
    internalError(node, "[visitDynamicPropertyPrefix] isn't implemented.");
  }

  void visitParameterPrefix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitParameterPrefix] isn't implemented.");
  }

  void errorLocalFunctionPrefix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      _){
    internalError(node, "[errorLocalFunctionPrefix] isn't implemented.");
  }


  void visitThisPropertyPrefix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _){
    internalError(node, "[visitThisPropertyPrefix] isn't implemented.");
  }

  void visitStaticFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitStaticFieldPrefix] isn't implemented.");
  }

  void visitStaticGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitStaticGetterSetterPrefix] isn't implemented.");
  }


  void visitStaticMethodSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitStaticMethodSetterPrefix] isn't implemented.");
  }

  void visitTopLevelFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitTopLevelFieldPrefix] isn't implemented.");
  }

  void visitTopLevelGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitTopLevelGetterSetterPrefix] isn't implemented.");
  }

  void visitTopLevelMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitTopLevelMethodSetterPrefix] isn't implemented.");
  }

  void visitSuperFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperFieldPrefix] isn't implemented.");
  }

  void visitSuperFieldFieldPrefix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperFieldFieldPrefix] isn't implemented.");
  }

  void visitSuperFieldSetterPrefix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperFieldSetterPrefix] isn't implemented.");
  }


  void visitSuperGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperGetterSetterPrefix] isn't implemented.");
  }

  void visitSuperGetterFieldPrefix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperGetterFieldPrefix] isn't implemented.");
  }

  void visitSuperMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperMethodSetterPrefix] isn't implemented.");
  }

  void visitClassTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _){
    internalError(node, "[visitClassTypeLiteralPrefix] isn't implemented.");
  }

  void visitTypedefTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _){
    internalError(node, "[visitTypedefTypeLiteralPrefix] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralPrefix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _){
    internalError(
        node, "[visitTypeVariableTypeLiteralPrefix] isn't implemented.");
  }

  void visitDynamicTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _){
    internalError(node, "[visitDynamicTypeLiteralPrefix] isn't implemented.");
  }

  void visitDynamicPropertyPostfix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _){
    internalError(node, "[visitDynamicPropertyPostfix] isn't implemented.");
  }

  void visitParameterPostfix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitParameterPostfix] isn't implemented.");
  }

  void errorLocalFunctionPostfix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      _){
    internalError(node, "[errorLocalFunctionPostfix] isn't implemented.");
  }


  void visitThisPropertyPostfix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _){
    internalError(node, "[visitThisPropertyPostfix] isn't implemented.");
  }

  void visitStaticFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitStaticFieldPostfix] isn't implemented.");
  }

  void visitStaticGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitStaticGetterSetterPostfix] isn't implemented.");
  }


  void visitStaticMethodSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitStaticMethodSetterPostfix] isn't implemented.");
  }

  void visitTopLevelFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitTopLevelFieldPostfix] isn't implemented.");
  }

  void visitTopLevelGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(
        node, "[visitTopLevelGetterSetterPostfix] isn't implemented.");
  }

  void visitTopLevelMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(
        node, "[visitTopLevelMethodSetterPostfix] isn't implemented.");
  }

  void visitSuperFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperFieldPostfix] isn't implemented.");
  }

  void visitSuperFieldFieldPostfix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperFieldFieldPostfix] isn't implemented.");
  }

  void visitSuperFieldSetterPostfix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperFieldSetterPostfix] isn't implemented.");
  }


  void visitSuperGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperGetterSetterPostfix] isn't implemented.");
  }

  void visitSuperGetterFieldPostfix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperGetterFieldPostfix] isn't implemented.");
  }

  void visitSuperMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _){
    internalError(node, "[visitSuperMethodSetterPostfix] isn't implemented.");
  }

  void visitClassTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _){
    internalError(node, "[visitClassTypeLiteralPostfix] isn't implemented.");
  }

  void visitTypedefTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _){
    internalError(node, "[visitTypedefTypeLiteralPostfix] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralPostfix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _){
    internalError(
        node, "[visitTypeVariableTypeLiteralPostfix] isn't implemented.");
  }

  void visitDynamicTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _){
    internalError(node, "[visitDynamicTypeLiteralPostfix] isn't implemented.");
  }

  void visitConstantGet(
      Send node,
      ConstantExpression constant,
      _){
    internalError(node, "[visitConstantGet] isn't implemented.");
  }

  void visitConstantInvoke(
      Send node,
      ConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[visitConstantInvoke] isn't implemented.");
  }

  void errorUnresolvedGet(
      Send node,
      Element element,
      _){
    internalError(node, "[errorUnresolvedGet] isn't implemented.");
  }

  void errorUnresolvedSet(
      Send node,
      Element element,
      Node rhs,
      _){
    internalError(node, "[errorUnresolvedSet] isn't implemented.");
  }

  void errorUnresolvedInvoke(
      Send node,
      Element element,
      NodeList arguments,
      Selector selector,
      _){
    internalError(node, "[errorUnresolvedInvoke] isn't implemented.");
  }

  void errorUnresolvedCompound(
      Send node,
      Element element,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(node, "[errorUnresolvedCompound] isn't implemented.");
  }

  void errorUnresolvedPrefix(
      Send node,
      Element element,
      IncDecOperator operator,
      _){
    internalError(node, "[errorUnresolvedPrefix] isn't implemented.");
  }

  void errorUnresolvedPostfix(
      Send node,
      Element element,
      IncDecOperator operator,
      _){
    internalError(node, "[errorUnresolvedPostfix] isn't implemented.");
  }

  void errorUnresolvedSuperIndexSet(
      Send node,
      Element element,
      Node index,
      Node rhs,
      _){
    internalError(node, "[errorUnresolvedSuperIndexSet] isn't implemented.");
  }

  void errorUnresolvedSuperCompoundIndexSet(
      Send node,
      Element element,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _){
    internalError(
        node, "[errorUnresolvedSuperCompoundIndexSet] isn't implemented.");
  }

  void errorUnresolvedSuperUnary(
      Send node,
      UnaryOperator operator,
      Element element,
      _){
    internalError(node, "[errorUnresolvedSuperUnary] isn't implemented.");
  }

  void errorUnresolvedSuperBinary(
      Send node,
      Element element,
      BinaryOperator operator,
      Node argument,
      _){
    internalError(node, "[errorUnresolvedSuperBinary] isn't implemented.");
  }

  void errorUndefinedUnaryExpression(
      Send node,
      Operator operator,
      Node expression,
      _){
    internalError(node, "[errorUndefinedUnaryExpression] isn't implemented.");
  }

  void errorUndefinedBinaryExpression(
      Send node,
      Node left,
      Operator operator,
      Node right,
      _){
    internalError(node, "[errorUndefinedBinaryExpression] isn't implemented.");
  }
}
