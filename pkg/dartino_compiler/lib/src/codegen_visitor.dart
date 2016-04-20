// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.codegen_visitor;

import 'package:compiler/src/resolution/semantic_visitor.dart';

import 'package:compiler/src/resolution/operators.dart' show
    AssignmentOperator,
    AssignmentOperatorKind,
    BinaryOperator,
    IncDecOperator,
    UnaryOperator;

import 'package:compiler/src/constants/expressions.dart' show
    BoolFromEnvironmentConstantExpression,
    IntFromEnvironmentConstantExpression,
    StringFromEnvironmentConstantExpression,
    ConstantExpression,
    ConstructedConstantExpression;

import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/util/util.dart' show
    Link;

import 'package:compiler/src/common/names.dart' show
    Names,
    Selectors;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/call_structure.dart' show
    CallStructure;
import 'package:compiler/src/universe/selector.dart' show
    Selector;
import 'package:compiler/src/diagnostics/spannable.dart' show
    Spannable;
import 'package:compiler/src/dart_types.dart';

import 'dartino_context.dart';

import 'dartino_backend.dart';

import 'dartino_constants.dart' show
    DartinoClassInstanceConstant;

import 'dartino_function_builder.dart' show
    DartinoFunctionBuilder;

import 'dartino_class_builder.dart' show
    DartinoClassBuilder;

import '../dartino_class_base.dart' show
    DartinoClassBase;

import 'dartino_selector.dart';

import '../dartino_system.dart';

import 'closure_environment.dart';

import '../incremental/dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed; // TODO(ahe): Remove this import.

import 'dartino_registry.dart' show
    ClosureKind,
    DartinoRegistry;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticMessage;

import 'package:compiler/src/diagnostics/messages.dart' show
    MessageKind;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    ConstructedConstantValue;

import 'dartino_system_base.dart' show
    DartinoSystemBase;

import 'dartino_system_builder.dart' show
    DartinoSystemBuilder;

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

  void initialize(BytecodeAssembler assembler);

  void load(BytecodeAssembler assembler);

  void loadRaw(BytecodeAssembler assembler) {
    load(assembler);
  }

  void store(BytecodeAssembler assembler);
}

/**
 * A reference to a local value that is boxed.
 */
class BoxedLocalValue extends LocalValue {
  BoxedLocalValue(int slot, Element element) : super(slot, element);

  void initialize(BytecodeAssembler assembler) {
    assembler.allocateBoxed();
  }

  void load(BytecodeAssembler assembler) {
    assembler.loadBoxedSlot(slot);
  }

  void loadRaw(BytecodeAssembler assembler) {
    assembler.loadSlot(slot);
  }

  void store(BytecodeAssembler assembler) {
    assembler.storeBoxedSlot(slot);
  }

  String toString() => "Boxed($element, $slot)";
}

/**
 * A reference to a local value that is boxed.
 */
class UnboxedLocalValue extends LocalValue {
  UnboxedLocalValue(int slot, Element element) : super(slot, element);

  void initialize(BytecodeAssembler assembler) {}

  void load(BytecodeAssembler assembler) {
    assembler.loadSlot(slot);
  }

  void store(BytecodeAssembler assembler) {
    assembler.storeSlot(slot);
  }

  String toString() => "Local($element, $slot)";
}

/**
 * A reference to a local value that is boxed.
 */
class BoxedParameterValue extends LocalValue {
  BoxedParameterValue(
      int parameter,
      Element element,
      BytecodeAssembler assembler)
      : super(assembler.computeParameterSlot(parameter), element);

  void initialize(BytecodeAssembler assembler) {
    assembler.allocateBoxed();
  }

  void load(BytecodeAssembler assembler) {
    assembler.loadBoxedParameterSlot(slot);
  }

  void loadRaw(BytecodeAssembler assembler) {
    assembler.loadParameterSlot(slot);
  }

  void store(BytecodeAssembler assembler) {
    assembler.storeBoxedParameterSlot(slot);
  }

  String toString() => "BoxedParameter($element, $slot)";
}

/**
 * A reference to a local value that is boxed.
 */
class UnboxedParameterValue extends LocalValue {
  UnboxedParameterValue(
      int parameter,
      Element element,
      BytecodeAssembler assembler)
      : super(assembler.computeParameterSlot(parameter), element);

  void initialize(BytecodeAssembler assembler) {}

  void load(BytecodeAssembler assembler) {
    assembler.loadParameterSlot(slot);
  }

  void store(BytecodeAssembler assembler) {
    assembler.storeParameterSlot(slot);
  }

  String toString() => "Parameter($element, $slot)";
}

class JumpInfo {
  final int stackSize;
  final BytecodeLabel continueLabel;
  final BytecodeLabel breakLabel;
  JumpInfo(this.stackSize, this.continueLabel, this.breakLabel);
}

class TryBlock {
  final int stackSize;
  final BytecodeLabel finallyLabel;
  final BytecodeLabel finallyReturnLabel;
  TryBlock(this.stackSize, this.finallyLabel, this.finallyReturnLabel);
}

