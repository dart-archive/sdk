// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'buildbot_service.dart';
import 'console_node.dart';
import 'package:service/struct.dart';

abstract class ConsolePresenterBase {
  // Construct a "presentation graph" from the model.
  ConsoleNode present();

  // Refresh a "presentation graph" from a given "previous" state.
  ConsoleNode refresh(ConsoleNode previous, ConsolePatchDataBuilder builder) {
    ConsoleNode graph = present();
    ConsolePatch patch = graph.diff(previous);
    patch.serialize(builder);
    return graph;
  }
}
