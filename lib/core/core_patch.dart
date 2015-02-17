// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

const patch = "patch";

@patch bool identical(Object a, Object b) {
  return false;
}

@patch class Object {
  @patch String toString() => '[Object object]';
}
