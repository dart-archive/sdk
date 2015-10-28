// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../../pkg/mdns/test/decode_test.dart' as decode;
import '../../pkg/mdns/test/lookup_resolver_test.dart' as lookup_resolver;

Future<Null> main() async {
  decode.main();
  lookup_resolver.main();
}
