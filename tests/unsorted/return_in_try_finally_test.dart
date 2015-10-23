// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

ret() {
  try {
    return;
  } finally {
  }
}

retNull() {
  try {
    return null;
  } finally {
  }
}

ret42() {
  try {
    return;
  } finally {
    return 42;
  }
}

ret87() {
  try {
    return null;
  } finally {
    return 87;
  }
}

main() {
  Expect.isNull(ret());
  Expect.isNull(retNull());
  Expect.equals(42, ret42());
  Expect.equals(87, ret87());
}
