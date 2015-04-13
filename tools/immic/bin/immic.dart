// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:immic/compiler.dart' as immic;
import 'package:args/args.dart';

main(List<String> arguments) {
  ArgParser parser = new ArgParser();
  parser.addOption('out', defaultsTo: ".");
  ArgResults results = parser.parse(arguments);
  String outputDirectory = results['out'];
  if (!(new Directory(outputDirectory)).existsSync()) {
    print("Output directory '$outputDirectory' does not exist.");
    exit(1);
  }
  if (results.rest.isEmpty) {
    print("No input files.");
    exit(1);
  }
  for (String path in results.rest) {
    immic.compile(path, outputDirectory);
  }
}
