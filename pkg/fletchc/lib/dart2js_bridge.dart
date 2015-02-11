// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io' show
    File,
    Platform;

import 'package:compiler/compiler.dart' as api;

import 'package:sharedfrontend/elements.dart' as elements;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'package:compiler/src/dart2jslib.dart' as dart2js;

import 'package:compiler/src/source_file_provider.dart' show
    FormattingDiagnosticHandler;

import 'package:dart2js_incremental/compiler.dart' show
    OutputProvider;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

import 'package:semantic_visitor/semantic_visitor.dart' show
    SemanticVisitor;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

import 'bytecodes.dart';

main(List<String> arguments) {
  FormattingDiagnosticHandler handler = new FormattingDiagnosticHandler()
      ..throwOnError = false;

  OutputProvider outputProvider = new OutputProvider();

  Uri myLocation = Uri.base.resolveUri(Platform.script);
  if (myLocation.scheme == 'package') {
    Uri runtimePackageRoot =
        Uri.base.resolve(appendSlash(Platform.packageRoot));
    myLocation =
        new Uri.file(
            new File.fromUri(runtimePackageRoot.resolve(myLocation.path))
                .resolveSymbolicLinksSync());
  }

  Uri script = Uri.base.resolve(arguments.single);

  Uri libraryRoot = myLocation.resolve('../../../../dart/sdk/');

  Uri packageRoot = script.resolve('packages/');

  List<String> options = <String>[];

  Map<String, dynamic> environment = <String, dynamic>{};

  FletchCompiler compiler = new FletchCompiler(
      handler.provider,
      outputProvider,
      handler,
      libraryRoot,
      packageRoot,
      options,
      environment);

  compiler.run(script);
}

abstract class FletchCompilerHack extends apiimpl.Compiler {
  FletchCompilerHack(
      api.CompilerInputProvider provider,
      api.CompilerOutputProvider outputProvider,
      api.DiagnosticHandler handler,
      Uri libraryRoot,
      Uri packageRoot,
      List<String> options,
      Map<String, dynamic> environment)
      : super(provider, outputProvider, handler, libraryRoot, packageRoot,
              options, environment) {
    switchBackendHack();
  }

  void switchBackendHack() {
    // TODO(ahe): Modify dart2js to support a custom backend directly, and
    // remove this method.
    int backendTaskCount = backend.tasks.length;
    int apiimplTaskCount = 2;
    int baseTaskCount = tasks.length - backendTaskCount - apiimplTaskCount;

    tasks.removeRange(baseTaskCount, baseTaskCount + backendTaskCount);

    backend = new FletchBackend(this);
    tasks.addAll(backend.tasks);
  }
}

class FletchCompiler extends FletchCompilerHack {
  FletchCompiler(
      api.CompilerInputProvider provider,
      api.CompilerOutputProvider outputProvider,
      api.DiagnosticHandler handler,
      Uri libraryRoot,
      Uri packageRoot,
      List<String> options,
      Map<String, dynamic> environment)
      : super(provider, outputProvider, handler, libraryRoot, packageRoot,
              ['--output-type=dart']..addAll(options), environment);

  void computeMain() {
    if (mainApp == null) return;

    mainFunction = mainApp.findLocal("_entry");
  }

  void onLibraryCreated(elements.LibraryElement library) {
    // TODO(ahe): Remove this.
    library.canUseNative = true;
    super.onLibraryCreated(library);
  }
}

class FletchBackend extends dart2js.Backend {
  final FletchResolutionCallbacks resolutionCallbacks =
      new FletchResolutionCallbacks();

  FletchBackend(dart2js.Compiler compiler)
      : super(compiler);

  List<CompilerTask> get tasks => <CompilerTask>[];

  dart2js.ConstantSystem get constantSystem {
    throw new UnsupportedError("get constantSystem");
  }

  dart2js.BackendConstantEnvironment get constants {
    throw new UnsupportedError("get constants");
  }

  dart2js.ConstantCompilerTask get constantCompilerTask {
    throw new UnsupportedError("get constantCompilerTask");
  }

  void enqueueHelpers(dart2js.ResolutionEnqueuer world, dart2js.Registry registry) {
  }

  void codegen(dart2js.CodegenWorkItem work) {
  }

  bool get canHandleCompilationFailed => true;

  int assembleProgram() {
    compiler.reportHint(
        compiler.mainFunction,
        dart2js.MessageKind.GENERIC,
        {'text': 'Compiling ${compiler.mainFunction.name}'});

    FletchVisitor visitor = new FletchVisitor(compiler.mainFunction);
    compiler.mainFunction.node.accept(visitor);
    print("Constants");
    visitor.constants.forEach((constant, int index) {
      print("  #$index: $constant");
    });

    print("Bytecodes:");
    int offset = 0;
    for (Bytecode bytecode in visitor.bytecodes) {
      print("  $offset: $bytecode");
      offset += bytecode.size;
    }
  }
}

class FletchResolutionCallbacks extends dart2js.ResolutionCallbacks {
}

class FletchVisitor extends SemanticVisitor {
  final List<Bytecode> bytecodes = <Bytecode>[];

  final Map<dynamic, int> constants = <dynamic, int>{};

