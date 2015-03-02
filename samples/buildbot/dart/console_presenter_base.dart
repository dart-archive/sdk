// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'console_node.dart';
import 'struct.dart';

abstract class ConsolePresenterBase {
  // Construct a "presenter graph" from the model.
  ConsoleNode present();

  // Refresh a "presentation graph" from a given "previous" state.
  ConsoleNode refresh(ConsoleNode previous, ConsolePatchSetBuilder builder) {
    ConsoleNode graph = present();
    List patches = graph.diff(previous);
    int length = patches.length;
    List patchBuilders = builder.initPatches(length);
    for (int i = 0; i < length; ++i) {
      patches[i].serialize(patchBuilders[i]);
    }
    return graph;
  }
}
