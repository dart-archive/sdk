// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// The dart:fletch.service library is a low-level communication library that
// allows dart code to register services that are accessible through
// the C API.
library dart.fletch.service;

import 'dart:fletch._system' as fletch;
import 'dart:fletch';

// TODO(ajohnsen): Rename file.

@fletch.native void register(String service, Port servicePort) {
  throw new UnsupportedError("Was not able to register service '$service'");
}
