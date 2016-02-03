// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';
import 'package:expect/expect.dart';
import '../dartino_compiler/run.dart' show
    export;
import 'dart:convert' show
    LineSplitter,
    UTF8,
    Utf8Decoder;

main() async {
  await testServerClient();
}

typedef Future NoArgFuture();

const String dartinoVmExecutable = const String.fromEnvironment('dartino-vm');
const String testsDir = const String.fromEnvironment('tests-dir');
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

String localFile(path) => Platform.script.resolve(path).toFilePath();

const String certPath = 'third_party/dart/tests/standalone/io/certificates';

SecurityContext createContext() {
  var testDirUri = new Uri.file(testsDir);
  var chain = testDirUri.resolve('../$certPath/server_chain.pem');
  var key = testDirUri.resolve('../$certPath/server_key.pem');
  return new SecurityContext()
    ..useCertificateChain(chain.toFilePath())
    ..usePrivateKey(key.toFilePath(), password: 'dartdart');
}

Future testServerClient() async {
  var server = await SecureServerSocket.bind(InternetAddress.LOOPBACK_IP_V4,
                                             0,
                                             createContext());
  server.listen((SecureSocket client) {
    client
      .transform(UTF8.decoder)
      .listen((s) => client.write(s), onDone: () => client.close());
  });

  var testDirUri = new Uri.file(testsDir);
  var client = testDirUri.resolve('mbedtls_tests/ssl_client.dart');
  var tempTest = '$buildDirectory/tests';
  await new Directory(tempTest).create(recursive: true);
  var snapshot = '$tempTest/ssl_client.snapshot';
  var environment = {
    'SERVER_PORT': '${server.port}'
  };
  await export(client.toFilePath(), snapshot, constants:environment);

  var process = await Process.start(dartinoVmExecutable, [snapshot]);
  // We print this, in the normal case there is no output, but in case of error
  // we actually want it all.
  var stdoutFuture = process.stdout.transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen((s) => print('dartino-vm(stdout): $s')).asFuture();
  var stderrFuture = process.stderr.transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen((s) => print('dartino-vm(stderr): $s')).asFuture();
  var result = await process.exitCode;
  await server.close();
  await stdoutFuture;
  await stderrFuture;
  Expect.equals(result, 0);

}
