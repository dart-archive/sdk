// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.emitter;

import 'dart:io';

import 'package:path/path.dart' show basenameWithoutExtension, join;

void writeToFile(String outputDirectory,
                 String path,
                 String extension,
                 String contents) {
  // Create 'cc' output directory if it doesn't already exist.
  new Directory(outputDirectory).createSync();
  // Write contents of the file.
  String base = basenameWithoutExtension(path);
  String headerFile = '$base.$extension';
  String headerFilePath = join(outputDirectory, headerFile);
  new File(headerFilePath).writeAsStringSync(contents);
}

