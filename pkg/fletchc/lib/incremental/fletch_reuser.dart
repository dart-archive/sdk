// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc_incremental.fletch_reuser;

import 'package:compiler/compiler_new.dart' show
    CompilerDiagnostics,
    Diagnostic;

import 'package:compiler/compiler.dart' as api;

import 'package:compiler/src/compiler.dart' show
    Compiler;

import 'package:compiler/src/enqueue.dart' show
    EnqueueTask;

import 'package:compiler/src/elements/elements.dart' show
    AstElement,
    ClassElement,
    Element,
    FieldElement,
    FunctionElement;

import 'package:compiler/src/parser/partial_elements.dart' show
    PartialClassElement,
    PartialElement,
    PartialFunctionElement;

import 'package:compiler/src/elements/modelx.dart' show
    ClassElementX,
    FieldElementX,
    LibraryElementX;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import '../incremental_backend.dart' show
    IncrementalFletchBackend;

import '../src/fletch_class_builder.dart' show
    FletchClassBuilder;

import '../src/fletch_context.dart' show
    FletchContext;

import '../src/fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import '../src/fletch_function_builder.dart' show
    FletchFunctionBuilder;

import '../vm_commands.dart' show
    PrepareForChanges,
    VmCommand;

import '../fletch_system.dart' show
    FletchDelta,
    FletchSystem;

import 'fletchc_incremental.dart' show
    IncrementalCompilationFailed,
    IncrementalCompiler;

import 'reuser.dart' show
    AddedClassUpdate,
    AddedFieldUpdate,
    AddedFunctionUpdate,
    ClassUpdate,
    Logger,
    RemovedClassUpdate,
    RemovedFieldUpdate,
    RemovedFunctionUpdate,
    Reuser;

export 'reuser.dart' show
    Logger;

abstract class _IncrementalCompilerContext {
  IncrementalCompiler incrementalCompiler;
}

class IncrementalCompilerContext extends _IncrementalCompilerContext
    implements CompilerDiagnostics {
  final CompilerDiagnostics diagnostics;
  int errorCount = 0;
  int warningCount = 0;
  int hintCount = 0;

  final Set<Uri> _uriWithUpdates = new Set<Uri>();

  IncrementalCompilerContext(this.diagnostics);

  int get problemCount => errorCount + warningCount + hintCount;

  void set incrementalCompiler(IncrementalCompiler value) {
    if (super.incrementalCompiler != null) {
      throw new StateError("Can't set [incrementalCompiler] more than once");
    }
    super.incrementalCompiler = value;
  }

  void registerUriWithUpdates(Iterable<Uri> uris) {
    _uriWithUpdates.addAll(uris);
  }

  bool _uriHasUpdate(Uri uri) => _uriWithUpdates.contains(uri);

  void report(
      var code,
      Uri uri,
      int begin,
      int end,
      String text,
      Diagnostic kind) {
    if (kind == Diagnostic.ERROR) {
      errorCount++;
    }
    if (kind == Diagnostic.WARNING) {
      warningCount++;
    }
    if (kind == Diagnostic.HINT) {
      hintCount++;
    }
    if (_uriHasUpdate(uri)) {
      // TODO(ahe): Map location to updated source file.
      print("$uri+$begin-$end: $text");
    } else {
      diagnostics.report(code, uri, begin, end, text, kind);
    }
  }
}

class FletchReuser extends Reuser with FletchFeatures {
  final IncrementalCompilerContext _context;

  FletchReuser(
      FletchCompilerImplementation compiler,
      api.CompilerInputProvider inputProvider,
      Logger logTime,
      Logger logVerbose,
      this._context)
      : super(compiler, inputProvider, logTime, logVerbose);

  FletchDelta computeUpdateFletch(FletchSystem currentSystem) {
    // TODO(ahe): Remove this when we support adding static fields.
    Set<Element> existingStaticFields =
        new Set<Element>.from(fletchContext.staticIndices.keys);

    backend.newSystemBuilder(currentSystem);

    List<Element> updatedElements = applyUpdates();

    if (compiler.progress != null) {
      compiler.progress.reset();
    }

    for (Element element in updatedElements) {
      if (!element.isClass) {
        if (element.isClassMember) {
          element.enclosingClass.ensureResolved(compiler.resolution);
        }
        enqueuer.resolution.addToWorkList(element);
      } else {
        ClassElement cls = element;
        cls.ensureResolved(compiler.resolution);

        // We've told the enqueuer to forget this class, now tell it that it's
        // in use again.  TODO(ahe): We only need to do this if [cls] was
        // already instantiated.
        enqueuer.codegen.registerInstantiatedType(cls.rawType);
      }
    }
    compiler.processQueue(enqueuer.resolution, null);

    compiler.phase = Compiler.PHASE_DONE_RESOLVING;

    // TODO(ahe): Clean this up. Don't call this method in analyze-only mode.
    if (compiler.analyzeOnly) {
      return new FletchDelta(currentSystem, currentSystem, <VmCommand>[]);
    }

    for (AstElement element in updatedElements) {
      if (element.node.isErroneous) {
        throw new IncrementalCompilationFailed(
            "Unable to incrementally compile $element with syntax error");
      }
      if (element.isField) {
        backend.newElement(element);
      } else if (!element.isClass) {
        enqueuer.codegen.addToWorkList(element);
      }
    }
    compiler.processQueue(enqueuer.codegen, null);

    // TODO(ahe): Remove this when we support adding static fields.
    Set<Element> newStaticFields =
        new Set<Element>.from(fletchContext.staticIndices.keys).difference(
            existingStaticFields);
    if (newStaticFields.isNotEmpty) {
      throw new IncrementalCompilationFailed(
          "Unable to add static fields:\n  ${newStaticFields.join(',\n  ')}");
    }

    List<VmCommand> commands = <VmCommand>[const PrepareForChanges()];
    FletchSystem system =
        backend.systemBuilder.computeSystem(fletchContext, commands);
    return new FletchDelta(system, currentSystem, commands);
  }

