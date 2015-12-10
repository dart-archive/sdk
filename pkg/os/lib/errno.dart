// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

final Errnos errnos = _getErrnos();

Errnos _getErrnos() {
  switch (Foreign.platform) {
    case Foreign.ANDROID:
    case Foreign.LINUX:
      return new _LinuxErrnos();
    case Foreign.MACOS:
      return new _MacOSErrnos();
    default:
      throw "Unsupported system ${Foreign.platform}";
  }
}

abstract class Errnos {
  int get EPERM;
  int get ENOENT;
  int get ESRCH;
  int get EINTR;
  int get EIO;
  int get ENXIO;
  int get E2BIG;
  int get ENOEXEC;
  int get EBADF;
  int get ECHILD;
  int get EAGAIN;
  int get ENOMEM;
  int get EACCES;
  int get EFAULT;
  int get ENOTBLK;
  int get EBUSY;
  int get EEXIST;
  int get EXDEV;
  int get ENODEV;
  int get ENOTDIR;
  int get EISDIR;
  int get EINVAL;
  int get ENFILE;
  int get EMFILE;
  int get ENOTTY;
  int get ETXTBSY;
  int get EFBIG;
  int get ENOSPC;
  int get ESPIPE;
  int get EROFS;
  int get EMLINK;
  int get EPIPE;
  int get EDOM;
  int get ERANGE;

  int get EADDRNOTAVAIL;
  int get EINPROGRESS;

  String errnoToString(int errno) => sys.strerror(errno);
}

abstract class _PosixErrnos extends Errnos {
  int get EPERM => 1;
  int get ENOENT => 2;
  int get ESRCH => 3;
  int get EINTR => 4;
  int get EIO => 5;
  int get ENXIO => 6;
  int get E2BIG => 7;
  int get ENOEXEC => 8;
  int get EBADF => 9;
  int get ECHILD => 10;
  int get EAGAIN => 11;
  int get ENOMEM => 12;
  int get EACCES => 13;
  int get EFAULT => 14;
  int get ENOTBLK => 15;
  int get EBUSY => 16;
  int get EEXIST => 17;
  int get EXDEV => 18;
  int get ENODEV => 19;
  int get ENOTDIR => 20;
  int get EISDIR => 21;
  int get EINVAL => 22;
  int get ENFILE => 23;
  int get EMFILE => 24;
  int get ENOTTY => 25;
  int get ETXTBSY => 26;
  int get EFBIG => 27;
  int get ENOSPC => 28;
  int get ESPIPE => 29;
  int get EROFS => 30;
  int get EMLINK => 31;
  int get EPIPE => 32;
  int get EDOM => 33;
  int get ERANGE => 34;
}

class _LinuxErrnos extends _PosixErrnos {
  int get EADDRNOTAVAIL => 99;
  int get EINPROGRESS => 115;
}

class _MacOSErrnos extends _PosixErrnos {
  int get EADDRNOTAVAIL => 49;
  int get EINPROGRESS => 36;
}
