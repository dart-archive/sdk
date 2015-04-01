// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import '../trace.dart';

ListPatch diffList(List current, List previous) {
  int currentLength = current.length;
  int previousLength = previous.length;
  assert(trace("diffList (cur ${currentLength}, prev ${previousLength})"));
  if (currentLength == 0 && previousLength == 0) return null;

  // TODO(zerny): be more clever about diffing a list.
  int minLength =
      (currentLength < previousLength) ? currentLength : previousLength;
  List patches = [];
  int start = -1;
  List elementPatches;
  for (int i = 0; i < minLength; ++i) {
    var diff = current[i].diff(previous[i]);
    if (diff != null) {
      if (start < 0) {
        start = i;
        elementPatches = new List();
      }
      elementPatches.add(diff);
    } else if (start >= 0) {
      patches.add(new ListPatchPatch(start, elementPatches));
      start = -1;
    }
  }
  if (start >= 0) {
    patches.add(new ListPatchPatch(start, elementPatches));
  }

  if (currentLength > previousLength) {
    int start = previousLength;
    int count = currentLength - previousLength;
    patches.add(new ListInsertPatch(start, current.sublist(start, count)));
  } else if (currentLength < previousLength) {
    int start = currentLength;
    int count = previousLength - currentLength;
    patches.add(new ListRemovePatch(start, count));
  }

  return (patches.length > 0) ? new ListPatch(patches) : null;
}

class ListPatch {
  final List<ListUpdatePatch> updates;
  ListPatch(this.updates);

  void serialize(Builder builder) {
    int length = updates.length;
    assert(trace("ListPatch::serialize ($length)"));
    List<Builder> builders = builder.initUpdates(length);
    for (var i = 0; i < length; ++i) {
      updates[i].serialize(builders[i]);
    }
  }
}

abstract class ListUpdatePatch {
  void serialize(Builder builder);
}

class ListRemovePatch extends ListUpdatePatch {
  final int index;
  final int count;
  ListRemovePatch(this.index, this.count);

  void serialize(Builder builder) {
    assert(trace("ListRemovePatch::serialize"));
    builder.index = index;
    builder.remove = count;
  }
}

class ListInsertPatch extends ListUpdatePatch {
  final int index;
  final List nodes;
  ListInsertPatch(this.index, this.nodes);

  void serialize(Builder builder) {
    assert(trace("ListInsertPatch::serialize"));
    builder.index = index;
    int length = nodes.length;
    List<Builders> builders = builder.initInsert(length);
    for (var i = 0; i < length; ++i) {
      nodes[i].serialize(builders[i]);
    }
  }
}

class ListPatchPatch extends ListUpdatePatch {
  final int index;
  final List patches;
  ListPatchPatch(this.index, this.patches);

  void serialize(Builder builder) {
    assert(trace("ListPatchPatch::serialize"));
    builder.index = index;
    int length = patches.length;
    List<Builders> builders = builder.initPatch(length);
    for (var i = 0; i < length; ++i) {
      patches[i].serialize(builders[i]);
    }
  }
}