  void addClassUpdate(
      Compiler compiler,
      PartialClassElement before,
      PartialClassElement after) {
    updates.add(new FletchClassUpdate(compiler, before, after));
  }

  void addAddedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element,
      /* ScopeContainerElement */ container) {
    updates.add(new FletchAddedFunctionUpdate(compiler, element, container));
  }

  void addRemovedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element) {
    updates.add(new FletchRemovedFunctionUpdate(compiler, element));
  }

  void addRemovedFieldUpdate(
      Compiler compiler,
      FieldElementX element) {
    updates.add(new FletchRemovedFieldUpdate(compiler, element));
  }

  void addRemovedClassUpdate(
      Compiler compiler,
      PartialClassElement element) {
    updates.add(new FletchRemovedClassUpdate(compiler, element));
  }

  void addAddedFieldUpdate(
      Compiler compiler,
      FieldElementX element,
      /* ScopeContainerElement */ container) {
    updates.add(new FletchAddedFieldUpdate(compiler, element, container));
  }

  void addAddedClassUpdate(
      Compiler compiler,
      PartialClassElement element,
      LibraryElementX library) {
    updates.add(new FletchAddedClassUpdate(compiler, element, library));
  }

  static void forEachField(ClassElement c, void action(FieldElement field)) {
    List classes = [];
    while (c != null) {
      if (!c.isResolved) {
        throw new IncrementalCompilationFailed("Class not resolved: $c");
      }
      classes.add(c);
      c = c.superclass;
    }
    for (int i = classes.length - 1; i >= 0; i--) {
      classes[i].implementation.forEachInstanceField((_, FieldElement field) {
        action(field);
      });
    }
  }

  bool uriHasUpdate(Uri uri) => _context._uriHasUpdate(uri);

  bool allowClassHeaderModified(PartialClassElement after) {
    if (!_context.incrementalCompiler.isExperimentalModeEnabled) {
      return cannotReuse(
          after,
          "Changing a class header requires requires 'experimental' mode");
    }
    return true;
  }

  bool allowSignatureChanged(
      PartialFunctionElement before,
      PartialFunctionElement after) {
    if (!_context.incrementalCompiler.isExperimentalModeEnabled) {
      return cannotReuse(
          after, "Signature change requires 'experimental' mode");
    }
    return true;
  }

  bool allowNonInstanceMemberModified(PartialFunctionElement after) {
    if (!_context.incrementalCompiler.isExperimentalModeEnabled) {
      return cannotReuse(
          after, "Non-instance member requires 'experimental' mode");
    }
    return true;
  }

  bool allowRemovedElement(PartialElement element) {
    if (!_context.incrementalCompiler.isExperimentalModeEnabled) {
      return cannotReuse(
          element, "Removing elements requires 'experimental' mode");
    }
    return true;
  }

  bool allowAddedElement(PartialElement element) {
    if (!_context.incrementalCompiler.isExperimentalModeEnabled) {
      return cannotReuse(
          element, "Adding elements requires 'experimental' mode");
    }
    return true;
  }
}

class FletchRemovedFunctionUpdate extends RemovedFunctionUpdate
    with FletchFeatures {
  FletchRemovedFunctionUpdate(Compiler compiler, PartialFunctionElement element)
      : super(compiler, element);
}

class FletchRemovedClassUpdate extends RemovedClassUpdate with FletchFeatures {
  FletchRemovedClassUpdate(Compiler compiler, PartialClassElement element)
      : super(compiler, element);
}

class FletchRemovedFieldUpdate extends RemovedFieldUpdate with FletchFeatures {
  // TODO(ahe): Remove?
  FletchClassBuilder beforeFletchClassBuilder;

  FletchRemovedFieldUpdate(Compiler compiler, FieldElementX element)
      : super(compiler, element);
}

class FletchAddedFunctionUpdate extends AddedFunctionUpdate
    with FletchFeatures {
  FletchAddedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element,
      /* ScopeContainerElement */ container)
      : super(compiler, element, container);
}

class FletchAddedClassUpdate extends AddedClassUpdate with FletchFeatures {
  FletchAddedClassUpdate(
      Compiler compiler,
      PartialClassElement element,
      LibraryElementX library)
      : super(compiler, element, library);
}

class FletchAddedFieldUpdate extends AddedFieldUpdate with FletchFeatures {
  FletchAddedFieldUpdate(
      Compiler compiler,
      FieldElementX element,
      /* ScopeContainerElement */ container)
      : super(compiler, element, container);
}

class FletchClassUpdate extends ClassUpdate with FletchFeatures {
  FletchClassUpdate(
      Compiler compiler,
      PartialClassElement before,
      PartialClassElement after)
      : super(compiler, before, after);
}

abstract class FletchFeatures {
  FletchCompilerImplementation get compiler;

  IncrementalFletchBackend get backend {
    return compiler.backend as IncrementalFletchBackend;
  }

  EnqueueTask get enqueuer => compiler.enqueuer;

  FletchContext get fletchContext => compiler.context;

  FletchFunctionBuilder lookupFletchFunctionBuilder(FunctionElement function) {
    return backend.systemBuilder.lookupFunctionBuilderByElement(function);
  }
}
