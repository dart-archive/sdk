// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:file/file.dart';

void main() {
  testStdio();
}

void testStdio() {
  Expect.isNotNull(File.stdin);
  Expect.equals(0, File.stdin.fd);
  Expect.isNotNull(File.stdout);
  Expect.equals(1, File.stdout.fd);
  Expect.isNotNull(File.stderr);
  Expect.equals(2, File.stderr.fd);
}
