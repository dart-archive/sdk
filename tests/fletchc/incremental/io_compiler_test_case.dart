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
    IncrementalCompiler;

import 'package:fletchc/incremental/compiler.dart' show
    OutputProvider;

import 'package:fletchc/commands.dart' show
    Command;

import 'package:fletchc/src/fletch_backend.dart' show
    FletchBackend;

import 'package:fletchc/fletch_system.dart';

import 'package:compiler/compiler.dart' show
    Diagnostic;

import 'package:compiler/src/source_file_provider.dart' show
    FormattingDiagnosticHandler,
    SourceFileProvider;

import 'package:compiler/src/io/source_file.dart' show
    StringSourceFile;

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

    return new IncrementalCompiler(
        // options: ['--verbose'],
        // libraryRoot: libraryRoot,
        packageRoot: packageRoot,
        inputProvider: inputProvider,
        diagnosticHandler: new FormattingDiagnosticHandler(inputProvider),
        outputProvider: new OutputProvider());
  }
}

/// An input provider which provides input via the class [File].  Includes
/// in-memory compilation units [sources] which are returned when a matching
/// key requested.
class IoInputProvider extends SourceFileProvider {
  final Map<Uri, String> sources;

  final Uri libraryRoot;

  final Uri packageRoot;

  final Map<Uri, Future> cachedSources = new Map<Uri, Future>();

  static final Map<Uri, String> cachedFiles = new Map<Uri, String>();

  IoInputProvider(this.sources, this.libraryRoot, this.packageRoot);

  Future readFromUri(Uri uri) {
    return cachedSources.putIfAbsent(uri, () {
      String text;
      String name;
      if (sources.containsKey(uri)) {
        name = '$uri';
        text = sources[uri];
      } else {
        if (uri.scheme == SDK_SCHEME) {
          uri = cwd.resolve('${_SDK_DIR}${uri.path}');
        } else if (uri.scheme == PACKAGE_SCHEME) {
          throw "packages not supported";
        }
        text = readCachedFile(uri);
        name = new File.fromUri(uri).path;
      }
      sourceFiles[uri] = new StringSourceFile(uri, name, text);
      return new Future<String>.value(text);
    });
  }

  Future call(Uri uri) => readStringFromUri(uri);

  Future<String> readStringFromUri(Uri uri) {
    return readFromUri(uri);
  }

  Future<List<int>> readUtf8BytesFromUri(Uri uri) {
    throw "not supported";
  }

  static String readCachedFile(Uri uri) {
    return cachedFiles.putIfAbsent(
        uri, () => new File.fromUri(uri).readAsStringSync());
  }
}
