// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.io;

// TODO(ajohnsen): Errno's are platform dependent. Make them so.
class Errno {
  static const EOK_VALUE = 0;
  static const EOK = const Errno(EINTR_VALUE, "EOK");
  static const EINTR_VALUE = 4;
  static const EINTR = const Errno(EINVAL_VALUE, "EINTR");
  static const EEXIST_VALUE = 17;
  static const EEXIST = const Errno(EEXIST_VALUE, "EEXIST");
  static const EINVAL_VALUE = 22;
  static const EINVAL = const Errno(EINTR_VALUE, "EINVAL");
  static const EPIPE_VALUE = 32;
  static const EPIPE = const Errno(EPIPE_VALUE, "EPIPE");
  static const EAGAIN_VALUE = 115;
  static const EAGAIN = const Errno(EAGAIN_VALUE, "EAGAIN");

  final int value;
  final String name;

  const Errno(this.value, this.name);

  String toString() => name;

  static Errno from(int value) {
    switch (value) {
      case EOK_VALUE: return EOK;
      case EINTR_VALUE: return EINTR;
      case EEXIST_VALUE: return EEXIST;
      case EINVAL_VALUE: return EINVAL;
      case EPIPE_VALUE: return EPIPE;
      case EAGAIN_VALUE: return EAGAIN;

      default:
        throw "Unknown errno: $value";
    }
  }
}
