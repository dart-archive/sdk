// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data';

import 'github_mock.dart' show DataStorage;
import 'github_mock.data' as data;

class ByteMapDataStorage implements DataStorage {
  ByteBuffer readResponseFile(String resource) {
    List<int> bytes = data.resources[resource];
    return (bytes != null) ? new Uint8List.fromList(bytes).buffer : null;
  }
}
