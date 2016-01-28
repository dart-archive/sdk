// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:github_sample/src/github_mock.dart';
import 'package:github_sample/src/github_mock_data.dart';

main() {
  var mock = new GithubMock('127.0.0.1', 8321);
  mock.dataStorage = new ByteMapDataStorage();
  mock.verbose = true;
  mock.run();
}
