// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletchc.fletch_compiler;

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
