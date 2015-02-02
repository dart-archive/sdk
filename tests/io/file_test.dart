// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'dart:typed_data';

import 'package:expect/expect.dart';

void main() {
  testOpen();
}

bool isFileException(e) => e is FileException;

void testOpen() {
  final String path = '/tmp/__fletch_dart_io_non_exist_file__';
  var file = new File(path);
  Expect.isFalse(file.isOpen);
  Expect.isFalse(file.exists);
  Expect.equals(path, file.path);
  Expect.throws(file.open, isFileException);

  file = new File.temporary("/tmp/file_test");
  Expect.isTrue(file.isOpen);
  Expect.isTrue(file.exists);
  file.close();
  Expect.isFalse(file.isOpen);
  file.remove();
  Expect.isFalse(file.exists);
}
