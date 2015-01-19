// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.io;

class Errno {
  static const EOK = const Errno(0, "EOK");
  static const EINTR = const Errno(4, "EINTR");
  static const EEXIST = const Errno(17, "EEXIST");
  static const EINVAL = const Errno(22, "EINVAL");
  static const EAGAIN = const Errno(115, "EAGAIN");

  final int value;
  final String name;

  const Errno(this.value, this.name);

  String toString() => name;

  static Errno from(int value) {
    switch (value) {
      case EOK.value: return EOK;
      case EINTR.value: return EINTR;
      case EEXIST.value: return EEXIST;
      case EINVAL.value: return EINVAL;
      case EAGAIN.value: return EAGAIN;

      default:
        throw "Unknown errno: $value";
    }
  }
}
