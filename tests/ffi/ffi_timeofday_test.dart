// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:ffi';
import 'dart:io' as io;
import "package:expect/expect.dart";

abstract class Timeval {
  factory Timeval() {
    switch (Foreign.bitsPerMachineWord) {
      case 32: return new Timeval32();
      case 64: return new Timeval64();
      default: throw "Unsupported machine word size.";
    }
  }
  int get tv_sec;
  int get tv_usec;
}

class Timeval32 extends Foreign implements Timeval {
  Timeval32() : super.allocated(8);
  int get tv_sec => getInt32(0);
  int get tv_usec => getInt32(4);
}

class Timeval64 extends Foreign implements Timeval {
  Timeval64() : super.allocated(16);
  int get tv_sec => getInt64(0);
  int get tv_usec => getInt64(8);
}

final Foreign gettimeofday = Foreign.lookup('gettimeofday');

main() {
  Timeval timeval = new Timeval();
  Expect.equals(0, gettimeofday.icall$2(timeval, 0));
  int start = timeval.tv_sec * 1000 + timeval.tv_usec ~/ 1000;

  int sleepTime = 300;
  io.sleep(sleepTime);

  Expect.equals(0, gettimeofday.icall$2(timeval, 0));
  int end = timeval.tv_sec * 1000 + timeval.tv_usec ~/ 1000;
  Expect.isTrue((end - start) >= sleepTime);
  timeval.free();
}
