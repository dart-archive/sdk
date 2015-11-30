// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Fletch utility package.
///
/// This is a preliminary API.
library fletch;

import 'dart:fletch.ffi';
import 'package:ffi/ffi.dart';

final ForeignFunction _getVersion = ForeignLibrary.main.lookup('GetVersion');

String version() => cStringToString(_getVersion.pcall$0());
