// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'package:expect/expect.dart';
import 'package:flash_sd_card/src/context.dart';
import 'package:flash_sd_card/src/platform_service.dart';

import 'utils.dart';

main() async {
  await testSuccessfullDownload();
  await testSuccessfullDownloadWithFailures();
  await testFailingDownload();
}

Future testSuccessfullDownload() async {
  Server server = await Server.start();

  TestEnvironment env = new TestEnvironment('image_download_test_1');
  Context ctx = env.ctx;
  var platformService = new PlatformService(ctx);
  await platformService.initialize();

  var tmpFile = await env.createTmpFile('download');
  await platformService.downloadWithProgress(
      Uri.parse('http://127.0.0.1:${server.port}'), tmpFile);
  var output = env.consoleOutput;
  Expect.equals(-1, output.indexOf('Failed'));
  Expect.isTrue(output.indexOf('DONE') > 0);
  Expect.equals(server.successDownloadSize,
                (await tmpFile.readAsBytes()).length);

  await server.done;
  await ctx.done();
  await env.close();
}

Future testSuccessfullDownloadWithFailures() async {
  const failureCount = 5;
  Server server = await Server.start(failureCount: failureCount);

  TestEnvironment env = new TestEnvironment('image_download_test_2');
  Context ctx = env.ctx;
  var platformService = new PlatformService(ctx);
  await platformService.initialize();

  var tmpFile = await env.createTmpFile('download');
  await platformService.downloadWithProgress(
      Uri.parse('http://127.0.0.1:${server.port}'),
      tmpFile,
      retryCount: failureCount + 1,
      retryInterval: const Duration(milliseconds: 10));
  var output = env.consoleOutput;
  Expect.isTrue(output.indexOf('Failed') > 0);
  Expect.isTrue(output.indexOf('Retrying in 0 seconds') > 0);
  Expect.isTrue(output.indexOf('DONE') > 0);
  Expect.equals(server.successDownloadSize,
                (await tmpFile.readAsBytes()).length);

  await server.done;
  await ctx.done();
  await env.close();
}

Future testFailingDownload() async {
  const failureCount = 5;
  Server server = await Server.start(failureCount: failureCount);

  TestEnvironment env = new TestEnvironment('image_download_test_2');
  Context ctx = env.ctx;
  var platformService = new PlatformService(ctx);
  await platformService.initialize();

  var tmpFile = await env.createTmpFile('download');

  try {
    await platformService.downloadWithProgress(
        Uri.parse('http://127.0.0.1:${server.port}'),
        tmpFile,
        retryCount: failureCount - 1,
        retryInterval: const Duration(milliseconds: 10));
    Expect.fail('Unexpected: Download succeeded');
  } on Failure catch (e) {
    var output = env.consoleOutput;
    Expect.isTrue(output.indexOf('Failed') > 0);
    Expect.isTrue(output.indexOf('Retrying in 0 seconds') > 0);
    Expect.equals(-1, output.indexOf('DONE'));

    await server.close();
    await server.done;
    await ctx.done();
    await env.close();
  }
}
