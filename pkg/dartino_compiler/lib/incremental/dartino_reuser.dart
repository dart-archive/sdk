// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler_incremental.dartino_reuser;

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
    IncrementalDartinoBackend;

import '../src/dartino_class_builder.dart' show
    DartinoClassBuilder;

import '../src/dartino_context.dart' show
    DartinoContext;

import '../src/dartino_compiler_implementation.dart' show
    DartinoCompilerImplementation;

import '../src/dartino_function_builder.dart' show
    DartinoFunctionBuilder;

import '../vm_commands.dart' show
    PrepareForChanges,
    VmCommand;

import '../dartino_system.dart' show
    DartinoDelta,
    DartinoSystem;

import 'dartino_compiler_incremental.dart' show
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
    diagnostics.report(code, uri, begin, end, text, kind);
  }
}

class DartinoReuser extends Reuser with DartinoFeatures {
  final IncrementalCompilerContext _context;

  DartinoReuser(
      DartinoCompilerImplementation compiler,
      api.CompilerInputProvider inputProvider,
      Logger logTime,
      Logger logVerbose,
      this._context)
      : super(compiler, inputProvider, logTime, logVerbose);

  DartinoDelta computeUpdateDartino(DartinoSystem currentSystem) {
    // TODO(ahe): Remove this when we support adding static fields.
    Set<Element> existingStaticFields =
        new Set<Element>.from(dartinoContext.staticIndices.keys);

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
      return new DartinoDelta(currentSystem, currentSystem, <VmCommand>[]);
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
        new Set<Element>.from(dartinoContext.staticIndices.keys).difference(
            existingStaticFields);
    if (newStaticFields.isNotEmpty) {
      throw new IncrementalCompilationFailed(
          "Unable to add static fields:\n  ${newStaticFields.join(',\n  ')}");
    }

    List<VmCommand> commands = <VmCommand>[const PrepareForChanges()];
    DartinoSystem system =
        backend.systemBuilder.computeSystem(dartinoContext, commands);
    return new DartinoDelta(system, currentSystem, commands);
  }

  void addClassUpdate(
      Compiler compiler,
      PartialClassElement before,
      PartialClassElement after) {
    updates.add(new DartinoClassUpdate(compiler, before, after));
  }

  void addAddedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element,
      /* ScopeContainerElement */ container) {
    updates.add(new DartinoAddedFunctionUpdate(compiler, element, container));
  }

  void addRemovedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element) {
    updates.add(new DartinoRemovedFunctionUpdate(compiler, element));
  }

  void addRemovedFieldUpdate(
      Compiler compiler,
      FieldElementX element) {
    updates.add(new DartinoRemovedFieldUpdate(compiler, element));
  }

  void addRemovedClassUpdate(
      Compiler compiler,
      PartialClassElement element) {
    updates.add(new DartinoRemovedClassUpdate(compiler, element));
  }

  void addAddedFieldUpdate(
      Compiler compiler,
      FieldElementX element,
      /* ScopeContainerElement */ container) {
    updates.add(new DartinoAddedFieldUpdate(compiler, element, container));
  }

  void addAddedClassUpdate(
      Compiler compiler,
      PartialClassElement element,
      LibraryElementX library) {
    updates.add(new DartinoAddedClassUpdate(compiler, element, library));
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

class DartinoRemovedFunctionUpdate extends RemovedFunctionUpdate
    with DartinoFeatures {
  DartinoRemovedFunctionUpdate(Compiler compiler, PartialFunctionElement element)
      : super(compiler, element);
}

class DartinoRemovedClassUpdate extends RemovedClassUpdate with DartinoFeatures {
  DartinoRemovedClassUpdate(Compiler compiler, PartialClassElement element)
      : super(compiler, element);
}

class DartinoRemovedFieldUpdate extends RemovedFieldUpdate with DartinoFeatures {
  // TODO(ahe): Remove?
  DartinoClassBuilder beforeDartinoClassBuilder;

  DartinoRemovedFieldUpdate(Compiler compiler, FieldElementX element)
      : super(compiler, element);
}

class DartinoAddedFunctionUpdate extends AddedFunctionUpdate
    with DartinoFeatures {
  DartinoAddedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element,
      /* ScopeContainerElement */ container)
      : super(compiler, element, container);
}

class DartinoAddedClassUpdate extends AddedClassUpdate with DartinoFeatures {
  DartinoAddedClassUpdate(
      Compiler compiler,
      PartialClassElement element,
      LibraryElementX library)
      : super(compiler, element, library);
}

class DartinoAddedFieldUpdate extends AddedFieldUpdate with DartinoFeatures {
  DartinoAddedFieldUpdate(
      Compiler compiler,
      FieldElementX element,
      /* ScopeContainerElement */ container)
      : super(compiler, element, container);
}

class DartinoClassUpdate extends ClassUpdate with DartinoFeatures {
  DartinoClassUpdate(
      Compiler compiler,
      PartialClassElement before,
      PartialClassElement after)
      : super(compiler, before, after);
}

abstract class DartinoFeatures {
  DartinoCompilerImplementation get compiler;

  IncrementalDartinoBackend get backend {
    return compiler.backend as IncrementalDartinoBackend;
  }

  EnqueueTask get enqueuer => compiler.enqueuer;

  DartinoContext get dartinoContext => compiler.context;

  DartinoFunctionBuilder lookupDartinoFunctionBuilder(FunctionElement function) {
    return backend.systemBuilder.lookupFunctionBuilderByElement(function);
  }
}
