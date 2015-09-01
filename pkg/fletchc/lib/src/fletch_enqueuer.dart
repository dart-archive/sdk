// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_enqueuer;

import 'package:compiler/src/dart2jslib.dart' show
    EnqueueTask;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

/// Custom enqueuer for Fletch.
class FletchEnqueueTask extends EnqueueTask {
  // TODO(ahe): Change to implementing [EnqueueTask] and store a custom
  // enqueuer in this class' [codegen] property.

  FletchEnqueueTask(FletchCompilerImplementation compiler)
      : super(compiler);
}
