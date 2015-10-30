// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of fletchc_incremental;

/// Do not call this method directly. It will be made private.
// TODO(ahe): Make this method private.
Future<Compiler> reuseCompiler(
    {CompilerDiagnostics diagnosticHandler,
     CompilerInput inputProvider,
     CompilerOutput outputProvider,
     List<String> options: const [],
     Compiler cachedCompiler,
     Uri libraryRoot,
     Uri patchRoot,
     Uri nativesJson,
     Uri packageConfig,
     Uri fletchVm,
     bool packagesAreImmutable: false,
     Map<String, dynamic> environment,
     Future<bool> reuseLibrary(LibraryElement library),
     List<Category> categories}) async {
  UserTag oldTag = new UserTag('_reuseCompiler').makeCurrent();
  // if (libraryRoot == null) {
  //   throw 'Missing libraryRoot';
  // }
  if (inputProvider == null) {
    throw 'Missing inputProvider';
  }
  if (diagnosticHandler == null) {
    throw 'Missing diagnosticHandler';
  }
  if (outputProvider == null) {
    outputProvider = new OutputProvider();
  }
  if (environment == null) {
    environment = {};
  }
  Compiler compiler = cachedCompiler;
  if (compiler == null ||
      (libraryRoot != null && compiler.libraryRoot != libraryRoot) ||
      !compiler.hasIncrementalSupport ||
      compiler.hasCrashed ||
      compiler.enqueuer.resolution.hasEnqueuedReflectiveElements ||
      compiler.deferredLoadTask.isProgramSplit) {
    if (compiler != null && compiler.hasIncrementalSupport) {
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
    compiler = await new FletchCompiler(
        provider: inputProvider,
        outputProvider: outputProvider,
        handler: diagnosticHandler,
        libraryRoot: libraryRoot,
        patchRoot: patchRoot,
        nativesJson: nativesJson,
        packageConfig: packageConfig,
        fletchVm: fletchVm,
        options: options,
        environment: environment,
        categories: categories).backdoor.compilerImplementation;
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

    if (reuseLibrary == null) {
      reuseLibrary = (LibraryElement library) {
        return new Future.value(
            library.isPlatformLibrary ||
            (packagesAreImmutable && library.isPackageLibrary));
      };
    }
    return compiler.libraryLoader.resetAsync(reuseLibrary).then((_) {
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