  FletchVisitor(element)
      : super(element.resolvedAst.elements);

  void visitStaticMethodInvocation(
      Send node,
      /* MethodElement */ element,
      NodeList arguments,
      Selector selector) {
    arguments.accept(this);
    int id = constants.putIfAbsent(element, () => constants.length);
    bytecodes.add(new InvokeStaticUnfold(id));
    bytecodes.add(const Pop());
  }

  void visitLiteralString(LiteralString node) {
    int id = constants.putIfAbsent(
        node.dartString.slowToString(), () => constants.length);
    bytecodes.add(new LoadConstUnfold(id));
  }

  void visitLiteralInt(LiteralInt node) {
    int id = constants.putIfAbsent(node.value, () => constants.length);
    bytecodes.add(new LoadConstUnfold(id));
  }


  void visitLiteral(Literal node) {
    print("literal ${node}");
  }

  void visitFunctionExpression(FunctionExpression node) {
    node.body.accept(this);
  }

  void visitBlock(Block node) {
    node.visitChildren(this);
  }

  void visitNodeList(NodeList node) {
    node.visitChildren(this);
  }

  void visitExpressionStatement(ExpressionStatement node) {
    node.visitChildren(this);
  }

  void visitParameterAccess(Send node, ParameterElement element);

  void visitParameterAssignment(SendSet node, ParameterElement element, Node rhs);
  void visitParameterInvocation(Send node,
                             ParameterElement element,
                             NodeList arguments,
                             Selector selector);

  void visitLocalVariableAccess(Send node, LocalVariableElement element);
  void visitLocalVariableAssignment(SendSet node,
                                 LocalVariableElement element,
                                 Node rhs);
  void visitLocalVariableInvocation(Send node,
                                 LocalVariableElement element,
                                 NodeList arguments,
                                 Selector selector);

  void visitLocalFunctionAccess(Send node, LocalFunctionElement element);
  void visitLocalFunctionAssignment(SendSet node,
                                 LocalFunctionElement element,
                                 Node rhs,
                                 Selector selector);
  void visitLocalFunctionInvocation(Send node,
                                 LocalFunctionElement element,
                                 NodeList arguments,
                                 Selector selector);

  void visitDynamicAccess(Send node, Selector selector);
  void visitDynamicAssignment(SendSet node, Selector selector, Node rhs);
  void visitDynamicInvocation(Send node,
                           NodeList arguments,
                           Selector selector);

  void visitStaticFieldAccess(Send node, FieldElement element);
  void visitStaticFieldAssignment(SendSet node, FieldElement element, Node rhs);
  void visitStaticFieldInvocation(Send node,
                               FieldElement element,
                               NodeList arguments,
                               Selector selector);

  void visitStaticMethodAccess(Send node, MethodElement element);

  void visitStaticPropertyAccess(Send node, FunctionElement element);
  void visitStaticPropertyAssignment(SendSet node,
                                  FunctionElement element,
                                  Node rhs);
  void visitStaticPropertyInvocation(Send node,
                                  FieldElement element,
                                  NodeList arguments,
                                  Selector selector);

  void visitTopLevelFieldAccess(Send node, FieldElement element);
  void visitTopLevelFieldAssignment(SendSet node, FieldElement element, Node rhs);
  void visitTopLevelFieldInvocation(Send node,
                               FieldElement element,
                               NodeList arguments,
                               Selector selector);

  void visitTopLevelMethodAccess(Send node, MethodElement element);
  void visitTopLevelMethodInvocation(Send node,
                                  MethodElement element,
                                  NodeList arguments,
                                  Selector selector);

  void visitTopLevelPropertyAccess(Send node, FunctionElement element);
  void visitTopLevelPropertyAssignment(SendSet node,
                                    FunctionElement element,
                                    Node rhs);
  void visitTopLevelPropertyInvocation(Send node,
                                    FieldElement element,
                                    NodeList arguments,
                                    Selector selector);

  void visitClassTypeLiteralAccess(Send node, ClassElement element);
  void visitClassTypeLiteralInvocation(Send node,
                                    ClassElement element,
                                    NodeList arguments,
                                    Selector selector);
  void visitClassTypeLiteralAssignment(SendSet node,
                                    ClassElement element,
                                    Node rhs);

  void visitTypedefTypeLiteralAccess(Send node, TypedefElement element);

  void visitTypedefTypeLiteralInvocation(Send node,
                                      TypedefElement element,
                                      NodeList arguments,
                                      Selector selector);

  void visitTypedefTypeLiteralAssignment(SendSet node,
                                      TypedefElement element,
                                      Node rhs);

  void visitTypeVariableTypeLiteralAccess(Send node, TypeVariableElement element);

  void visitTypeVariableTypeLiteralInvocation(Send node,
                                           TypeVariableElement element,
                                           NodeList arguments,
                                           Selector selector);

  void visitTypeVariableTypeLiteralAssignment(SendSet node,
                                           TypeVariableElement element,
                                           Node rhs);

  void visitDynamicTypeLiteralAccess(Send node);

  void visitAssert(Send node, Node expression);

  internalError(Spannable spannable, String reason);

}
