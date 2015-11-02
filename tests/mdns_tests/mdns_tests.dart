// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import '../../pkg/mdns/test/decode_test.dart' as decode;
import '../../pkg/mdns/test/lookup_resolver_test.dart' as lookup_resolver;
import '../../pkg/mdns/test/native_extension_test.dart' as native_extension;

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  tests['mdns_tests/decode'] = () async => decode.main();
  tests['mdns_tests/lookup_resolver'] = () async => lookup_resolver.main();
  tests['mdns_tests/validate_extension'] = native_extension.main;
  return tests;
}