abstract class CodegenVisitor
    extends SemanticVisitor
    with GetBulkMixin,
         SetBulkMixin,
         ErrorBulkMixin,
         InvokeBulkMixin,
         IndexSetBulkMixin,
         CompoundBulkMixin,
         UnaryBulkMixin,
         BaseBulkMixin,
         BinaryBulkMixin,
         PrefixBulkMixin,
         PostfixBulkMixin,
         NewBulkMixin,
         VariableBulkMixin,
         ParameterBulkMixin,
         FunctionBulkMixin,
         ConstructorBulkMixin,
         InitializerBulkMixin,
         BaseImplementationOfStaticsMixin,
         BaseImplementationOfLocalsMixin
    implements SemanticSendVisitor, SemanticDeclarationVisitor {
  // A literal int can have up to 31 bits of information (32 minus sign).
  static const int LITERAL_INT_MAX = 0x3FFFFFFF;
  static const int MAX_INT64 = (1 << 63) - 1;
  static const int MIN_INT64 = -(1 << 63);

  final DartinoContext context;

  final ClosureEnvironment closureEnvironment;

  final ExecutableElement element;

  final DartinoFunctionBuilder functionBuilder;

  final Map<Element, LocalValue> scope = <Element, LocalValue>{};

  final Map<Node, JumpInfo> jumpInfo = <Node, JumpInfo>{};

  // Stack of try blocks (inner-most first), in the lexical scope.
  Link<TryBlock> tryBlockStack = const Link<TryBlock>();

  VisitState visitState;
  BytecodeLabel trueLabel;
  BytecodeLabel falseLabel;

  // TODO(ajohnsen): Merge computation into constructor.
  // The slot at which 'this' is stored. In closures, this is overwritten.
  LocalValue thisValue;

  TreeElements initializerElements;

  List<Element> blockLocals = <Element>[];

  CodegenVisitor(
      this.functionBuilder,
      this.context,
      TreeElements elements,
      this.closureEnvironment,
      this.element)
      : super(elements) {
    if (functionBuilder.isInstanceMember) {
      thisValue = new UnboxedParameterValue(0, null, assembler);
    }
  }

  TreeElements get elements {
    if (initializerElements != null) return initializerElements;
    return super.elements;
  }

  BytecodeAssembler get assembler => functionBuilder.assembler;

  SemanticSendVisitor get sendVisitor => this;
  SemanticDeclarationVisitor get declVisitor => this;

  DartinoSystemBase get systemBase;

  void compile();

  ConstantValue evaluateAndUseConstant(
      Node node,
      {TreeElements elements,
       bool isConst}) {
    ConstantValue value =
        inspectConstant(node, elements: elements, isConst: isConst);
    if (value == null) return null;
    markConstantUsed(value);
    return value;
  }

  ConstantValue inspectConstant(
      Node node,
      {TreeElements elements,
       bool isConst}) {
    assert(isConst != null);
    if (elements == null) elements = this.elements;
    ConstantExpression expression =
        context.compiler.resolver.constantCompiler.compileNode(
            node, elements, enforceConst: isConst);
    if (expression == null) return null;
    return context.getConstantValue(expression);
  }

  bool isConstNull(Node node) {
    ConstantValue value = inspectConstant(node, isConst: false);
    return value == null ? false : value.isNull;
  }

  int allocateConstantFromNode(Node node, {TreeElements elements}) {
    return functionBuilder.allocateConstant(
        evaluateAndUseConstant(node, elements: elements, isConst: false));
  }

  int allocateConstantClassInstance(int classId) {
    var constant = new DartinoClassInstanceConstant(classId);
    markConstantUsed(constant);
    return functionBuilder.allocateConstant(constant);
  }

  int allocateStringConstant(String string) {
    return functionBuilder.allocateConstant(
        context.backend.constantSystem.createString(
            new DartString.literal(string)));
  }

  ClosureInfo get closureInfo => closureEnvironment.closures[element];

  LocalValue createLocalValueFor(
      LocalElement element,
      {int slot,
       bool isCapturedValueBoxed: true}) {
    if (slot == null) slot = assembler.stackSize;
    if (closureEnvironment.shouldBeBoxed(element)) {
      if (isCapturedValueBoxed) {
        return new BoxedLocalValue(slot, element);
      }
      LocalValue value = new BoxedLocalValue(assembler.stackSize, element);
      assembler.loadSlot(slot);
      value.initialize(assembler);
      return value;
    }

    return new UnboxedLocalValue(slot, element);
  }

  LocalValue createLocalValueForParameter(
      ParameterElement parameter,
      int index,
      {bool isCapturedValueBoxed: true}) {
    // TODO(kasperl): Use [ParameterElement.constant] instead when
    // [ConstantValue] can be computed on-the-fly from a [ConstantExpression].
    Expression initializer = parameter.initializer;
    if (initializer != null) {
      // If the parameter has an initializer expression, we ask the context
      // to compile it right away to make sure we enqueue all dependent
      // elements correctly before we start assembling the program.

      // TODO(ahe): We don't need to do this because parameter stubs also
      // register actually used constants.
      evaluateAndUseConstant(
          initializer, elements: parameter.memberContext.resolvedAst.elements,
          isConst: true);
    }

    if (closureEnvironment.shouldBeBoxed(parameter)) {
      if (isCapturedValueBoxed) {
        return new BoxedParameterValue(index, parameter, assembler);
      }
      LocalValue value = new BoxedLocalValue(assembler.stackSize, parameter);
      assembler.loadParameter(index);
      value.initialize(assembler);
      return value;
    }
    return new UnboxedParameterValue(index, parameter, assembler);
  }

  void pushVariableDeclaration(LocalValue value) {
    scope[value.element] = value;
  }

  void popVariableDeclaration(Element local) {
    scope.remove(local);
  }

  void registerDynamicSelector(Selector selector);

  void registerStaticInvocation(FunctionElement function);

  void registerInstantiatedClass(ClassElement klass);

  void registerIsCheck(DartType type);

  void registerLocalInvoke(LocalElement element, Selector selector);

  /// Register that [element] is a closure. This can happen for a tear-off, or
  /// for local functions. See [ClosureKind] for more information about the
  /// various kinds of implicit or explicit closurizations that can occur.
  void registerClosurization(FunctionElement element, ClosureKind kind);

  int compileLazyFieldInitializer(FieldElement field);

  DartinoClassBase getLocalFunctionClosureClass(
      FunctionElement function,
      ClosureInfo info);

  void markConstantUsed(ConstantValue constant);

  DartinoFunctionBase getParameterStub(
      DartinoFunctionBase function,
      Selector selector);

  void invokeMethod(Node node, Selector selector) {
    registerDynamicSelector(selector);
    String symbol = systemBase.getSymbolFromSelector(selector);
    int id = systemBase.getSymbolId(symbol);
    int arity = selector.argumentCount;
    int dartinoSelector = DartinoSelector.encodeMethod(id, arity);
    assembler.invokeMethod(dartinoSelector, arity, selector.name);
  }

  void invokeGetter(Node node, Name name) {
    registerDynamicSelector(new Selector.getter(name));
    String symbol = systemBase.mangleName(name);
    int id = systemBase.getSymbolId(symbol);
    int dartinoSelector = DartinoSelector.encodeGetter(id);
    assembler.invokeMethod(dartinoSelector, 0);
  }

  void invokeSetter(Node node, Name name) {
    registerDynamicSelector(new Selector.setter(name));
    String symbol = systemBase.mangleName(name);
    int id = systemBase.getSymbolId(symbol);
    int dartinoSelector = DartinoSelector.encodeSetter(id);
    assembler.invokeMethod(dartinoSelector, 1);
  }

  void invokeFactory(Node node, int constId, int arity) {
    assembler.invokeFactory(constId, arity);
  }

  void invokeStatic(Node node, int constId, int arity) {
    assembler.invokeStatic(constId, arity);
  }

  void generateIdentical(Node node) {
    assembler.identical();
  }

  void generateIdenticalNonNumeric(Node node) {
    assembler.identicalNonNumeric();
  }

  void generateReturn(Node node) {
    assembler.ret();
  }

  void generateReturnNull(Node node) {
    assembler.returnNull();
  }

  void generateThrow(Node node) {
    assembler.emitThrow();
  }

  void generateSwitchCaseMatch(CaseMatch caseMatch, BytecodeLabel ifTrue) {
    assembler.dup();
    int constId = allocateConstantFromNode(caseMatch.expression);
    assembler.loadConst(constId);
    // For debugging, ignore the equality checks in connection
    // with case matches by not associating the calls with
    // any node.
    invokeMethod(null, new Selector.binaryOperator('=='));
    assembler.branchIfTrue(ifTrue);
  }

  DartinoFunctionBase requireFunction(FunctionElement element) {
    registerStaticInvocation(element);
    return context.backend.getFunctionForElement(element);
  }

  DartinoFunctionBase requireConstructorInitializer(
      ConstructorElement constructor) {
    assert(constructor.isGenerativeConstructor);
    registerInstantiatedClass(constructor.enclosingClass);
    registerStaticInvocation(constructor);
    return context.backend.getConstructorInitializerFunction(constructor);
  }

  void doStaticFunctionInvoke(
      Node node,
      DartinoFunctionBase function,
      NodeList arguments,
      CallStructure callStructure,
      {bool factoryInvoke: false}) {
    if (function.isInstanceMember) loadThis();
    FunctionSignature signature = function.signature;
    int functionId;
    int arity;
    if (signature.hasOptionalParameters &&
        signature.optionalParametersAreNamed) {
      if (DartinoBackend.isExactParameterMatch(signature, callStructure)) {
        functionId = function.functionId;
      } else if (callStructure.signatureApplies(signature)) {
        // TODO(ajohnsen): Inline parameter stub?
        DartinoFunctionBase stub =
            getParameterStub(function, callStructure.callSelector);
        functionId = stub.functionId;
      } else {
        doUnresolved(function.name);
        return;
      }
      for (Node argument in arguments) {
        visitForValue(argument);
      }
      arity = callStructure.argumentCount;
    } else if (callStructure != null &&
               callStructure.namedArguments.isNotEmpty) {
      doUnresolved(function.name);
      return;
    } else {
      functionId = function.functionId;
      arity = loadPositionalArguments(arguments, signature, function.name);
    }
    if (function.isInstanceMember) arity++;
    int constId = functionBuilder.allocateConstantFromFunction(functionId);
    if (factoryInvoke) {
      invokeFactory(node, constId, arity);
    } else {
      invokeStatic(node, constId, arity);
    }
  }

  void loadThis() {
    if (thisValue == null) {
      // If this happens, most probably the closure environment has not been
      // created correctly.
      internalError(null, "Failed to look up 'this'");
    }
    thisValue.load(assembler);
  }

  /**
   * Load the [arguments] for caling [function], with potential positional
   * arguments.
   *
   * Return the number of arguments pushed onto the stack.
   */
  int loadPositionalArguments(
      NodeList arguments,
      FunctionSignature signature,
      String name) {
    int argumentCount = 0;
    Iterator<Node> it = arguments.iterator;
    signature.orderedForEachParameter((ParameterElement parameter) {
      if (it.moveNext()) {
        visitForValue(it.current);
      } else {
        if (parameter.isOptional) {
          doParameterInitializer(parameter);
        } else {
          doUnresolved(name);
        }
      }
      argumentCount++;
    });
    if (it.moveNext()) doUnresolved(name);
    return argumentCount;
  }

  void doParameterInitializer(ParameterElement parameter) {
    Expression initializer = parameter.initializer;
    if (initializer == null) {
      assembler.loadLiteralNull();
    } else {
      var previousElements = initializerElements;
      initializerElements = parameter.resolvedAst.elements;
      visitForValue(initializer);
      initializerElements = previousElements;
    }
  }

  void doVisitForValue(Node node) {
    VisitState oldState = visitState;
    visitState = VisitState.Value;
    node.accept(this);
    visitState = oldState;
  }

  // Visit the expression [node] and push the result on top of the stack.
  void visitForValue(Node node) {
    doVisitForValue(node);
  }

  // Visit the expression [node] and push the result on top of the stack.
  // This method bypasses debug information collection and using this
  // method will not generate breakpoints for the expression evaluation.
  // This is useful when dealing with internal details that the programmer
  // shouldn't care about such as the string concatenation aspects of
  // of string interpolation.
  void visitForValueNoDebugInfo(Node node) {
    doVisitForValue(node);
  }

  // Visit the expression [node] without pushing the result on top of the stack.
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

    assert(trueLabel != null || falseLabel != null);
    node.accept(this);

    visitState = oldState;
    this.trueLabel = oldTrueLabel;
    this.falseLabel = oldFalseLabel;
  }

  void negateTest() {
    assert(visitState == VisitState.Test);
    BytecodeLabel temporary = trueLabel;
    trueLabel = falseLabel;
    falseLabel = temporary;
  }

  void applyVisitState() {
    if (visitState == VisitState.Effect) {
      assembler.pop();
    } else if (visitState == VisitState.Test) {
      if (trueLabel == null) {
        assembler.branchIfFalse(falseLabel);
      } else if (falseLabel == null) {
        assembler.branchIfTrue(trueLabel);
      } else {
        assembler.branchIfTrue(trueLabel);
        assembler.branch(falseLabel);
      }
    }
  }

  void visitNamedArgument(NamedArgument node) {
    Expression expression = node.expression;
    if (expression != null) {
      visitForValue(expression);
    } else {
      assembler.loadLiteralNull();
    }
    applyVisitState();
  }

  void doLocalVariableCompound(
      Node node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs) {
    LocalValue value = scope[variable];
    value.load(assembler);
    visitForValue(rhs);
    String operatorName = operator.binaryOperator.name;
    invokeMethod(node, new Selector.binaryOperator(operatorName));
    value.store(assembler);
  }

  void visitLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _) {
    doLocalVariableCompound(node, variable, operator, rhs);
    applyVisitState();
  }

  void visitParameterCompound(
      Send node,
      LocalParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    doLocalVariableCompound(node, parameter, operator, rhs);
    applyVisitState();
  }

  void doStaticFieldCompound(
      Node node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs) {
    doStaticFieldGet(field);
    visitForValue(rhs);
    Selector selector = new Selector.binaryOperator(
        operator.binaryOperator.name);
    invokeMethod(node, selector);
    doStaticFieldSet(field);
  }

  void visitTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    doStaticFieldCompound(node, field, operator, rhs);
    applyVisitState();
  }

  void visitStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    doStaticFieldCompound(node, field, operator, rhs);
    applyVisitState();
  }

  void doBinaryOperator(
      Node node,
      Node left,
      Node right,
      BinaryOperator operator) {
    visitForValue(left);
    visitForValue(right);
    // For '==', if either side is a null literal, use identicalNonNumeric.
    if (operator == BinaryOperator.EQ &&
        (isConstNull(left) || isConstNull(right))) {
      generateIdenticalNonNumeric(node);
      return;
    }

    Selector selector = new Selector.binaryOperator(operator.name);
    invokeMethod(node, selector);
  }

  void visitEquals(
      Send node,
      Node left,
      Node right,
      _) {
    // TODO(ajohnsen): Inject null check (in callee).
    doBinaryOperator(node, left, right, BinaryOperator.EQ);
    applyVisitState();
  }

  void visitNotEquals(
      Send node,
      Node left,
      Node right,
      _) {
    doBinaryOperator(node, left, right, BinaryOperator.EQ);
    if (visitState == VisitState.Test) {
      negateTest();
    } else {
      assembler.negate();
    }
    applyVisitState();
  }

  void visitBinary(
      Send node,
      Node left,
      BinaryOperator operator,
      Node right,
      _) {
    doBinaryOperator(node, left, right, operator);
    applyVisitState();
  }

  void visitUnary(
      Send node,
      UnaryOperator operator,
      Node value,
      _) {
    visitForValue(value);
    Selector selector = new Selector.unaryOperator(operator.name);
    invokeMethod(node, selector);
    applyVisitState();
  }

  void visitNot(
      Send node,
      Node value,
      _) {
    if (visitState == VisitState.Test) {
      visitForTest(value, falseLabel, trueLabel);
    } else {
      visitForValue(value);
      assembler.negate();
      applyVisitState();
    }
  }

  void visitIndex(
      Send node,
      Node receiver,
      Node index,
      _) {
    visitForValue(receiver);
    visitForValue(index);
    Selector selector = new Selector.index();
    invokeMethod(node, selector);
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
    invokeMethod(node, selector);
    applyVisitState();
  }

  void visitLogicalAnd(
      Send node,
      Node left,
      Node right,
      _) {
    if (visitState == VisitState.Test) {
      if (falseLabel == null) {
        BytecodeLabel ifFalse = new BytecodeLabel();
        visitForTest(left, null, ifFalse);
        visitForTest(right, trueLabel, null);
        assembler.bind(ifFalse);
      } else {
        visitForTest(left, null, falseLabel);
        visitForTest(right, trueLabel, falseLabel);
      }
      return;
    }

    BytecodeLabel isFalse = new BytecodeLabel();
    assembler.loadLiteralFalse();

    visitForTest(left, null, isFalse);
    visitForTest(right, null, isFalse);
    assembler.pop();
    assembler.loadLiteralTrue();

    assembler.bind(isFalse);
    applyVisitState();
  }

  void visitLogicalOr(
      Send node,
      Node left,
      Node right,
      _) {
    if (visitState == VisitState.Test) {
      if (trueLabel == null) {
        BytecodeLabel ifTrue = new BytecodeLabel();
        visitForTest(left, ifTrue, null);
        visitForTest(right, null, falseLabel);
        assembler.bind(ifTrue);
      } else {
        visitForTest(left, trueLabel, null);
        visitForTest(right, trueLabel, falseLabel);
      }
      return;
    }

    BytecodeLabel isTrue = new BytecodeLabel();
    assembler.loadLiteralTrue();

    visitForTest(left, isTrue, null);
    visitForTest(right, isTrue, null);
    assembler.pop();
    assembler.loadLiteralFalse();

    assembler.bind(isTrue);
    applyVisitState();
  }

  void visitConditional(Conditional node) {
    BytecodeLabel isFalse = new BytecodeLabel();
    BytecodeLabel done = new BytecodeLabel();

    assembler.loadLiteralNull();

    visitForTest(node.condition, null, isFalse);

    assembler.pop();
    visitForValue(node.thenExpression);
    assembler.branch(done);

    assembler.bind(isFalse);
    assembler.pop();
    visitForValue(node.elseExpression);

    assembler.bind(done);

    applyVisitState();
  }

  void callIsSelector(
      Node node,
      DartType type,
      // TODO(ahe): Remove [diagnosticLocation] when malformed types are
      // handled.
      Spannable diagnosticLocation) {
    if (type == null || type.isMalformed) {
      assembler.pop();
      generateUnimplementedError(
          diagnosticLocation, "Unhandled type test for malformed $type.");
      return;
    }

    registerIsCheck(type);

    if (type.isDynamic) {
      assembler.pop();
      assembler.loadLiteralTrue();
      return;
    }

    if (type.isTypedef) {
      // TODO(ajohnsen): This only matches with the number of arguments, not
      // the actual argument types.
      TypedefType typedefType = type;
      int arity = typedefType.element.functionSignature.parameterCount;
      int dartinoSelector = systemBase.toDartinoIsSelector(
          context.backend.compiler.coreClasses.functionClass, arity);
      assembler.invokeTest(dartinoSelector, 0);
      return;
    }

    if (!type.isInterfaceType) {
      assembler.pop();
      generateUnimplementedError(
          diagnosticLocation, "Unhandled type test for $type.");
      return;
    }

    Element element = type.element;
    int dartinoSelector = systemBase.toDartinoIsSelector(element);
    assembler.invokeTest(dartinoSelector, 0);
  }

  void doIs(
      Node node,
      Node expression,
      DartType type,
      // TODO(ahe): Remove [diagnosticLocation] when callIsSelector does not
      // require it.
      Spannable diagnosticLocation) {
    visitForValue(expression);
    callIsSelector(node, type, diagnosticLocation);
  }

  void visitIs(
      Send node,
      Node expression,
      DartType type,
      _) {
    doIs(node, expression, type, node.arguments.first);
    applyVisitState();
  }

  void visitIsNot(
      Send node,
      Node expression,
      DartType type,
      _) {
    doIs(node, expression, type, node.arguments.first);
    if (visitState == VisitState.Test) {
      negateTest();
    } else {
      assembler.negate();
    }
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

  void doIdenticalCall(Node node, NodeList arguments) {
    assert(arguments.slowLength() == 2);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    generateIdentical(node);
  }

  void doStaticFunctionGet(Send node, MethodElement function) {
    registerClosurization(function, ClosureKind.tearOff);
    DartinoFunctionBase target = requireFunction(function);
    DartinoClassBase classBase = context.backend.getTearoffClass(target);
    assert(classBase.fieldCount == 0);
    int constId = allocateConstantClassInstance(classBase.classId);
    assembler.loadConst(constId);
  }

  void handleStaticFunctionGet(
      Send node,
      MethodElement function,
      _) {
    doStaticFunctionGet(node, function);
    applyVisitState();
  }

  void doMainCall(Send node, NodeList arguments) {
    FunctionElement function = context.compiler.mainFunction;
    if (function.isMalformed) {
      List<DiagnosticMessage> messages =
          context.compiler.elementsWithCompileTimeErrors[function];
      DiagnosticMessage message;
      if (messages == null) {
        // TODO(johnniwinther): The error should always be associated with the
        // element.
        // Example triggering this:
        // ```
        // [
        // main() {}
        // ```
        message = context.compiler.reporter.createMessage(
            function, MessageKind.GENERIC, {'text': 'main is malformed.'});
      } else {
        message = messages.first;
      }
      doCompileError(message);
      return;
    }
    if (context.compiler.libraryLoader.libraries.any(checkCompileError)) return;

    // Load up to 'parameterCount' arguments, padding with nulls.
    int parameterCount = function.functionSignature.parameterCount;
    int argumentCount = 0;
    for (Node argument in arguments) {
      if (argumentCount == parameterCount) break;
      visitForValue(argument);
      argumentCount++;
    }
    for (int i = argumentCount; i < parameterCount; i++) {
      assembler.loadLiteralNull();
    }

    DartinoFunctionBase base = requireFunction(function);
    int constId = functionBuilder.allocateConstantFromFunction(base.functionId);
    invokeStatic(node, constId, parameterCount);
  }

  void doStaticallyBoundInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      CallStructure callStructure) {
    if (checkCompileError(element)) return;
    if (element.declaration == context.compiler.identicalFunction) {
      doIdenticalCall(node, arguments);
      return;
    }
    if (element.isExternal) {
      // Patch known functions directly.
      if (element == context.backend.dartinoExternalInvokeMain) {
        doMainCall(node, arguments);
        return;
      } else if (element == context.backend.dartinoExternalCoroutineChange) {
        for (Node argument in arguments) {
          visitForValue(argument);
        }
        assembler.coroutineChange();
        return;
      }
      // TODO(ajohnsen): Define a known set of external functions we allow
      // calls to?
    }
    DartinoFunctionBase target = requireFunction(element);
    doStaticFunctionInvoke(node, target, arguments, callStructure);
  }

  void handleStaticFunctionInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    doStaticallyBoundInvoke(
        node, element.declaration, arguments, callStructure);
    applyVisitState();
  }

  void visitSuperMethodInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    doStaticallyBoundInvoke(node, element, arguments, callStructure);
    applyVisitState();
  }

  void doSuperCall(Node node, FunctionElement function) {
    registerStaticInvocation(function);
    int arity = function.functionSignature.parameterCount + 1;
    DartinoFunctionBase base = requireFunction(function);
    int constId = functionBuilder.allocateConstantFromFunction(base.functionId);
    invokeStatic(node, constId, arity);
  }

  void visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    loadThis();
    doSuperCall(node, getter);
    applyVisitState();
  }

  void doSuperMethodGet(
      Send node,
      MethodElement method) {
    registerClosurization(method, ClosureKind.superTearOff);
    loadThis();
    DartinoFunctionBase target = requireFunction(method);
    DartinoClassBase classBase = context.backend.getTearoffClass(target);
    assert(classBase.fieldCount == 1);
    int constId = functionBuilder.allocateConstantFromClass(classBase.classId);
    assembler.allocate(constId, classBase.fieldCount);
  }

  void visitSuperMethodGet(
      Send node,
      MethodElement method,
      _) {
    doSuperMethodGet(node, method);
    applyVisitState();
  }

  void visitSuperSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    loadThis();
    visitForValue(rhs);
    doSuperCall(node, setter);
    applyVisitState();
  }

  void visitSuperIndex(
      Send node,
      FunctionElement function,
      Node index,
      _) {
    loadThis();
    visitForValue(index);
    doSuperCall(node, function);
    applyVisitState();
  }

  void visitSuperIndexSet(
      Send node,
      FunctionElement function,
      Node index,
      Node rhs,
      _) {
    loadThis();
    visitForValue(index);
    visitForValue(rhs);
    doSuperCall(node, function);
    applyVisitState();
  }

  void visitSuperCompoundIndexSet(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    visitForValue(index);
    loadThis();
    assembler.loadLocal(1);
    doSuperCall(node, getter);
    loadThis();
    // Load index
    assembler.loadLocal(2);
    // Load value from index call and call operator.
    assembler.loadLocal(2);
    visitForValue(rhs);
    invokeMethod(node, getAssignmentSelector(operator));
    doSuperCall(node, setter);
    // Override 'index' with result value, and pop everything else.
    assembler.storeLocal(2);
    assembler.popMany(2);
    applyVisitState();
  }

  void visitSuperIndexPostfix(
      SendSet node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      IncDecOperator operator,
      _) {
    // TODO(ajohnsen): Fast-case when for effect.
    visitForValue(index);
    loadThis();
    assembler.loadLocal(1);
    doSuperCall(node, getter);
    loadThis();
    // Load index
    assembler.loadLocal(2);
    // Load value from index call and inc/dec.
    assembler.loadLocal(2);
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    // We can now call []= with 'this', 'index' and 'value'.
    doSuperCall(node, setter);
    assembler.pop();
    // Pop result, override 'index' with initial indexed value, and pop again.
    assembler.storeLocal(1);
    assembler.pop();
    applyVisitState();
  }

  void visitSuperBinary(
      Send node,
      FunctionElement function,
      BinaryOperator operator,
      Node argument,
      _) {
    loadThis();
    visitForValue(argument);
    doSuperCall(node, function);
    applyVisitState();
  }

  void visitSuperEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    loadThis();
    visitForValue(argument);
    doSuperCall(node, function);
    applyVisitState();
  }

  void visitSuperUnary(
      Send node,
      UnaryOperator operator,
      FunctionElement function,
      _) {
    loadThis();
    doSuperCall(node, function);
    applyVisitState();
  }

  int computeFieldIndex(FieldElement field) {
    ClassElement classElement = element.enclosingClass;
    int fieldIndex;
    DartinoClassBuilder classBuilder;
    do {
      // We need to find the mixin application of the class, where the field
      // is stored. Iterate until it's found.
      classBuilder = systemBase.getClassBuilder(classElement);
      classElement = classElement.implementation;
      int i = 0;
      classElement.forEachInstanceField((_, FieldElement member) {
        if (member == field) {
          assert(fieldIndex == null);
          fieldIndex = i;
        }
        i++;
      });
      classElement = classElement.superclass;
    } while (fieldIndex == null);
    fieldIndex += classBuilder.superclassFields;
    return fieldIndex;
  }

  void visitSuperFieldGet(
      Send node,
      FieldElement field,
      _) {
    loadThis();
    assembler.loadField(computeFieldIndex(field));
    applyVisitState();
  }

  void visitSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    loadThis();
    visitForValue(rhs);
    assembler.storeField(computeFieldIndex(field));
    applyVisitState();
  }

  void handleStaticFieldInvoke(
      Node node,
      FieldElement field,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    doStaticFieldGet(field);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(node, callStructure.callSelector);
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
    invokeMethod(node, selector);
    applyVisitState();
  }

  void visitIfNull(
      Send node,
      Node left,
      Node right,
      _) {
    BytecodeLabel end = new BytecodeLabel();
    visitForValue(left);
    assembler.dup();
    assembler.loadLiteralNull();
    assembler.identicalNonNumeric();
    assembler.branchIfFalse(end);
    assembler.pop();
    visitForValue(right);
    assembler.bind(end);
    applyVisitState();
  }

  void doIfNotNull(Node receiver, void ifNotNull()) {
    BytecodeLabel end = new BytecodeLabel();
    visitForValue(receiver);
    assembler.dup();
    assembler.loadLiteralNull();
    assembler.identicalNonNumeric();
    assembler.branchIfTrue(end);
    ifNotNull();
    assembler.bind(end);
  }

  void visitIfNotNullDynamicPropertyInvoke(
      Send node,
      Node receiver,
      NodeList arguments,
      Selector selector,
      _) {
    doIfNotNull(receiver, () {
      for (Node argument in arguments) {
        visitForValue(argument);
      }
      invokeMethod(node, selector);
    });
    applyVisitState();
  }

  void visitExpressionInvoke(
      Send node,
      Expression receiver,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    visitForValue(receiver);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(node, new Selector.call(Names.call, callStructure));
    applyVisitState();
  }

  void visitThisPropertyInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      _) {
    loadThis();

    // If the property is statically known to be a field, instead invoke the
    // getter and then invoke 'call(...)' on the value.
    // TODO(ajohnsen): This is a fix that only works when the field is
    // statically known - that is not always the case. Implement VM support?
    Element target = elements[node];
    if (target != null && target.isField) {
      invokeGetter(node, new Name(target.name, element.library));
      selector = new Selector.callClosureFrom(selector);
    }
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(node, selector);
    applyVisitState();
  }

  void visitThisInvoke(
      Send node,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    loadThis();
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(node, callStructure.callSelector);
    applyVisitState();
  }

  void visitClassTypeLiteralGet(
      Send node,
      ConstantExpression constant,
      _) {
    generateUnimplementedError(
        node, "[visitClassTypeLiteralGet] isn't implemented.");
    applyVisitState();
  }

  void visitDynamicPropertyGet(
      Send node,
      Node receiver,
      Name name,
      _) {
    if (name.text == "runtimeType") {
      // TODO(ahe): Implement runtimeType.
      generateUnimplementedError(
          node,
          "'runtimeType' isn't supported in Dartino. "
          "See https://goo.gl/ELH6Zc");
      applyVisitState();
      return;
    }
    visitForValue(receiver);
    invokeGetter(node, name);
    applyVisitState();
  }

  void visitIfNotNullDynamicPropertyGet(
      Send node,
      Node receiver,
      Name name,
      _) {
    doIfNotNull(receiver, () {
      invokeGetter(node, name);
    });
    applyVisitState();
  }

  void visitThisPropertyGet(
      Send node,
      Name name,
      _) {
    loadThis();
    invokeGetter(node, name);
    applyVisitState();
  }

  void visitThisPropertySet(
      Send node,
      Name name,
      Node rhs,
      _) {
    loadThis();
    visitForValue(rhs);
    invokeSetter(node, name);
    applyVisitState();
  }

  void doStaticFieldGet(FieldElement field) {
    if (checkCompileError(field)) return;
    if (field.isConst) {
      int constId = allocateConstantFromNode(
          field.initializer,
          elements: field.resolvedAst.elements);
      assembler.loadConst(constId);
    } else {
      int index = compileLazyFieldInitializer(field);
      if (field.initializer != null) {
        assembler.loadStaticInit(index);
      } else {
        assembler.loadStatic(index);
      }
    }
  }

  void handleStaticFieldGet(
      Send node,
      FieldElement field,
      _) {
    doStaticFieldGet(field);
    applyVisitState();
  }

  void visitAssert(Assert node) {
    // TODO(ajohnsen): Emit assert in checked mode.
  }

  void visitDynamicPropertySet(
      Send node,
      Node receiver,
      Name name,
      Node rhs,
      _) {
    visitForValue(receiver);
    visitForValue(rhs);
    invokeSetter(node, name);
    applyVisitState();
  }

  void visitIfNotNullDynamicPropertySet(
      SendSet node,
      Node receiver,
      Name name,
      Node rhs,
      _) {
    doIfNotNull(receiver, () {
      visitForValue(rhs);
      invokeSetter(node, name);
    });
    applyVisitState();
  }

  void doStaticFieldSet(FieldElement field) {
    int index = systemBase.getStaticFieldIndex(field, element);
    assembler.storeStatic(index);
  }

  void handleStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    visitForValue(rhs);
    doStaticFieldSet(field);
    applyVisitState();
  }

  void visitStringJuxtaposition(StringJuxtaposition node) {
    // TODO(ajohnsen): This could probably be optimized to string constants in
    // some cases.
    visitForValue(node.first);
    visitForValue(node.second);
    // TODO(ajohnsen): Cache these in context/backend.
    Selector concat = new Selector.binaryOperator('+');
    invokeMethod(node, concat);
    applyVisitState();
  }

  void visitStringInterpolation(StringInterpolation node) {
    // TODO(ajohnsen): Cache this in context/backend.
    Selector concat = new Selector.binaryOperator('+');
    visitForValueNoDebugInfo(node.string);
    for (StringInterpolationPart part in node.parts) {
      visitForValue(part.expression);
      invokeMethod(part.expression, Selectors.toString_);
      LiteralString string = part.string;
      if (string.dartString.isNotEmpty) {
        visitForValueNoDebugInfo(string);
        invokeMethod(null, concat);
      }
      invokeMethod(null, concat);
    }
    applyVisitState();
  }

  void visitLiteralNull(LiteralNull node) {
    if (visitState == VisitState.Value) {
      assembler.loadLiteralNull();
    } else if (visitState == VisitState.Test) {
      if (falseLabel != null) assembler.branch(falseLabel);
    }
  }

  void visitLiteralSymbol(LiteralSymbol node) {
    int constId = allocateConstantFromNode(node);
    assembler.loadConst(constId);
    applyVisitState();
  }

  void visitLiteralBool(LiteralBool node) {
    ConstantValue value = evaluateAndUseConstant(node, isConst: false);
    bool isTrue = value != null ? value.isTrue : false;
    if (visitState == VisitState.Value) {
      if (isTrue) {
        assembler.loadLiteralTrue();
      } else {
        assembler.loadLiteralFalse();
      }
    } else if (visitState == VisitState.Test) {
      if (isTrue) {
        if (trueLabel != null) assembler.branch(trueLabel);
      } else {
        if (falseLabel != null) assembler.branch(falseLabel);
      }
    }
  }

  void visitLiteralInt(LiteralInt node) {
    if (visitState == VisitState.Value) {
      int value = node.value;
      assert(value >= 0);
      if (value > LITERAL_INT_MAX) {
        if ((value < MIN_INT64 || value > MAX_INT64) && !context.enableBigint) {
          generateUnimplementedError(
              node,
              'Program compiled without support for big integers');
        } else {
          int constId = allocateConstantFromNode(node);
          assembler.loadConst(constId);
        }
      } else {
        assembler.loadLiteral(value);
      }
    } else if (visitState == VisitState.Test) {
      if (falseLabel != null) assembler.branch(falseLabel);
    }
  }

  void visitLiteral(Literal node) {
    if (visitState == VisitState.Value) {
      assembler.loadConst(allocateConstantFromNode(node));
    } else if (visitState == VisitState.Test) {
      if (falseLabel != null) assembler.branch(falseLabel);
    }
  }

  void visitLiteralList(LiteralList node) {
    if (node.isConst) {
      int constId = allocateConstantFromNode(node);
      assembler.loadConst(constId);
      applyVisitState();
      return;
    }
    ClassElement literalClass = context.backend.growableListClass;
    ConstructorElement constructor = literalClass.lookupDefaultConstructor();
    if (constructor == null) {
      internalError(node, "Failed to lookup default list constructor");
    }
    // Call with empty arguments, as we call the default constructor.
    callConstructor(
        node, constructor, new NodeList.empty(), CallStructure.NO_ARGS);
    Selector add = new Selector.call(new Name('add', null),
        CallStructure.ONE_ARG);
    for (Node element in node.elements) {
      assembler.dup();
      visitForValue(element);
      invokeMethod(node, add);
      assembler.pop();
    }
    applyVisitState();
  }

  void visitLiteralMap(LiteralMap node) {
    if (node.isConst) {
      int constId = allocateConstantFromNode(node);
      assembler.loadConst(constId);
      applyVisitState();
      return;
    }
    ClassElement literalClass =
        context.backend.mapImplementation.implementation;
    ConstructorElement constructor = literalClass.lookupConstructor("");
    if (constructor == null) {
      internalError(literalClass, "Failed to lookup default map constructor");
      return;
    }
    // The default constructor is a redirecting factory constructor. Follow it.
    constructor = constructor.effectiveTarget;
    DartinoFunctionBase function = requireFunction(constructor.declaration);
    doStaticFunctionInvoke(
        node,
        function,
        new NodeList.empty(),
        CallStructure.NO_ARGS,
        factoryInvoke: true);

    Selector selector = new Selector.indexSet();
    for (Node element in node.entries) {
      assembler.dup();
      visitForValue(element);
      invokeMethod(node, selector);
      assembler.pop();
    }
    applyVisitState();
  }

  void visitLiteralMapEntry(LiteralMapEntry node) {
    assert(visitState == VisitState.Value);
    visitForValue(node.key);
    visitForValue(node.value);
  }

  void visitLiteralString(LiteralString node) {
    if (visitState == VisitState.Value) {
      assembler.loadConst(allocateConstantFromNode(node));
      registerInstantiatedClass(
          context.compiler.backend.stringImplementation);
    } else if (visitState == VisitState.Test) {
      if (falseLabel != null) assembler.branch(falseLabel);
    }
  }

  void visitCascadeReceiver(CascadeReceiver node) {
    visitForValue(node.expression);
    assembler.dup();
    assert(visitState == VisitState.Value);
  }

  void visitCascade(Cascade node) {
    visitForEffect(node.expression);
    applyVisitState();
  }

  void visitParenthesizedExpression(ParenthesizedExpression node) {
    // Visit expression in the same VisitState.
    node.expression.accept(this);
  }

  void doLocalFunctionGet(Send node, LocalFunctionElement function) {
    registerClosurization(function, ClosureKind.localFunction);
    doLocalGet(function);
  }

  void visitLocalFunctionGet(Send node, LocalFunctionElement function, _) {
    doLocalFunctionGet(node, function);
    applyVisitState();
  }

  void doLocalGet(LocalElement element) {
    scope[element].load(assembler);
  }

  void handleLocalGet(
      Send node,
      LocalElement element,
      _) {
    doLocalGet(element);
    applyVisitState();
  }

  void handleLocalSet(
      SendSet node,
      LocalElement element,
      Node rhs,
      _) {
    visitForValue(rhs);
    scope[element].store(assembler);
    applyVisitState();
  }

  void visitLocalFunctionInvoke(
      Send node,
      LocalFunctionElement function,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    // TODO(ahe): We could use loadPositionalArguments if [element] is a local
    // function to avoid generating additional stubs and to avoid registering
    // this as a dynamic call.
    registerLocalInvoke(function, callStructure.callSelector);
    handleLocalInvoke(node, function, arguments, callStructure, _);
  }

  void handleLocalInvoke(
      Node node,
      LocalElement element,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    scope[element].load(assembler);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(node, callStructure.callSelector);
    applyVisitState();
  }

  static Selector getIncDecSelector(IncDecOperator operator) {
    String name = operator == IncDecOperator.INC ? '+' : '-';
    return new Selector.binaryOperator(name);
  }

  static Selector getAssignmentSelector(AssignmentOperator operator) {
    String name = operator.binaryOperator.name;
    return new Selector.binaryOperator(name);
  }

  void doLocalVariableIncrement(
      Node node,
      LocalVariableElement element,
      IncDecOperator operator,
      bool prefix) {
    // TODO(ajohnsen): Candidate for bytecode: Inc/Dec local with non-Smi
    // bailout.
    LocalValue value = scope[element];
    value.load(assembler);
    // For postfix, keep local, unmodified version, to 'return' after store.
    if (!prefix) assembler.dup();
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    value.store(assembler);
    if (!prefix) assembler.pop();
  }

  void visitLocalVariablePrefix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    doLocalVariableIncrement(node, element, operator, true);
    applyVisitState();
  }

  void visitParameterPrefix(
      Send node,
      LocalParameterElement parameter,
      IncDecOperator operator,
      _) {
    doLocalVariableIncrement(node, parameter, operator, true);
    applyVisitState();
  }

  void visitLocalVariablePostfix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    // If visitState is for effect, we can ignore the return value, thus always
    // generate code for the simpler 'prefix' case.
    bool prefix = (visitState == VisitState.Effect);
    doLocalVariableIncrement(node, element, operator, prefix);
    applyVisitState();
  }

  void visitParameterPostfix(
      SendSet node,
      LocalParameterElement parameter,
      IncDecOperator operator,
      _) {
    // If visitState is for effect, we can ignore the return value, thus always
    // generate code for the simpler 'prefix' case.
    bool prefix = (visitState == VisitState.Effect);
    doLocalVariableIncrement(node, parameter, operator, prefix);
    applyVisitState();
  }

  void doStaticFieldPrefix(
        Node node,
        FieldElement field,
        IncDecOperator operator) {
    doStaticFieldGet(field);
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    doStaticFieldSet(field);
  }

  void doStaticFieldPostfix(
        Node node,
        FieldElement field,
        IncDecOperator operator) {
    doStaticFieldGet(field);
    // For postfix, keep local, unmodified version, to 'return' after store.
    assembler.dup();
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    doStaticFieldSet(field);
    assembler.pop();
  }

  void visitStaticFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    if (visitState == VisitState.Effect) {
      doStaticFieldPrefix(node, field, operator);
    } else {
      doStaticFieldPostfix(node, field, operator);
    }
    applyVisitState();
  }

  void visitStaticFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    doStaticFieldPrefix(node, field, operator);
    applyVisitState();
  }

  void visitTopLevelFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    if (visitState == VisitState.Effect) {
      doStaticFieldPrefix(node, field, operator);
    } else {
      doStaticFieldPostfix(node, field, operator);
    }
    applyVisitState();
  }

  void visitTopLevelFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    doStaticFieldPrefix(node, field, operator);
    applyVisitState();
  }

  void doDynamicPropertyCompound(
      Node node,
      Name name,
      AssignmentOperator operator,
      Node rhs) {
    // Dup receiver for setter.
    assembler.dup();
    invokeGetter(node, name);
    visitForValue(rhs);
    invokeMethod(node, getAssignmentSelector(operator));
    invokeSetter(node, name);
  }

  void visitDynamicPropertyCompound(
      Send node,
      Node receiver,
      Name name,
      AssignmentOperator operator,
      Node rhs,
      _) {
    visitForValue(receiver);
    doDynamicPropertyCompound(
        node,
        name,
        operator,
        rhs);
    applyVisitState();
  }

  void visitIfNotNullDynamicPropertyCompound(
      Send node,
      Node receiver,
      Name name,
      AssignmentOperator operator,
      Node rhs,
      _) {
    doIfNotNull(receiver, () {
      doDynamicPropertyCompound(
          node,
          name,
          operator,
          rhs);
    });
    applyVisitState();
  }

  void visitThisPropertyCompound(
      Send node,
      Name name,
      AssignmentOperator operator,
      Node rhs,
      _) {
    loadThis();
    doDynamicPropertyCompound(
        node,
        name,
        operator,
        rhs);
    applyVisitState();
  }

  void doDynamicPrefix(
      Node node,
      Name name,
      IncDecOperator operator) {
    assembler.dup();
    invokeGetter(node, name);
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    invokeSetter(node, name);
  }

  void doIndexPrefix(
      SendSet node,
      Node receiver,
      Node index,
      IncDecOperator operator) {
    visitForValue(receiver);
    visitForValue(index);
    // Load already evaluated receiver and index for '[]' call.
    assembler.loadLocal(1);
    assembler.loadLocal(1);
    invokeMethod(node, new Selector.index());
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    // Use existing evaluated receiver and index for '[]=' call.
    invokeMethod(node, new Selector.indexSet());
  }

  void visitIndexPrefix(
      SendSet node,
      Node receiver,
      Node index,
      IncDecOperator operator,
      _) {
    doIndexPrefix(node, receiver, index, operator);
    applyVisitState();
  }

  void visitIndexPostfix(
      Send node,
      Node receiver,
      Node index,
      IncDecOperator operator,
      _) {
    if (visitState == VisitState.Effect) {
      doIndexPrefix(node, receiver, index, operator);
      applyVisitState();
      return;
    }

    // Reserve slot for result.
    assembler.loadLiteralNull();
    visitForValue(receiver);
    visitForValue(index);
    // Load already evaluated receiver and index for '[]' call.
    assembler.loadLocal(1);
    assembler.loadLocal(1);
    invokeMethod(node, new Selector.index());
    assembler.storeLocal(3);
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    // Use existing evaluated receiver and index for '[]=' call.
    invokeMethod(node, new Selector.indexSet());
    assembler.pop();
    applyVisitState();
  }

  void visitCompoundIndexSet(
      Send node,
      Node receiver,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    if (operator.kind == AssignmentOperatorKind.IF_NULL) {
      // TODO(sigurdm): This case should not go here.
      // This redirection should be removed in a future roll of the dart2js
      // frontend.
      visitIndexSetIfNotNull(node, receiver, index, rhs,_);
      return;
    }
    visitForValue(receiver);
    visitForValue(index);
    // Load already evaluated receiver and index for '[]' call.
    assembler.loadLocal(1);
    assembler.loadLocal(1);
    invokeMethod(node, new Selector.index());
    visitForValue(rhs);
    invokeMethod(node, getAssignmentSelector(operator));
    // Use existing evaluated receiver and index for '[]=' call.
    invokeMethod(node, new Selector.indexSet());
    applyVisitState();
  }

  void visitThisPropertyPrefix(
      Send node,
      Name name,
      IncDecOperator operator,
      _) {
    loadThis();
    doDynamicPrefix(node, name, operator);
    applyVisitState();
  }

  void visitThisPropertyPostfix(
      Send node,
      Name name,
      IncDecOperator operator,
      _) {
    // If visitState is for effect, we can ignore the return value, thus always
    // generate code for the simpler 'prefix' case.
    if (visitState == VisitState.Effect) {
      loadThis();
      doDynamicPrefix(node, name, operator);
      applyVisitState();
      return;
    }

    loadThis();
    invokeGetter(node, name);
    // For postfix, keep local, unmodified version, to 'return' after store.
    assembler.dup();
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    loadThis();
    assembler.loadLocal(1);
    invokeSetter(node, name);
    assembler.popMany(2);
    applyVisitState();
  }

  void visitDynamicPropertyPrefix(
      Send node,
      Node receiver,
      Name name,
      IncDecOperator operator,
      _) {
    visitForValue(receiver);
    doDynamicPrefix(node, name, operator);
    applyVisitState();
  }

  void visitIfNotNullDynamicPropertyPrefix(
      Send node,
      Node receiver,
      Name name,
      IncDecOperator operator,
      _) {
    doIfNotNull(receiver, () {
      doDynamicPrefix(node, name, operator);
    });
    applyVisitState();
  }

  void doDynamicPostfix(
      Send node,
      Node receiver,
      Name name,
      IncDecOperator operator) {
    int receiverSlot = assembler.stackSize - 1;
    assembler.loadSlot(receiverSlot);
    invokeGetter(node, name);
    // For postfix, keep local, unmodified version, to 'return' after store.
    assembler.dup();
    assembler.loadLiteral(1);
    invokeMethod(node, getIncDecSelector(operator));
    assembler.loadSlot(receiverSlot);
    assembler.loadLocal(1);
    invokeSetter(node, name);
    assembler.popMany(2);
    assembler.storeLocal(1);
    // Pop receiver.
    assembler.pop();
  }

  void visitDynamicPropertyPostfix(
      Send node,
      Node receiver,
      Name name,
      IncDecOperator operator,
      _) {
    // If visitState is for effect, we can ignore the return value, thus always
    // generate code for the simpler 'prefix' case.
    if (visitState == VisitState.Effect) {
      visitForValue(receiver);
      doDynamicPrefix(node, name, operator);
      applyVisitState();
      return;
    }

    visitForValue(receiver);
    doDynamicPostfix(node, receiver, name, operator);
    applyVisitState();
  }

  void visitIfNotNullDynamicPropertyPostfix(
      Send node,
      Node receiver,
      Name name,
      IncDecOperator operator,
      _) {
    doIfNotNull(receiver, () {
      doDynamicPostfix(
          node, receiver, name, operator);
    });
    applyVisitState();
  }

  void visitThrow(Throw node) {
    visitForValue(node.expression);
    generateThrow(node);
    // TODO(ahe): It seems suboptimal that each throw is followed by a pop.
    applyVisitState();
  }

  void visitRethrow(Rethrow node) {
    if (tryBlockStack.isEmpty) {
      doCompileError(context.compiler.reporter.createMessage(
          node, MessageKind.GENERIC, {"text": "Rethrow outside try"}));
    } else {
      TryBlock block = tryBlockStack.head;
      assembler.loadSlot(block.stackSize - 1);
      // TODO(ahe): It seems suboptimal that each throw is followed by a pop.
      generateThrow(node);
    }
    assembler.pop();
  }

  void callConstructor(Node node,
                       ConstructorElement constructor,
                       NodeList arguments,
                       CallStructure callStructure) {
    DartinoFunctionBase function = requireConstructorInitializer(constructor);
    doStaticFunctionInvoke(node, function, arguments, callStructure);
  }

  void doConstConstructorInvoke(ConstantExpression constant) {
    var value = context.getConstantValue(constant);
    markConstantUsed(value);
    int constId = functionBuilder.allocateConstant(value);
    assembler.loadConst(constId);
  }

  void visitConstConstructorInvoke(
      NewExpression node,
      ConstructedConstantExpression constant,
      _) {
    // TODO(johnniwinther): We should not end up here with an bad constructor.
    if (!checkCompileError(elements[node.send])) {
      doConstConstructorInvoke(constant);
    }
    applyVisitState();
  }

  void visitBoolFromEnvironmentConstructorInvoke(
      NewExpression node,
      BoolFromEnvironmentConstantExpression constant,
      _) {
    doConstConstructorInvoke(constant);
    applyVisitState();
  }

  void visitIntFromEnvironmentConstructorInvoke(
      NewExpression node,
      IntFromEnvironmentConstantExpression constant,
      _) {
    doConstConstructorInvoke(constant);
    applyVisitState();
  }

  void visitStringFromEnvironmentConstructorInvoke(
      NewExpression node,
      StringFromEnvironmentConstantExpression constant,
      _) {
    doConstConstructorInvoke(constant);
    applyVisitState();
  }

  void visitGenerativeConstructorInvoke(
      NewExpression node,
      ConstructorElement constructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    if (!checkCompileError(constructor)) {
      callConstructor(node, constructor.declaration, arguments, callStructure);
    }
    applyVisitState();
  }

  void visitFactoryConstructorInvoke(
      NewExpression node,
      ConstructorElement constructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    // If the constructor has an implementation, the implementation is the
    // factory we want to invoke. Redirect to
    // visitRedirectingFactoryConstructorInvoke, so we handle both cases of
    // either a factory or a redirecting factory.
    if (constructor.implementation != constructor) {
      ConstructorElement implementation = constructor.implementation;
      visitRedirectingFactoryConstructorInvoke(
          node,
          constructor,
          type,
          implementation.effectiveTarget,
          null,
          arguments,
          callStructure,
          null);
      return;
    }
    // TODO(ahe): Remove ".declaration" when issue 23135 is fixed.
    DartinoFunctionBase function = requireFunction(constructor.declaration);
    doStaticFunctionInvoke(
        node, function, arguments, callStructure, factoryInvoke: true);
    applyVisitState();
  }

  void visitConstructorIncompatibleInvoke(
      NewExpression node,
      ConstructorElement constructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    if (!checkCompileError(constructor)) {
      doUnresolved(constructor.name);
    }
    applyVisitState();
  }

  void visitRedirectingGenerativeConstructorInvoke(
      NewExpression node,
      ConstructorElement constructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    visitGenerativeConstructorInvoke(
        node,
        constructor,
        type,
        arguments,
        callStructure,
        null);
 }

  void visitRedirectingFactoryConstructorInvoke(
      NewExpression node,
      ConstructorElement constructor,
      InterfaceType type,
      ConstructorElement effectiveTarget,
      InterfaceType effectiveTargetType,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    if (effectiveTarget.isGenerativeConstructor) {
      visitGenerativeConstructorInvoke(
          node,
          effectiveTarget,
          effectiveTargetType,
          arguments,
          callStructure,
          null);
    } else {
      visitFactoryConstructorInvoke(
          node,
          effectiveTarget,
          effectiveTargetType,
          arguments,
          callStructure,
          null);
    }
  }

  void visitUnresolvedConstructorInvoke(
      NewExpression node,
      Element constructor,
      DartType type,
      NodeList arguments,
      Selector selector,
      _) {
    if (!checkCompileError(constructor.enclosingClass)) {
      doUnresolved(node.send.toString());
    }
    applyVisitState();
  }

  void visitUnresolvedClassConstructorInvoke(
      NewExpression node,
      Element element,
      DartType type,
      NodeList arguments,
      Selector selector,
      _) {
    doUnresolved(node.send.toString());
    applyVisitState();
  }

  void visitAbstractClassConstructorInvoke(
      NewExpression node,
      ConstructorElement element,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    generateUnimplementedError(node, "Cannot allocate abstract class");
    applyVisitState();
  }

  void visitUnresolvedRedirectingFactoryConstructorInvoke(
      NewExpression node,
      ConstructorElement constructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    doUnresolved(node.send.toString());
    applyVisitState();
  }

  void doStaticGetterGet(Send node, FunctionElement getter) {
    if (getter == context.backend.dartinoExternalNativeError) {
      assembler.loadSlot(0);
      return;
    }

    if (getter.isDeferredLoaderGetter) {
      generateUnimplementedError(node, "Deferred loading is not supported.");
      return;
    }

    DartinoFunctionBase base = requireFunction(getter);
    int constId = functionBuilder.allocateConstantFromFunction(base.functionId);
    invokeStatic(node, constId, 0);
  }

  void handleStaticGetterGet(Send node, FunctionElement getter, _) {
    doStaticGetterGet(node, getter);
    applyVisitState();
  }

  void handleStaticGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    doStaticGetterGet(node, getter);
    for (Node argument in arguments) {
      visitForValue(argument);
    }
    invokeMethod(node, callStructure.callSelector);
    applyVisitState();
  }

  void doStaticSetterSet(Send node, FunctionElement setter, Node rhs) {
    visitForValue(rhs);
    DartinoFunctionBase base = requireFunction(setter);
    int constId = functionBuilder.allocateConstantFromFunction(base.functionId);
    invokeStatic(node, constId, 1);
  }

  void handleStaticSetterSet(
      Send node,
      FunctionElement setter,
      Node rhs,
      _) {
    doStaticSetterSet(node, setter, rhs);
    applyVisitState();
  }

  /**
   * Load the captured variables of [function], expressed in [info].
   *
   * If [function] captures itself, its field index is returned.
   */
  int pushCapturedVariables(FunctionElement function) {
    ClosureInfo info = closureEnvironment.closures[function];
    if (info == null) {
      // TODO(ahe): Do not throw here, instead fix bug in incremental compiler
      // (see test closure_capture).
      throw new IncrementalCompilationFailed(
          "Internal error: no closure info for $function");
    }
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
        assembler.loadLiteralNull();
        assert(thisClosureIndex == -1);
        thisClosureIndex = index;
      } else {
        // Load the raw value (the 'Box' when by reference).
        scope[element].loadRaw(assembler);
      }
      index++;
    }
    return thisClosureIndex;
  }

  void handleLocalFunction(FunctionElement function) {
    // If the closure captures itself, thisClosureIndex is the field-index in
    // the closure.
    int thisClosureIndex = pushCapturedVariables(function);
    bool needToStoreThisReference = thisClosureIndex >= 0;

    ClosureInfo info = closureEnvironment.closures[function];
    DartinoClassBase classBase = getLocalFunctionClosureClass(function, info);
    int classConstant =
        functionBuilder.allocateConstantFromClass(classBase.classId);

    // NOTE: Currently we emit a storeField instruction in case a closure
    // captures itself. Changing fields makes it a mutable object.
    // We can therefore not allocate the object with `immutable = true`.
    // TODO(dartino_compiler-team): Could we restrict this limitation.
    bool immutable = !closureEnvironment.closures[function].free.any(
        closureEnvironment.shouldBeBoxed) && !needToStoreThisReference;

    assembler.allocate(
        classConstant, classBase.fieldCount, immutable: immutable);

    if (needToStoreThisReference) {
      assert(!immutable);
      assembler.dup();
      assembler.storeField(thisClosureIndex);
    }
  }

  void visitFunctionExpression(FunctionExpression node) {
    FunctionElement function = elements[node];
    handleLocalFunction(function);
    applyVisitState();
    registerClosurization(function, ClosureKind.localFunction);
  }

  void visitExpression(Expression node) {
    generateUnimplementedError(
        node, "Missing visit of expression: ${node.runtimeType}");
    applyVisitState();
  }

  void visitStatement(Node node) {
    generateUnimplementedError(
        node, "Missing visit of statement: ${node.runtimeType}");
    assembler.pop();
  }

  void doStatements(NodeList statements) {
    List<Element> oldBlockLocals = blockLocals;
    blockLocals = <Element>[];
    int stackSize = assembler.stackSize;

    for (Node statement in statements) {
      statement.accept(this);
    }

    int stackSizeDifference = assembler.stackSize - stackSize;
    if (stackSizeDifference != blockLocals.length) {
      internalError(
          statements,
          "Unbalanced number of block locals and stack slots used by block.");
    }

    if (blockLocals.length > 0) assembler.popMany(blockLocals.length);

    for (int i = blockLocals.length - 1; i >= 0; --i) {
      popVariableDeclaration(blockLocals[i]);
    }

    blockLocals = oldBlockLocals;
  }

  void visitBlock(Block node) {
    var breakLabel = new BytecodeLabel();
    jumpInfo[node] = new JumpInfo(assembler.stackSize, null, breakLabel);
    doStatements(node.statements);
    assembler.bind(breakLabel);
  }

  void visitEmptyStatement(EmptyStatement node) {
  }

  void visitExpressionStatement(ExpressionStatement node) {
    visitForEffect(node.expression);
  }

  // Called before 'return', as an option to replace the already evaluated
  // return value. One example is setters.
  bool get hasAssignmentSemantics => false;
  void optionalReplaceResultValue() { }

  void visitReturn(Return node) {
    Expression expression = node.expression;
    bool returnNull = true;
    if (expression != null && !isConstNull(expression)) {
      visitForValue(expression);
      returnNull = false;
    }

    // Avoid using the return-null bytecode if we have assignment semantics.
    if (returnNull && hasAssignmentSemantics) {
      assembler.loadLiteralNull();
      returnNull = false;
    }

    if (returnNull) {
      callFinallyBlocks(0, false);
      generateReturnNull(node);
    } else {
      callFinallyBlocks(0, true);
      optionalReplaceResultValue();
      generateReturn(node);
    }
  }

  // Find the JumpInfo matching the target of [node].
  JumpInfo getJumpTargetInfo(GotoStatement node) {
    JumpTarget target = elements.getTargetOf(node);
    if (target == null) {
      generateUnimplementedError(node, "'$node' not in loop");
      assembler.pop();
      return null;
    }
    Node statement = target.statement;
    JumpInfo info = jumpInfo[statement];
    if (info == null) {
      generateUnimplementedError(node, "'$node' has no target");
      assembler.pop();
    }
    return info;
  }

  void callFinallyBlocks(int targetStackSize, bool preserveTop) {
    int popCount = 0;
    for (var block in tryBlockStack) {
      // Break once all exited finally blocks are processed. Finally blocks
      // are ordered by stack size which coincides with scoping. Blocks with
      // stack sizes at least equal to target size are being exited.
      if (block.stackSize < targetStackSize) break;
      if (block.finallyLabel == null) continue;
      if (preserveTop) {
        // We reuse the exception slot as a temporary buffer for the top
        // element, which is located -1 relative to the block's stack size.
        assembler.storeSlot(block.stackSize - 1);
      }
      // TODO(ajohnsen): Don't pop, but let subroutineCall take a 'pop count'
      // argument, just like popAndBranch.
      if (assembler.stackSize > block.stackSize) {
        int sizeDifference = assembler.stackSize - block.stackSize;
        popCount += sizeDifference;
        assembler.popMany(sizeDifference);
      }
      assembler.subroutineCall(block.finallyLabel, block.finallyReturnLabel);
      if (preserveTop) {
        assembler.loadSlot(block.stackSize - 1);
        popCount--;
      }
    }
    // Reallign stack (should be removed, according to above TODO).
    for (int i = 0; i < popCount; i++) {
      // Note we dup, to make sure the top element is the return value.
      assembler.dup();
    }
  }

  void unbalancedBranch(GotoStatement node, bool isBreak) {
    JumpInfo info = getJumpTargetInfo(node);
    if (info == null) return;
    callFinallyBlocks(info.stackSize, false);
    BytecodeLabel label = isBreak ? info.breakLabel : info.continueLabel;
    int diff = assembler.stackSize - info.stackSize;
    assembler.popAndBranch(diff, label);
  }

  void visitBreakStatement(BreakStatement node) {
    var breakLabel = new BytecodeLabel();
    jumpInfo[node] = new JumpInfo(assembler.stackSize, null, breakLabel);
    unbalancedBranch(node, true);
    assembler.bind(breakLabel);
  }

  void visitContinueStatement(ContinueStatement node) {
    unbalancedBranch(node, false);
  }

  void visitIf(If node) {
    ConstantValue conditionValue =
        inspectConstant(node.condition, isConst: false);

    if (conditionValue != null) {
      BytecodeLabel end = new BytecodeLabel();
      jumpInfo[node] = new JumpInfo(assembler.stackSize, null, end);
      if (conditionValue.isTrue) {
        doScopedStatement(node.thenPart);
      } else if (node.hasElsePart) {
        doScopedStatement(node.elsePart);
      }
      assembler.bind(end);
      return;
    }

    BytecodeLabel ifFalse = new BytecodeLabel();

    visitForTest(node.condition, null, ifFalse);
    if (node.hasElsePart) {
      BytecodeLabel end = new BytecodeLabel();
      jumpInfo[node] = new JumpInfo(assembler.stackSize, null, end);
      doScopedStatement(node.thenPart);
      assembler.branch(end);
      assembler.bind(ifFalse);
      doScopedStatement(node.elsePart);
      assembler.bind(end);
    } else {
      jumpInfo[node] = new JumpInfo(assembler.stackSize, null, ifFalse);
      doScopedStatement(node.thenPart);
      assembler.bind(ifFalse);
    }
  }

  void visitFor(For node) {
    List<Element> oldBlockLocals = blockLocals;
    blockLocals = <Element>[];

    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    BytecodeLabel afterBody  = new BytecodeLabel();

    Node initializer = node.initializer;
    if (initializer != null) visitForEffect(initializer);

    jumpInfo[node] = new JumpInfo(assembler.stackSize, afterBody, end);

    assembler.bind(start);

    Expression condition = node.condition;
    if (condition != null) {
      visitForTest(condition, null, end);
    }

    doScopedStatement(node.body);

    assembler.bind(afterBody);

    for (int i = blockLocals.length - 1; i >= 0; --i) {
      LocalElement local = blockLocals[i];
      // If the locals are captured by reference, load the current value and
      // store it in a new boxed.
      if (closureEnvironment.shouldBeBoxed(local)) {
        LocalValue value = scope[local];
        value.load(assembler);
        value.initialize(assembler);
        assembler.storeSlot(value.slot);
        assembler.pop();
      }
    }

    for (Node update in node.update) {
      visitForEffect(update);
    }
    assembler.branch(start);

    assembler.bind(end);

    for (int i = blockLocals.length - 1; i >= 0; --i) {
      assembler.pop();
      popVariableDeclaration(blockLocals[i]);
    }

    blockLocals = oldBlockLocals;
  }

  void visitSyncForIn(SyncForIn node) {
    visitForIn(node);
  }

  void visitForIn(ForIn node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();

    // Evalutate expression and iterator.
    visitForValue(node.expression);
    invokeGetter(node.expression, Names.iterator);

    jumpInfo[node] = new JumpInfo(assembler.stackSize, start, end);

    assembler.bind(start);

    assembler.dup();
    invokeMethod(node, Selectors.moveNext);
    assembler.branchIfFalse(end);

    bool isVariableDeclaration = node.declaredIdentifier.asSend() == null;
    Element element = elements[node];
    if (isVariableDeclaration) {
      // Create local value and load the current element to it.
      LocalValue value = createLocalValueFor(element);
      assembler.dup();
      invokeGetter(node, Names.current);
      value.initialize(assembler);
      pushVariableDeclaration(value);
    } else {
      if (element == null || element.isInstanceMember) {
        loadThis();
        assembler.loadLocal(1);
        invokeGetter(node, Names.current);
        Selector selector = elements.getSelector(node.declaredIdentifier);
        invokeSetter(node, selector.memberName);
      } else {
        assembler.dup();
        invokeGetter(node, Names.current);
        if (element.isLocal) {
          scope[element].store(assembler);
        } else if (element.isField) {
          doStaticFieldSet(element);
        } else if (element.isMalformed) {
          doUnresolved(element.name);
          assembler.pop();
        } else {
          internalError(node, "Unhandled store in for-in");
        }
      }
      assembler.pop();
    }

    doScopedStatement(node.body);

    if (isVariableDeclaration) {
      // Pop the local again.
      assembler.pop();
      popVariableDeclaration(element);
    }

    assembler.branch(start);

    assembler.bind(end);

    // Pop iterator.
    assembler.pop();
  }

  void visitLabeledStatement(LabeledStatement node) {
    node.statement.accept(this);
  }

  // Visit the statement in a scope, where locals are popped when left.
  void doScopedStatement(Node statement) {
    Block block = statement.asBlock();
    if (block != null) {
      doStatements(block.statements);
    } else {
      doStatements(new NodeList.singleton(statement));
    }
  }

  void visitWhile(While node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    jumpInfo[node] = new JumpInfo(assembler.stackSize, start, end);
    assembler.bind(start);
    visitForTest(node.condition, null, end);
    doScopedStatement(node.body);
    assembler.branch(start);
    assembler.bind(end);
  }

  void visitDoWhile(DoWhile node) {
    BytecodeLabel start = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    BytecodeLabel skipBody = new BytecodeLabel();
    jumpInfo[node] = new JumpInfo(assembler.stackSize, skipBody, end);
    assembler.bind(start);
    doScopedStatement(node.body);
    assembler.bind(skipBody);
    visitForTest(node.condition, start, null);
    assembler.bind(end);
  }

  LocalValue allocateLocal(LocalElement element, int slot) {
    LocalValue value = createLocalValueFor(element, slot: slot);
    value.initialize(assembler);
    pushVariableDeclaration(value);
    blockLocals.add(element);
    return value;
  }

  void generateEmptyInitializer(Node node) {
    assembler.loadLiteralNull();
  }

  void visitVariableDefinitions(VariableDefinitions node) {
    for (Node definition in node.definitions) {
      LocalVariableElement element = elements[definition];
      int slot = assembler.stackSize;
      if (element.initializer != null) {
        visitForValue(element.initializer);
      } else {
        generateEmptyInitializer(element.node);
      }
      allocateLocal(element, slot);
    }
  }

  void visitFunctionDeclaration(FunctionDeclaration node) {
    FunctionExpression functionNode = node.function;
    LocalFunctionElement function = elements[functionNode];
    int slot = assembler.stackSize;
    handleLocalFunction(function);
    allocateLocal(function, slot);
    // TODO(ahe): Remove the following line:
    registerClosurization(function, ClosureKind.localFunction);
  }

  void visitSwitchStatement(SwitchStatement node) {
    BytecodeLabel end = new BytecodeLabel();

    visitForValue(node.expression);

    jumpInfo[node] = new JumpInfo(assembler.stackSize, null, end);

    // Install cross-case jump targets.
    for (SwitchCase switchCase in node.cases) {
      BytecodeLabel continueLabel = new BytecodeLabel();
      jumpInfo[switchCase] = new JumpInfo(
          assembler.stackSize,
          continueLabel,
          null);
    }

    for (SwitchCase switchCase in node.cases) {
      BytecodeLabel ifTrue = jumpInfo[switchCase].continueLabel;
      BytecodeLabel next = new BytecodeLabel();
      if (!switchCase.isDefaultCase) {
        for (Node labelOrCaseMatch in switchCase.labelsAndCases) {
          CaseMatch caseMatch = labelOrCaseMatch.asCaseMatch();
          if (caseMatch == null) continue;
          generateSwitchCaseMatch(caseMatch, ifTrue);
        }
        assembler.branch(next);
      }
      assembler.bind(ifTrue);
      doStatements(switchCase.statements);
      assembler.branch(end);
      assembler.bind(next);
    }

    assembler.bind(end);
    assembler.pop();
  }

  void doCatchBlock(CatchBlock node, int exceptionSlot, BytecodeLabel end) {
    BytecodeLabel wrongType = new BytecodeLabel();

    TypeAnnotation type = node.type;
    if (type != null) {
      assembler.loadSlot(exceptionSlot);
      callIsSelector(type, elements.getType(type), type);
      assembler.branchIfFalse(wrongType);
    }

    List<Element> locals = <Element>[];
    Node exception = node.exception;
    if (exception != null) {
      LocalVariableElement element = elements[exception];
      LocalValue value = createLocalValueFor(element);
      assembler.loadSlot(exceptionSlot);
      value.initialize(assembler);
      pushVariableDeclaration(value);
      locals.add(element);

      Node trace = node.trace;
      if (trace != null) {
        LocalVariableElement element = elements[trace];
        LocalValue value = createLocalValueFor(element);
        assembler.loadLiteralNull();
        value.initialize(assembler);
        pushVariableDeclaration(value);
        // TODO(ajohnsen): Set trace.
        locals.add(element);
      }
    }

    node.block.accept(this);

    assembler.popMany(locals.length);
    for (Element e in locals) {
      popVariableDeclaration(e);
    }

    assembler.branch(end);

    assembler.bind(wrongType);
  }

  void visitTryStatement(TryStatement node) {
    BytecodeLabel end = new BytecodeLabel();
    BytecodeLabel finallyLabel = new BytecodeLabel();
    BytecodeLabel finallyReturnLabel = new BytecodeLabel();

    Block finallyBlock = node.finallyBlock;
    bool hasFinally = finallyBlock != null;

    // Reserve slot for exception.
    int exceptionSlot = assembler.stackSize;
    assembler.loadLiteralNull();

    jumpInfo[node] = new JumpInfo(assembler.stackSize, null, end);

    int startBytecodeSize = assembler.byteSize;

    tryBlockStack = tryBlockStack.prepend(
        new TryBlock(
            assembler.stackSize,
            hasFinally ? finallyLabel : null,
            hasFinally ? finallyReturnLabel: null));

    node.tryBlock.accept(this);

    // Go to end if no exceptions was thrown.
    assembler.branch(end);
    int endBytecodeSize = assembler.byteSize;

    // Add catch-frame to the assembler.
    assembler.addCatchFrameRange(startBytecodeSize, endBytecodeSize);

    for (Node catchBlock in node.catchBlocks) {
      doCatchBlock(catchBlock, exceptionSlot, end);
    }

    tryBlockStack = tryBlockStack.tail;

    if (hasFinally) {
      if (!node.catchBlocks.isEmpty) {
        assembler.addCatchFrameRange(endBytecodeSize, assembler.byteSize);
      }
      // Catch exception from catch blocks.
      assembler.subroutineCall(finallyLabel, finallyReturnLabel);
    }

    // The exception was not caught. Rethrow.
    generateThrow(node);

    assembler.bind(end);

    if (hasFinally) {
      BytecodeLabel done = new BytecodeLabel();
      assembler.subroutineCall(finallyLabel, finallyReturnLabel);
      assembler.branch(done);

      assembler.bind(finallyLabel);
      assembler.applyStackSizeFix(1);
      finallyBlock.accept(this);
      assembler.subroutineReturn(finallyReturnLabel);

      assembler.bind(done);
    }

    // Pop exception slot.
    assembler.pop();
  }

  void doUnresolved(String name) {
    var constString = context.backend.constantSystem.createString(
        new DartString.literal(name));
    markConstantUsed(constString);
    assembler.loadConst(functionBuilder.allocateConstant(constString));
    FunctionElement function = context.backend.dartinoUnresolved;
    DartinoFunctionBase base = requireFunction(function);
    int constId = functionBuilder.allocateConstantFromFunction(base.functionId);
    assembler.invokeStatic(constId, 1);
  }

  bool checkCompileError(Element element) {
    List<DiagnosticMessage> messages =
        context.compiler.elementsWithCompileTimeErrors[element];
    if (messages != null) {
      doCompileError(messages.first);
      return true;
    }
    return false;
  }

  String formatError(DiagnosticMessage diagnosticMessage) {
    return diagnosticMessage.message.computeMessage();
  }


  void doCompileError(DiagnosticMessage errorMessage) {
    FunctionElement function = context.backend.dartinoCompileError;
    DartinoFunctionBase base = requireFunction(function);
    int constId = functionBuilder.allocateConstantFromFunction(base.functionId);
    String errorString = formatError(errorMessage);
    ConstantValue stringConstant =
        context.backend.constantSystem.createString(
            new DartString.literal(errorString));
    int messageConstId = functionBuilder.allocateConstant(stringConstant);
    markConstantUsed(stringConstant);
    assembler.loadConst(messageConstId);
    registerInstantiatedClass(context.backend.stringImplementation);
    assembler.invokeStatic(constId, 1);
  }

  void visitUnresolvedInvoke(
      Send node,
      Element element,
      Node arguments,
      Selector selector,
      _) {
    if (!checkCompileError(element)) {
      doUnresolved(node.selector.toString());
    }
    applyVisitState();
  }

  void visitUnresolvedGet(
      Send node,
      Element element,
      _) {
    doUnresolved(node.selector.toString());
    applyVisitState();
  }

  void visitUnresolvedSet(
      Send node,
      Element element,
      Node rhs,
      _) {
    doUnresolved(node.selector.toString());
    applyVisitState();
  }

  void handleStaticFunctionIncompatibleInvoke(
      Send node,
      MethodElement function,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    if (!checkCompileError(function)) {
      doUnresolved(function.name);
    }
    applyVisitState();
  }

  void internalError(Spannable spannable, String reason) {
    context.compiler.reporter.internalError(spannable, reason);
  }

  void reportUnimplementedError(Spannable spannable, String reason);

  void generateUnimplementedError(Spannable spannable, String reason) {
    var constString = context.backend.constantSystem.createString(
        new DartString.literal(reason));
    markConstantUsed(constString);
    assembler.loadConst(functionBuilder.allocateConstant(constString));
    assembler.emitThrow();
  }

  String toString() => "FunctionCompiler(${element.name})";

  void handleFinalStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[handleFinalStaticFieldSet] isn't implemented.");
    applyVisitState();
  }

  void handleImmutableLocalSet(
      SendSet node,
      LocalElement element,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[handleImmutableLocalSet] isn't implemented.");
    applyVisitState();
  }

  void handleStaticSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    generateUnimplementedError(
        node, "[handleStaticSetterGet] isn't implemented.");
    applyVisitState();
  }

  void handleStaticSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    generateUnimplementedError(
        node, "[handleStaticSetterInvoke] isn't implemented.");
    applyVisitState();
  }

  void handleStaticGetterSet(
      Send node,
      FunctionElement getter,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[handleStaticGetterSet] isn't implemented.");
    applyVisitState();
  }

  void handleStaticFunctionSet(
      SendSet node,
      MethodElement function,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[handleStaticFunctionSet] isn't implemented.");
    applyVisitState();
  }

  /// Generates code that
  /// - runs the code generated by [getLhs]. Let the top of stack be t.
  /// - Compares t to null.
  ///   - If t is different from null, t is left on the stack.
  /// - If t is equal to null the code generated by [doSet] is run.
  ///
  /// [getLhs] can leave [valuesToPopIfNotNull] values on the stack for [doSet]
  /// to consume under t. These will be removed if the t is different to null.
  void doSetIfNull(void getLhs(), void doSet(), int valuesToPopIfNotNull) {
    BytecodeLabel notNull = new BytecodeLabel();
    BytecodeLabel end = new BytecodeLabel();
    getLhs();
    // We need a copy to return if it Lhs is not null.
    assembler.dup();
    assembler.loadLiteralNull();
    assembler.identicalNonNumeric();
    assembler.branchIfFalse(notNull);
    // Pop the extra null left by the dup.
    assembler.pop();
    doSet();
    if (valuesToPopIfNotNull != 0) {
      assembler.branch(end);
    }
    assembler.bind(notNull);
    if (valuesToPopIfNotNull != 0) {
      assembler.applyStackSizeFix(valuesToPopIfNotNull);
      assembler.storeLocal(valuesToPopIfNotNull);
      assembler.popMany(valuesToPopIfNotNull);
      assembler.bind(end);
    }
  }

  void visitClassTypeLiteralSetIfNull(
      Send node,
      ConstantExpression constant,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitClassTypeLiteralGetIfNull] isn't implemented.");
    applyVisitState();
  }

  void visitDynamicPropertySetIfNull(
      Send node,
      Node receiver,
      Name name,
      Node rhs,
      _) {
    doSetIfNull(() {
      visitForValue(receiver);
      assembler.dup();
      invokeGetter(node, name);
    }, () {
      visitForValue(rhs);
      invokeSetter(node, name);
    }, 1);
    applyVisitState();
  }

  void visitDynamicTypeLiteralSetIfNull(
      Send node,
      ConstantExpression constant,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitDynamicTypeLiteralSetIfNull] isn't implemented.");
    applyVisitState();
  }

  void doFinalLocalSetIfNull(Send node, LocalElement element, Node rhs) {
    doSetIfNull(() {
      scope[element].load(assembler);
    }, () {
      visitForValue(rhs);
      doUnresolved(element.name);
      assembler.pop();
    }, 0);
  }

  void visitFinalLocalVariableSetIfNull(
      Send node,
      LocalVariableElement variable,
      Node rhs,
      _) {
    doFinalLocalSetIfNull(node, variable, rhs);
    applyVisitState();
  }

  void visitFinalParameterSetIfNull(
      Send node,
      ParameterElement parameter,
      Node rhs,
      _) {
    doFinalLocalSetIfNull(node, parameter, rhs);
    applyVisitState();
  }

  void visitFinalStaticFieldSetIfNull(
      Send node,
      FieldElement field,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitFinalStaticFieldSetIfNull] isn't implemented.");
    applyVisitState();
  }

  void visitFinalSuperFieldSetIfNull(
      Send node,
      FieldElement field,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitFinalSuperFieldSetIfNull] isn't implemented.");
    applyVisitState();
  }

  void visitFinalTopLevelFieldSetIfNull(
      Send node,
      FieldElement field,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitFinalTopLevelFieldSetIfNull] isn't implemented.");
    applyVisitState();
  }

  void visitIfNotNullDynamicPropertySetIfNull(
      Send node,
      Node receiver,
      Name name,
      Node rhs,
      _) {
    doIfNotNull(receiver, () {
      doSetIfNull(() {
        assembler.dup();
        invokeGetter(node, name);
      }, () {
        visitForValue(rhs);
        invokeSetter(node, name);
      }, 1);
    });
    applyVisitState();
  }

  void visitLocalFunctionSetIfNull(
      Send node,
      LocalFunctionElement function,
      Node rhs,
      _) {
    doLocalFunctionGet(node, function);
    applyVisitState();
  }

  void visitLocalVariableSetIfNull(
      Send node,
      LocalVariableElement variable,
      Node rhs,
      _) {
    doSetIfNull(() {
      scope[variable].load(assembler);
    }, () {
      visitForValue(rhs);
      scope[variable].store(assembler);
    }, 0);
    applyVisitState();
  }

  void visitParameterSetIfNull(
      Send node,
      ParameterElement parameter,
      Node rhs,
      _) {
    doSetIfNull(() {
      scope[parameter].load(assembler);
    }, () {
      visitForValue(rhs);
      scope[parameter].store(assembler);
    }, 0);
    applyVisitState();
  }

  void visitStaticFieldSetIfNull(
      Send node,
      FieldElement field,
      Node rhs,
      _) {
    doSetIfNull(() {
      doStaticFieldGet(field);
    }, () {
      visitForValue(rhs);
      doStaticFieldSet(field);
    }, 0);
    applyVisitState();
  }

  void visitStaticGetterSetterSetIfNull(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node rhs,
      _) {
    doSetIfNull(() {
      doStaticGetterGet(node, getter);
    }, () {
      doStaticSetterSet(node, setter, rhs);
    }, 0);
    applyVisitState();
  }

  void visitStaticMethodSetIfNull(
      Send node,
      FunctionElement method,
      Node rhs,
      _) {
    doStaticFunctionGet(node, method);
    applyVisitState();
  }

  void visitStaticMethodSetterSetIfNull(
      Send node,
      MethodElement method,
      MethodElement setter,
      Node rhs,
      _) {
    doStaticFunctionGet(node, method);
    applyVisitState();
  }

  void visitSuperFieldFieldSetIfNull(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      Node rhs,
      _) {
    doSetIfNull(() {
      loadThis();
      assembler.dup();
      assembler.loadField(computeFieldIndex(readField));
    }, () {
      visitForValue(rhs);
      assembler.storeField(computeFieldIndex(writtenField));
    }, 1);
    applyVisitState();
  }

  void visitSuperFieldSetIfNull(
      Send node,
      FieldElement field,
      Node rhs,
      _) {
    int fieldIndex = computeFieldIndex(field);
    doSetIfNull(() {
      loadThis();
      assembler.dup();
      assembler.loadField(fieldIndex);
    }, () {
      visitForValue(rhs);
      assembler.storeField(fieldIndex);
    }, 1);
    applyVisitState();
  }

  void visitSuperFieldSetterSetIfNull(
      Send node,
      FieldElement field,
      FunctionElement setter,
      Node rhs,
      _) {
    doSetIfNull(() {
      loadThis();
      assembler.dup();
      assembler.loadField(computeFieldIndex(field));
    }, () {
      visitForValue(rhs);
      doSuperCall(node, setter);
    }, 1);
    applyVisitState();
  }

  void visitSuperGetterFieldSetIfNull(
      Send node,
      FunctionElement getter,
      FieldElement field,
      Node rhs,
      _) {
    doSetIfNull(() {
      loadThis();
      assembler.dup();
      doSuperCall(node, getter);
    }, () {
      visitForValue(rhs);
      assembler.storeField(computeFieldIndex(field));
    }, 1);
    applyVisitState();
  }

  void visitSuperGetterSetterSetIfNull(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node rhs,
      _) {
    doSetIfNull(() {
      loadThis();
      assembler.dup();
      doSuperCall(node, getter);
    }, () {
      visitForValue(rhs);
      doSuperCall(node, setter);
    }, 1);
    applyVisitState();
  }

  void visitSuperMethodSetIfNull(
      Send node,
      FunctionElement method,
      Node rhs,
      _) {
    doSuperMethodGet(node, method);
    applyVisitState();
  }

  void visitSuperMethodSetterSetIfNull(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      Node rhs,
      _) {
    doSuperMethodGet(node, method);
    applyVisitState();
  }

  void visitThisPropertySetIfNull(
      Send node,
      Name name,
      Node rhs,
      _) {
    doSetIfNull(() {
      loadThis();
      assembler.dup();
      invokeGetter(node, name);
    }, () {
      visitForValue(rhs);
      invokeSetter(node, name);
    }, 1);
    applyVisitState();
  }

  void visitTopLevelFieldSetIfNull(
      Send node,
      FieldElement field,
      Node rhs,
      _) {
    doSetIfNull(() {
      doStaticFieldGet(field);
    }, () {
      visitForValue(rhs);
      doStaticFieldSet(field);
    }, 0);
    applyVisitState();
  }

  void visitTopLevelGetterSetterSetIfNull(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node rhs,
      _) {
    doSetIfNull(() {
      doStaticGetterGet(node, getter);
    }, () {
      doStaticSetterSet(node, setter, rhs);
    }, 0);
    applyVisitState();
  }

  void visitTopLevelMethodSetIfNull(
      Send node,
      FunctionElement method,
      Node rhs,
      _) {
    doStaticFunctionGet(node, method);
    applyVisitState();
  }

  void visitTopLevelMethodSetterSetIfNull(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      Node rhs,
      _) {
    doStaticFunctionGet(node, method);
    applyVisitState();
  }

  void visitTypeVariableTypeLiteralSetIfNull(
      Send node,
      TypeVariableElement element,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitTypeVariableTypeLiteralSetIfNull] isn't implemented.");
    applyVisitState();
  }

  void visitTypedefTypeLiteralSetIfNull(
      Send node,
      ConstantExpression constant,
      Node rhs,
      _) {
    generateUnimplementedError(
        node, "[visitTypedefTypeLiteralSetIfNull] isn't implemented.");
    applyVisitState();
  }

  void visitUnresolvedSetIfNull(
      Send node,
      Element element,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedStaticGetterSetIfNull(
      Send node,
      Element element,
      MethodElement setter,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedStaticSetterSetIfNull(
      Send node,
      MethodElement getter,
      Element element,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedSuperGetterSetIfNull(
      Send node,
      Element element,
      MethodElement setter,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedSuperSetIfNull(
      Send node,
      Element element,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedSuperSetterSetIfNull(
      Send node,
      MethodElement getter,
      Element element,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedTopLevelGetterSetIfNull(
      Send node,
      Element element,
      MethodElement setter,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitUnresolvedTopLevelSetterSetIfNull(
      Send node,
      MethodElement getter,
      Element element,
      Node rhs,
      _) {
    visitForValue(node.receiver);
    applyVisitState();
  }

  void visitIndexSetIfNotNull(Send node,
      Node receiver,
      Node index,
      Node rhs,
      _) {
    doSetIfNull(() {
      visitForValue(receiver);
      visitForValue(index);
      assembler.loadLocal(1);
      assembler.loadLocal(1);
      invokeMethod(node, new Selector.index());
    }, () {
      visitForValue(rhs);
      invokeMethod(node, new Selector.indexSet());
    }, 2);
    applyVisitState();
  }


  void previsitDeferredAccess(Send node, PrefixElement prefix, _) {
    // We don't support deferred access, so nothing to do for now.
  }

  void bulkHandleNode(Node node, String msg, _) {
    generateUnimplementedError(node, msg.replaceAll('#', node.toString()));
    applyVisitState();
  }

  void visitNode(Node node) {
    internalError(node, "[visitNode] isn't implemented.");
  }

  void apply(Node node, _) {
    internalError(node, "[apply] isn't implemented.");
  }

  void applyInitializers(FunctionExpression initializers, _) {
    internalError(initializers, "[applyInitializers] isn't implemented.");
  }

  void applyParameters(NodeList parameters, _) {
    internalError(parameters, "[applyParameters] isn't implemented.");
  }
}

abstract class DartinoRegistryMixin {
  DartinoRegistry get registry;
  DartinoContext get context;

  DartinoSystemBuilder get systemBase => context.backend.systemBuilder;

  void registerDynamicSelector(Selector selector) {
    registry.registerDynamicSelector(selector);
  }

  void registerStaticInvocation(FunctionElement function) {
    registry.registerStaticInvocation(function);
  }

  void registerInstantiatedClass(ClassElement klass) {
    registry.registerInstantiatedClass(klass);
  }

  void registerIsCheck(DartType type) {
    registry.registerIsCheck(type);
  }

  void registerLocalInvoke(LocalElement element, Selector selector) {
    registry.registerLocalInvoke(element, selector);
  }

  void registerClosurization(FunctionElement element, ClosureKind kind) {
    if (kind == ClosureKind.localFunction) {
      // TODO(ahe): Get rid of the call to [registerStaticUse]. It is
      // currently needed to ensure that local function expression closures are
      // compiled correctly. For example, `[() {}].last()`, notice that `last`
      // is a getter. This happens for both named and unnamed.
      registerStaticInvocation(element);
    }
    registry.registerClosurization(element, kind);
  }

  int compileLazyFieldInitializer(FieldElement field) {
    return context.backend.compileLazyFieldInitializer(field, registry);
  }

  DartinoClassBase getLocalFunctionClosureClass(
      FunctionElement function,
      ClosureInfo info) {
    DartinoFunctionBuilder closureFunctionBuilder =
        systemBase.getClosureFunctionBuilder(
            function, context.compiler.coreClasses.functionClass, info,
            context.backend.compiledClosureClass);

    return systemBase.lookupClassById(closureFunctionBuilder.memberOf);
  }

  void reportUnimplementedError(
      Spannable spannable,
      String reason) {
    compiler.reporter.reportHintMessage(
        spannable, MessageKind.GENERIC, {'text': reason});
  }

  void markConstantUsed(ConstantValue constant) {
    for (ConstantValue value in constant.getDependencies()) {
      markConstantUsed(value);
    }
    if (!systemBase.registerConstant(constant)) return;
    if (constant.isConstructedObject) {
      // TODO(ahe): Is there a better way to register the constant's class.
      ConstructedConstantValue value = constant;
      ClassElement classElement = value.type.element;
      systemBase.getClassBuilder(classElement);
      registry.registerInstantiatedClass(classElement);
    } else if (constant.isFunction) {
      context.backend.markFunctionConstantAsUsed(constant);
    }
  }

  DartinoFunctionBase getParameterStub(
      DartinoFunctionBase function,
      Selector selector) {
    return context.backend.createParameterStub(function, selector, registry);
  }
}
