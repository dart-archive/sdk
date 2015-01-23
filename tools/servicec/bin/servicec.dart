// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:servicec/compiler.dart' as servicec;
import 'package:args/args.dart';

main(List<String> arguments) {
  ArgParser parser = new ArgParser();
  ArgResults results = parser.parse(arguments);
  for (String path in results.rest) {
    servicec.compile(path);
  }
}
