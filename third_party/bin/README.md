<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

fletch_driver requires Unix domain sockets which aren't part of Dart yet, so we
maintain a custom build of the Dart VM. As of Apr 9, 2015 Unix domain sockets
are planned for some release of Dart *after* 1.10.

How to build the dart binary:

In a normal Dart checkout, run:

  gclient sync -r all.deps@44800 -t

Then patch in https://codereview.chromium.org/1061283003.

Then run:

  ./tools/build.py -mrelease -aia32 runtime

Then strip the binary, on Linux use "strip", on Mac use "strip -x".
