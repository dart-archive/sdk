// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dartino_compiler_incremental;

/// Do not call this method directly. It will be made private.
// TODO(ahe): Make this method private.
Future<CompilerImpl> reuseCompiler(
    {CompilerDiagnostics diagnosticHandler,
     CompilerInput inputProvider,
     CompilerOutput outputProvider,
     DartinoCompilerOptions options,
     CompilerImpl cachedCompiler,
     Uri nativesJson,
     Uri dartinoVm,
     bool packagesAreImmutable: false,
     ReuseLibrariesFunction reuseLibraries,
     Uri base,
     IncrementalCompiler incrementalCompiler}) async {
  UserTag oldTag = new UserTag('_reuseCompiler').makeCurrent();
  if (inputProvider == null) {
    throw 'Missing inputProvider';
  }
  if (inputProvider is SourceFileProvider && base != null) {
    inputProvider.cwd = base;
  }
  if (diagnosticHandler == null) {
    throw 'Missing diagnosticHandler';
  }
  if (outputProvider == null) {
    outputProvider = new OutputProvider();
  }
  CompilerImpl compiler = cachedCompiler;
  if (compiler == null ||
      compiler.libraryRoot != options.libraryRoot ||
      !compiler.options.hasIncrementalSupport ||
      compiler.hasCrashed ||
      compiler.enqueuer.resolution.hasEnqueuedReflectiveElements ||
      compiler.deferredLoadTask.isProgramSplit) {
    if (compiler != null && compiler.options.hasIncrementalSupport) {
      if (compiler.hasCrashed) {
        throw new IncrementalCompilationFailed(
            "Unable to reuse compiler due to crash");
      } else if (compiler.enqueuer.resolution.hasEnqueuedReflectiveElements) {
        throw new IncrementalCompilationFailed(
            "Unable to reuse compiler due to dart:mirrors");
      } else if (compiler.deferredLoadTask.isProgramSplit) {
        throw new IncrementalCompilationFailed(
            "Unable to reuse compiler due to deferred loading");
      } else {
        throw new IncrementalCompilationFailed(
            "Unable to reuse compiler");
      }
    }
    oldTag.makeCurrent();
    DartinoCompiler dartinoCompiler = new DartinoCompiler(
        provider: inputProvider,
        outputProvider: outputProvider,
        handler: diagnosticHandler,
        nativesJson: nativesJson,
        dartinoVm: dartinoVm,
        options: options,
        incrementalCompiler: incrementalCompiler);
    compiler = await dartinoCompiler.backdoor.compilerImplementation;
    return compiler;
  } else {
    for (final task in compiler.tasks) {
      if (task.watch != null) {
        task.watch.reset();
      }
    }
    compiler
        ..userOutputProvider = outputProvider
        ..provider = inputProvider
        ..handler = diagnosticHandler
        ..enqueuer.resolution.queueIsClosed = false
        ..enqueuer.resolution.hasEnqueuedReflectiveElements = false
        ..enqueuer.resolution.hasEnqueuedReflectiveStaticFields = false
        ..enqueuer.codegen.queueIsClosed = false
        ..enqueuer.codegen.hasEnqueuedReflectiveElements = false
        ..enqueuer.codegen.hasEnqueuedReflectiveStaticFields = false
        ..compilationFailed = false;

    if (reuseLibraries == null) {
      reuseLibraries = (Iterable<LibraryElement> libraries) async {
        return libraries.where((LibraryElement library) {
          return library.isPlatformLibrary ||
              (packagesAreImmutable && library.isPackageLibrary);
        });
      };
    }
    return compiler.libraryLoader.resetLibraries(reuseLibraries).then((_) {
      oldTag.makeCurrent();
      return compiler;
    });
  }
}

/// Helper class to collect sources.
class StringEventSink implements EventSink<String> {
  List<String> data = <String>[];

  final Function onClose;

  StringEventSink(this.onClose);

  void add(String event) {
    if (data == null) throw 'StringEventSink is closed.';
    data.add(event);
  }

  void addError(errorEvent, [StackTrace stackTrace]) {
    throw 'addError($errorEvent, $stackTrace)';
  }

  void close() {
    if (data != null) {
      onClose(data.join());
      data = null;
    }
  }
}
