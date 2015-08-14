// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library test.dart2js_helper;

import 'dart:async';
import 'dart:fletch.io';

import 'package:async_helper/async_helper.dart';
import 'package:compiler/compiler.dart';
import 'package:expect/expect.dart';

final mainScriptUri = new Uri(
    scheme: "org.dartlang.fletch",
    path: "/main.dart");

void run(Uri uri, String mainScript, bool isServer) {

  void diagnosticHandler(
      Uri uri, int begin, int end, String message, Diagnostic kind) {
  }

  Future compilerInputProvider(Uri uri) {
    if (uri == mainScriptUri) {
      return new Future.value(mainScript);
    }
    var file = new File.open(uri.path);
    var buffer = file.read(file.length + 1).asUint8List();
    file.close();
    return new Future.value(buffer);
  }

  bool hasOutput = false;

  EventSink<String> compilerOutputProvider(String name, String extension) {
    var c = new StreamController(sync: true);

    asyncStart();
    c.stream.listen(
      (data) {
        hasOutput = true;
      },
      onDone: () {
        asyncEnd();
      });

    return c;
  }

  asyncStart();
  compile(
      uri,
      Uri.base.resolve('../dart/sdk/'),
      new Uri(path: 'package/'),
      compilerInputProvider,
      diagnosticHandler,
      isServer ? ['--categories=Server'] : [],
      compilerOutputProvider).then((result) {
    Expect.isTrue(result.isSuccess);
    Expect.isTrue(hasOutput);
    asyncEnd();
  });
}

void compileUri(Uri uri, {bool isServer : false}) {
  run(uri, null, isServer);
}

void compileScript(String script, {bool isServer : false}) {
  run(mainScriptUri, script, isServer);
}
