// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_compiler;

import 'package:compiler/compiler.dart' as api;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'package:compiler/src/elements/modelx.dart' show
    LibraryElementX;

import 'fletch_context.dart';

part 'fletch_compiler_hack.dart';

const EXTRA_DART2JS_OPTIONS = const <String>[
    // TODO(ahe): This doesn't completely disable type inference. Investigate.
    '--disable-type-inference',
    '--output-type=dart',
];

class FletchCompiler extends FletchCompilerHack {
  final Uri fletchVm;

  FletchContext internalContext;

  FletchCompiler(
      api.CompilerInputProvider provider,
      api.CompilerOutputProvider outputProvider,
      api.DiagnosticHandler handler,
      Uri libraryRoot,
      Uri packageRoot,
      List<String> options,
      Map<String, dynamic> environment,
      this.fletchVm)
      : super(
          provider, outputProvider, handler, libraryRoot, packageRoot,
          EXTRA_DART2JS_OPTIONS.toList()..addAll(options), environment);

  FletchContext get context {
    if (internalContext == null) {
      internalContext = new FletchContext(this);
    }
    return internalContext;
  }

  void computeMain() {
    if (mainApp == null) return;

    mainFunction = mainApp.findLocal("_entry");
  }

  void onLibraryCreated(LibraryElementX library) {
    // TODO(ahe): Remove this.
    library.canUseNative = true;
    super.onLibraryCreated(library);
  }
}
