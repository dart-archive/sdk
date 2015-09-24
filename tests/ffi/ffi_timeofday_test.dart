// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.ffi';

import "package:expect/expect.dart";
import 'package:os/os.dart' as os;

abstract class Timeval implements ForeignMemory {
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

class Timeval32 extends ForeignMemory implements Timeval {
  Timeval32() : super.allocated(8);
  int get tv_sec => getInt32(0);
  int get tv_usec => getInt32(4);
}

class Timeval64 extends ForeignMemory implements Timeval {
  Timeval64() : super.allocated(16);
  int get tv_sec => getInt64(0);
  int get tv_usec => getInt64(8);
}

final ForeignFunction gettimeofday = ForeignLibrary.main.lookup('gettimeofday');

main() {
  Timeval timeval = new Timeval();
  Expect.equals(0, gettimeofday.icall$2(timeval, 0));
  int start = timeval.tv_sec * 1000 + timeval.tv_usec ~/ 1000;

  int sleepTime = 300;
  os.sleep(sleepTime);

  Expect.equals(0, gettimeofday.icall$2(timeval, 0));
  int end = timeval.tv_sec * 1000 + timeval.tv_usec ~/ 1000;
  Expect.isTrue((end - start) >= sleepTime);
  timeval.free();
}
