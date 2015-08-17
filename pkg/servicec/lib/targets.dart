// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.targets;

// Using pre-Dart 1.8 enums, to allow masking.
class Target {
  static const JAVA = const Target._(1);
  static const CC   = const Target._(2);
  static const ALL  = const Target._(3);

  static get values => [JAVA, CC, ALL];

  final int value;

  const Target._(this.value);

  bool includes(Target t) {
    return value & t.value > 0;
  }
}
