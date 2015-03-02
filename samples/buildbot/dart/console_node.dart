// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'presentation_utils.dart';

class ConsoleNode {
  String title;
  String status;
  ConsoleNode(this.title, this.status);

  // TODO(zerny): implement actual diff'ing
  List<ConsoleNodePatch> diff(ConsoleNode previous) =>
    [new ConsoleNodePatch(this)];

  void serialize(ConsoleNodeDataBuilder builder) {
    serializeString(title, builder.initTitle());
    serializeString(status, builder.initStatus());
  }
}

class ConsoleNodePatch {
  ConsoleNode node;
  ConsoleNodePatch(this.node);

  void serialize(ConsoleNodePatchDataBuilder builder) {
    node.serialize(builder.initReplace());
  }
}
