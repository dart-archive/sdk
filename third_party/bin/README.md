<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

How to build the dart binary:

In a normal Dart checkout, run:

  gclient sync -r all.deps@44800 -t

Then patch in https://codereview.chromium.org/1061283003.

Then run:

  ./tools/build.py -mrelease -aia32 runtime

Then strip the binary, on Linux use "strip", on Mac use "strip -x".
