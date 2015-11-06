// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart' show
    Expect;

main() {
  Expect.notEquals("/", Uri.base.toFilePath());
  // Work around https://github.com/dart-lang/sdk/issues/24837
  Expect.notEquals("//", Uri.base.toFilePath());
}
