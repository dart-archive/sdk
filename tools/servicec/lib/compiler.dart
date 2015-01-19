// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'src/parser.dart';
import 'src/pretty_printer.dart';

const String INPUT = """
service EchoService {
  Echo(Int32): Int32;
  Gecho(UInt16): Text;
}
""";

compile() {
  Unit unit = parseUnit(INPUT);
  PrettyPrinter printer = new PrettyPrinter()
      ..visit(unit);
  print(printer.buffer);
}

