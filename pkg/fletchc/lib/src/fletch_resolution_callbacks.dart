// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_resolution_callbacks;

import 'package:compiler/src/dart2jslib.dart' show
    ResolutionCallbacks;

import 'fletch_context.dart' show
    FletchContext;

class FletchResolutionCallbacks extends ResolutionCallbacks {
  final FletchContext context;

  FletchResolutionCallbacks(this.context);
}
