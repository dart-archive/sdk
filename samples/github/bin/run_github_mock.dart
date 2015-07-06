// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:github_sample/src/github_mock.dart';

main() {
  var mock = new GithubMock.invertedForTesting(8321);
  mock.verbose = true;
  mock.run();
}
