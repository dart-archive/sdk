// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.io';
import 'dart:typed_data';

import 'package:expect/expect.dart';

void main() {
  testOpen();
  testReadWrite();
  testSeek();
}

bool isFileException(e) => e is FileException;

void testOpen() {
  String path = '/tmp/__fletch_dart_io_non_exist_file__';
  Expect.throws(() => new File.open(path), isFileException);
  var file = new File.temporary("/tmp/file_test");
  Expect.isTrue(file.isOpen);
  Expect.isTrue(File.existsAsFile(file.path));
  file.close();
  Expect.isFalse(file.isOpen);
  File.delete(file.path);
  Expect.isFalse(File.existsAsFile(file.path));
}

void testReadWrite() {
  var file = new File.temporary("/tmp/file_write_test");

  var data = new Uint8List(8);
  for (int i = 0; i < data.length; i++) data[i] = i;
  file.write(data.buffer);
  Expect.equals(8, file.length);

  Expect.equals(8, file.position);
  Expect.equals(0, file.read(16).lengthInBytes);

  file.position = 0;

  var buffer = file.read(16);
  Expect.equals(8, buffer.lengthInBytes);
  var list = new Uint8List.view(buffer);
  for (int i = 0; i < list.length; i++) Expect.equals(i, list[i]);

  Expect.equals(8, file.position);

  file.close();
  Expect.isFalse(file.isOpen);
  File.delete(file.path);
}

void testSeek() {
  var file = new File.temporary("/tmp/file_seek_test");
  Expect.isTrue(file.isOpen);
  Expect.equals(0, file.position);
  Expect.equals(0, file.length);
  file.position = 0;
  Expect.equals(0, file.position);
  file.position = 1;
  Expect.equals(1, file.position);
  Expect.equals(0, file.length);

  file.close();
  File.delete(file.path);
}
