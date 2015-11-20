// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import '../../pkg/flash_sd_card/test/image_download_test.dart'
    as image_download;

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  tests['flash_sd_card_tests/image_download'] = image_download.main;
  return tests;
}
