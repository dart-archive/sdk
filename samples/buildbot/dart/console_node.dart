// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'presentation_utils.dart';

class ConsoleNode {
  String title;
  String status;
  ConsoleNode(this.title, this.status);

  List<ConsoleNodePatch> diff(ConsoleNode previous) {
    List<ConsoleNodePatch> patches = new List();
    diffAt(previous, patches);
    return patches;
  }

  void diffAt(ConsoleNode previous,
              List<ConsoleNodePatch> patches) {
    if (previous == null || previous is! ConsoleNode) {
      patches.add(new ConsoleNodeReplacePatch(this));
      return;
    }
    if (this.title != previous.title) {
      patches.add(new ConsoleNodeTitlePatch(this.title));
    }
    if (this.status != previous.status) {
      patches.add(new ConsoleNodeStatusPatch(this.status));
    }
  }

  void serialize(ConsoleNodeDataBuilder builder) {
    serializeString(title, builder.initTitle());
    serializeString(status, builder.initStatus());
  }
}

abstract class ConsoleNodePatch {
  void serialize(ConsoleNodePatchDataBuilder builder);
}

class ConsoleNodeReplacePatch extends ConsoleNodePatch {
  ConsoleNode node;
  ConsoleNodeReplacePatch(this.node);

  void serialize(ConsoleNodePatchDataBuilder builder) {
    node.serialize(builder.initReplace());
  }
}

class ConsoleNodeTitlePatch extends ConsoleNodePatch {
  String title;
  ConsoleNodeTitlePatch(this.title);

  void serialize(ConsoleNodePatchDataBuilder builder) {
    serializeString(title, builder.initTitle());
  }
}

class ConsoleNodeStatusPatch extends ConsoleNodePatch {
  String status;
  ConsoleNodeStatusPatch(this.status);

  void serialize(ConsoleNodePatchDataBuilder builder) {
    serializeString(status, builder.initStatus());
  }
}
