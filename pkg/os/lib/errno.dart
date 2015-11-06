// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

class Errno {
  static const EOK_VALUE = 0;
  static const EOK = const Errno(EOK_VALUE, "EOK");
  static const ENOENT_VALUE = 2;
  static const ENOENT = const Errno(ENOENT_VALUE, "ENOENT");
  static const EINTR_VALUE = 4;
  static const EINTR = const Errno(EINTR_VALUE, "EINTR");
  static const EEXIST_VALUE = 17;
  static const EEXIST = const Errno(EEXIST_VALUE, "EEXIST");
  static const EINVAL_VALUE = 22;
  static const EINVAL = const Errno(EINVAL_VALUE, "EINVAL");
  static const EPIPE_VALUE = 32;
  static const EPIPE = const Errno(EPIPE_VALUE, "EPIPE");

  // TODO(wibling): Find a better crossplatform solution for errno.
  static int get EADDRNOTAVAIL_VALUE =>
      Foreign.platform == Foreign.MACOS ? 49 : 99;
  static Errno EADDRNOTAVAIL =
    new Errno(EADDRNOTAVAIL_VALUE, "EADDRNOTAVAIL");
  static int get EINPROGRESS_VALUE =>
      Foreign.platform == Foreign.MACOS ? 36 : 115;
  static Errno EINPROGRESS = new Errno(EINPROGRESS_VALUE, "EINPROGRESS");

  final int value;
  final String name;

  const Errno(this.value, this.name);

  String toString() => name;

  static Errno from(int value) {
    // Handle non-const errno.
    if (value == EADDRNOTAVAIL_VALUE) {
      return EADDRNOTAVAIL;
    } else if (value == EINPROGRESS_VALUE) {
      return EINPROGRESS;
    }
    switch (value) {
      case EOK_VALUE: return EOK;
      case ENOENT_VALUE: return ENOENT;
      case EINTR_VALUE: return EINTR;
      case EEXIST_VALUE: return EEXIST;
      case EINVAL_VALUE: return EINVAL;
      case EPIPE_VALUE: return EPIPE;
      default:
        throw "Unknown errno: $value";
    }
  }
}
