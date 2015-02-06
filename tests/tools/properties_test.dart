// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';
import '../../src/tools/driver/properties.dart' as props;

main() {
  String path = "p";
  String name = "n";
  String value = "v";

  props.useMemoryBackedProperties();

  Expect.isNull(props.getProperty(path, name));
  props.setProperty(path, name, value);
  Expect.equals(value, props.getProperty(path, name));

  Expect.isNull(props.getProperty(path, "unknown_name"));
}
