// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

void serializeString(String string, StrDataBuilder builder) {
  int length = string.length;
  List<int> chars = builder.initChars(length);
  for (int i = 0; i < length; ++i) {
    chars[i] = string.codeUnitAt(i);
  }
}

abstract class ListPatch {
  void serialize(builder);
}

class ListReplacePatch {
  List nodes;
  ListReplacePatch(this.nodes);

  void serialize(builder) {
    int length = nodes.length;
    List builders = builder.initReplace(length);
    for (int i = 0; i < length; ++i) {
      nodes[i].serialize(builders[i]);
    }
  }
}
