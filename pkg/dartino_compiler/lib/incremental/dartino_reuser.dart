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
    ElementX,
    FieldElementX,
    LibraryElementX;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import '../incremental_backend.dart' show
    IncrementalDartinoBackend;

import '../src/dartino_class_builder.dart' show
    DartinoPatchClassBuilder,
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
    DartinoFunction,
    DartinoSystem;

import '../src/dartino_system_builder.dart' show
    DartinoSystemBuilder,
    SchemaChange;

import 'dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed,
    IncrementalCompiler;

import 'reuser.dart' show
    AddedClassUpdate,
    AddedFieldUpdate,
    AddedFunctionUpdate,
    ClassUpdate,
    FunctionUpdate,
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

  final Map<PartialClassElement, SchemaChange> schemaChangesByClass =
      <PartialClassElement, SchemaChange>{};

  DartinoReuser(
      DartinoCompilerImplementation compiler,
      api.CompilerInputProvider inputProvider,
      Logger logTime,
      Logger logVerbose,
      this._context)
      : super(compiler, inputProvider, logTime, logVerbose);

  // TODO(ahe): If I remove this, I don't get type errors on backend.
  IncrementalDartinoBackend get backend => super.backend;

  DartinoDelta computeUpdateDartino(DartinoSystem currentSystem) {
    // TODO(ahe): Remove this when we support adding static fields.
    Set<Element> existingStaticFields =
        new Set<Element>.from(dartinoContext.staticIndices.keys);

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
    computeAllSchemaChanges();
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
        // TODO(ahe): Enqueue fields?
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

    List<VmCommand> commands = <VmCommand>[];
    DartinoSystem system =
        systemBuilder.computeSystem(dartinoContext, commands);
    backend.newSystemBuilder(system);
    return new DartinoDelta(system, currentSystem, commands);
  }

  void computeAllSchemaChanges() {
    for (PartialClassElement cls in schemaChangesByClass.keys.toList()) {
      SchemaChange schemaChange = getSchemaChange(cls);
      backend.forEachSubclassOf(cls, (ClassElement subclass) {
        if (cls == subclass) return;
        getSchemaChange(subclass).addSchemaChange(schemaChange);
      });
    }
    void checkSchemaChangesAreUsed(
        DartinoClassBuilder builder,
        PartialClassElement cls) {
      // TODO(ahe): Eventually, this should be an assertion.
      if (builder is DartinoPatchClassBuilder) {
        SchemaChange schemaChange = schemaChangesByClass[cls];
        if (!builder.addedFields.toSet().containsAll(
                schemaChange.addedFields)) {
          throw new IncrementalCompilationFailed(
              "Missing added fields in $cls");
        }
        if (!builder.removedFields.toSet().containsAll(
                schemaChange.removedFields)) {
          throw new IncrementalCompilationFailed(
              "Missing removed fields in $cls");
        }
      } else {
        throw new IncrementalCompilationFailed(
            "Patched class is registered as new: $cls");
      }
    }
    for (PartialClassElement cls in schemaChangesByClass.keys) {
      DartinoClassBuilder builder = systemBuilder.getClassBuilder(
          cls, backend, schemaChanges: schemaChangesByClass);
      checkSchemaChangesAreUsed(builder, cls);
    }
  }

  void addClassUpdate(
      Compiler compiler,
      PartialClassElement before,
      PartialClassElement after) {
    updates.add(new DartinoClassUpdate(compiler, before, after));
  }

  void addFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement before,
      PartialFunctionElement after) {
    updates.add(new DartinoFunctionUpdate(compiler, before, after));
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
    if (element.isInstanceMember) {
      getSchemaChange(element.enclosingClass).addRemovedField(element);
    }
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
    SchemaChange schemaChange;
    if (element.isInstanceMember) {
      schemaChange = getSchemaChange(container);
    }
    updates.add(
        new DartinoAddedFieldUpdate(
            compiler, element, container, schemaChange));
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
    if (element is PartialFunctionElement && element.isInstanceMember) {
      return true;
    }
    if (!_context.incrementalCompiler.isExperimentalModeEnabled) {
      return cannotReuse(
          element, "Removing elements besides instance methods requires"
                   " 'experimental' mode");
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

  bool allowSimpleModificationWithNestedClosures(PartialElement element) {
    return cannotReuse(
        element, "Simple modification of methods with nested closures is not"
                 " supported.");
  }

  SchemaChange getSchemaChange(PartialClassElement cls) {
    return schemaChangesByClass.putIfAbsent(cls, () => new SchemaChange(cls));
  }

  void replaceFunctionInBackend(ElementX element) {
    DartinoFunction oldFunction =
        systemBuilder.predecessorSystem.lookupFunctionByElement(element);
    if (oldFunction == null) return;
    Iterable<int> users =
        systemBuilder.predecessorSystem.functionBackReferences[
            oldFunction.functionId];
    if (users == null) return;
    for (int userId in users) {
      systemBuilder.replaceUsage(userId, oldFunction.functionId);
    }
  }
}

class DartinoFunctionUpdate extends FunctionUpdate with DartinoFeatures {
  DartinoFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement before,
      PartialFunctionElement after)
      : super(compiler, before, after);
}

class DartinoRemovedFunctionUpdate extends RemovedFunctionUpdate
    with DartinoFeatures {
  DartinoRemovedFunctionUpdate(Compiler compiler,
                               PartialFunctionElement element)
      : super(compiler, element);
}

class DartinoRemovedClassUpdate extends RemovedClassUpdate
    with DartinoFeatures {
  DartinoRemovedClassUpdate(Compiler compiler, PartialClassElement element)
      : super(compiler, element);
}

class DartinoRemovedFieldUpdate extends RemovedFieldUpdate
    with DartinoFeatures {
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
  final SchemaChange schemaChange;

  DartinoAddedFieldUpdate(
      Compiler compiler,
      FieldElementX element,
      /* ScopeContainerElement */ container,
      this.schemaChange)
      : super(compiler, element, container);

  FieldElementX apply(IncrementalDartinoBackend backend) {
    FieldElementX newField = super.apply(backend);
    if (newField.isInstanceMember) {
      schemaChange.addAddedField(newField);
    }
    return newField;
  }
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

  DartinoSystemBuilder get systemBuilder => backend.systemBuilder;

  DartinoFunctionBuilder lookupDartinoFunctionBuilder(
      FunctionElement function) {
    return systemBuilder.lookupFunctionBuilderByElement(function);
  }
}
