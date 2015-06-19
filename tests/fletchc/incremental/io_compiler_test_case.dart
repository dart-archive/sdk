// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Helpers for writing compiler tests running in browser.
library fletchc.test.io_compiler_test_case;

import 'dart:io' show
    File;

import 'dart:async' show
    EventSink,
    Future;

import 'compiler_test_case.dart' show
    customUri,
    CompilerTestCase;

import 'package:fletchc/incremental/fletchc_incremental.dart' show
    IncrementalCompiler,
    OutputProvider;

import 'package:fletchc/commands.dart' show
    Command;

import 'package:fletchc/src/fletch_backend.dart' show
    FletchBackend;

import 'package:fletchc/fletch_system.dart';

import 'package:compiler/compiler.dart' show
    Diagnostic;

const String SDK_SCHEME = 'org.trydart.sdk';

const String PACKAGE_SCHEME = 'org.trydart.packages';

// TODO(ahe): Integrate with pkg/fletchc/lib/compiler.dart.
const String _SDK_DIR =
    const String.fromEnvironment("dart-sdk", defaultValue: "sdk/");

/// A CompilerTestCase which runs in a browser.
class IoCompilerTestCase extends CompilerTestCase {
  final IncrementalCompiler incrementalCompiler;

  IoCompilerTestCase.init(/* Map or String */ source, Uri uri)
      : this.incrementalCompiler = makeCompiler(source, uri),
        super(uri);

  IoCompilerTestCase(/* Map or String */ source, [String path])
      : this.init(source, customUri(path == null ? 'main.dart' : path));

  Future<FletchDelta> run() {
    return incrementalCompiler.compile(scriptUri).then((success) {
      if (!success) throw 'Compilation failed';
      FletchBackend backend = incrementalCompiler.compiler.backend;
      return backend.computeDelta();
    });
  }

  static IncrementalCompiler makeCompiler(
      /* Map or String */ source,
      Uri mainUri) {
    Uri libraryRoot = new Uri(scheme: SDK_SCHEME, path: '/');
    Uri packageRoot = new Uri(scheme: PACKAGE_SCHEME, path: '/');

    Map<Uri, String> sources = <Uri, String>{};
    if (source is String) {
      sources[mainUri] = source;
    } else if (source is Map) {
      source.forEach((String name, String code) {
        sources[mainUri.resolve(name)] = code;
      });
    } else {
      throw new ArgumentError("[source] should be a String or a Map");
    }

    IoInputProvider inputProvider =
        new IoInputProvider(sources, libraryRoot, packageRoot);

    void diagnosticHandler(
        Uri uri, int begin, int end, String message, Diagnostic kind) {
      if (uri == null) {
        print('[$kind] $message');
      } else {
        print('$uri@$begin+${end - begin}: [$kind] $message');
      }
    }

    return new IncrementalCompiler(
        // options: ['--verbose'],
        // libraryRoot: libraryRoot,
        packageRoot: packageRoot,
        inputProvider: inputProvider,
        diagnosticHandler: diagnosticHandler,
        outputProvider: new OutputProvider());
  }
}

/// An input provider which provides input via [HttpRequest].  Includes
/// in-memory compilation units [sources] which are returned when a matching
/// key requested.
class IoInputProvider {
  final Map<Uri, String> sources;

  final Uri libraryRoot;

  final Uri packageRoot;

  final Map<Uri, Future> cachedSources = new Map<Uri, Future>();

  static final Map<Uri, Future> cachedFiles = new Map<Uri, Future>();

  IoInputProvider(this.sources, this.libraryRoot, this.packageRoot);

  Future call(Uri uri) {
    return cachedSources.putIfAbsent(uri, () {
      if (sources.containsKey(uri)) return new Future.value(sources[uri]);
      if (uri.scheme == SDK_SCHEME) {
        return readCachedFile(new Uri.file('${_SDK_DIR}${uri.path}'));
      } else if (uri.scheme == PACKAGE_SCHEME) {
        throw "packages not supported";
      } else {
        return readCachedFile(uri);
      }
    });
  }

  static Future readCachedFile(Uri uri) {
    return cachedFiles.putIfAbsent(
        uri, () => new File.fromUri(uri).readAsString());
  }
}
