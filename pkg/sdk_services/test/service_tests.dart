// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'package:expect/expect.dart';
import 'package:sdk_services/sdk_services.dart';

import 'utils.dart';

main() async {
  await testSuccessfullDownload();
  await testSuccessfullDownloadWithFailures();
  await testFailingDownload();
}

Future testSuccessfullDownload() async {
  Server server = await Server.start();
  TestOutputService output = new TestOutputService();
  SDKServices service = new SDKServices(output);
  var dir = await Directory.systemTemp.createTemp("download_test");
  var tmpFile = new File("${dir.path}download");
  await service.downloadWithProgress(
      Uri.parse('http://127.0.0.1:${server.port}'), tmpFile);
  var result = output.output;
  Expect.equals(-1, result.indexOf('Failed'));
  Expect.isTrue(result.indexOf('DONE') > 0);
  Expect.equals(server.successDownloadSize,
                (await tmpFile.readAsBytes()).length);

  await server.done;
  await(dir.delete(recursive: true));
}

Future testSuccessfullDownloadWithFailures() async {
  const failureCount = 5;
  Server server = await Server.start(failureCount: failureCount);

  TestOutputService output = new TestOutputService();
  SDKServices service = new SDKServices(output);
  var dir = await Directory.systemTemp.createTemp("download_test");
  var tmpFile = new File("${dir.path}download");
  await service.downloadWithProgress(
      Uri.parse('http://127.0.0.1:${server.port}'),
      tmpFile,
      retryCount: failureCount + 1,
      retryInterval: const Duration(milliseconds: 10));

  var result = output.output;
  Expect.isTrue(result.indexOf('Failed') > 0);
  Expect.isTrue(result.indexOf('Retrying in 0 seconds') > 0);
  Expect.isTrue(result.indexOf('DONE') > 0);
  Expect.equals(server.successDownloadSize,
                (await tmpFile.readAsBytes()).length);

  await server.done;
  await(dir.delete(recursive: true));
}

Future testFailingDownload() async {
  const failureCount = 5;
  Server server = await Server.start(failureCount: failureCount);

  TestOutputService output = new TestOutputService();
  SDKServices service = new SDKServices(output);
  var dir = await Directory.systemTemp.createTemp("download_test");
  var tmpFile = new File("${dir.path}download");

  try {
    await service.downloadWithProgress(
        Uri.parse('http://127.0.0.1:${server.port}'),
        tmpFile,
        retryCount: failureCount - 1,
        retryInterval: const Duration(milliseconds: 10));
    Expect.fail('Unexpected: Download succeeded');
  } on DownloadException catch (e) {
    var result = output.output;
    Expect.isTrue(result.indexOf('Failed') > 0);
    Expect.isTrue(result.indexOf('Retrying in 0 seconds') > 0);
    Expect.equals(-1, result.indexOf('DONE'));

    await server.close();
    await server.done;
    await(dir.delete(recursive: true));
    return;
  }
  Expect.fail("Only DownloadException is valid");
}
