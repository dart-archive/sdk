// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library immi;

import 'package:service/struct.dart';

// TODO(zerny): Can we find a way to depend on the generated builder hierarchy
// so we can use the actual builder types below? Otherwise, remove the commented
// builder types.

abstract class Node {
  diff(Node previous);
  void serializeNode(/*NodeData*/Builder builder, ResourceManager manager);
  void unregisterHandlers(ResourceManager manager);
}

class ResourceManager {
  int _nextEventID = 1;
  Map<int, Function> _eventHandlers = {};
  Map<Function, int> _eventHandlersInverted = {};
  void clear() {
    _eventHandlers.clear();
    _eventHandlersInverted.clear();
  }
  int addHandler(Function handler) {
    if (handler == null) return 0;
    _eventHandlers[_nextEventID] = handler;
    _eventHandlersInverted[handler] = _nextEventID;
    return _nextEventID++;
  }
  void removeHandler(Function handler) {
    if (handler == null) return;
    int id = _eventHandlersInverted.remove(handler);
    if (id == null) return;
    _eventHandlers.remove(id);
  }
  Function getHandler(int id) {
    if (id == 0) {
      print('Request with invalid event id: 0');
      return null;
    }
    Function handler = _eventHandlers[id];
    if (handler == null) {
      print('Request with unallocated event id: \$id');
      return null;
    }
    return handler;
  }
}

abstract class NodePatch {
  void serializeNode(/*NodePatchData*/Builder builder, ResourceManager manager);
}

class ListPatch {
  final List<ListRegionPatch> regions;
  ListPatch(this.regions);
  void serializeList(/*ListPatchDataBuilder*/ builder,
                     ResourceManager manager) {
    int length = regions.length;
    List</*ListRegionData*/Builder> builders = builder.initRegions(length);
    for (int i = 0; i < length; ++i) {
      ListRegionPatch region = regions[i];
      /*ListRegionDataBuilder*/var regionBuilder = builders[i];
      regionBuilder.index = region.index;
      region.serializeRegion(regionBuilder, manager);
    }
  }
}

abstract class ListRegionPatch {
  final int index;
  ListRegionPatch(this.index);
  void serializeRegion(/*ListRegionData*/Builder builder,
                       ResourceManager manager);
}

class ListInsertPatch extends ListRegionPatch {
  final int length;
  final List current;
  ListInsertPatch(int index, this.length, this.current) : super(index);
  void serializeRegion(/*ListRegionDataBuilder*/ builder,
                       ResourceManager manager) {
    List</*NodeData*/Builder> builders = builder.initInsert(length);
    for (int i = 0; i < length; ++i) {
      current[index + i].serializeNode(builders[i], manager);
    }
  }
}

class ListRemovePatch extends ListRegionPatch {
  final int length;
  final List previous;
  ListRemovePatch(int index, this.length, this.previous) : super(index);
  void serializeRegion(/*ListRegionDataBuilder*/ builder,
                       ResourceManager manager) {
    builder.remove = length;
    for (int i = 0; i < length; ++i) {
      previous[index + i].unregisterHandlers(manager);
    }
  }
}

class ListUpdatePatch extends ListRegionPatch {
  final List updates;
  ListUpdatePatch(int index, this.updates) : super(index);
  void serializeRegion(/*ListRegionDataBuilder*/ builder,
                       ResourceManager manager) {
    int length = updates.length;
    List</*NodePatchData*/Builder> builders = builder.initUpdate(length);
    for (int i = 0; i < length; ++i) {
      updates[i].serializeNode(builders[i], manager);
    }
  }
}

ListPatch diffList(List current, List previous) {
  int currentLength = current.length;
  int previousLength = previous.length;
  if (currentLength == 0 && previousLength == 0) {
    return null;
  }
  if (previousLength == 0) {
    return new ListPatch([new ListInsertPatch(0, currentLength, current)]);
  }
  if (currentLength == 0) {
    return new ListPatch([new ListRemovePatch(0, previousLength, previous)]);
  }

  // TODO(zerny): be more clever about diffing a list.
  int minLength =
      (currentLength < previousLength) ? currentLength : previousLength;

  List patches = [];

  int regionStart = -1;
  List regionPatches;

  for (int i = 0; i < minLength; ++i) {
    // TODO(zerny): Support lists of primitives and lists of Node.
    var patch = current[i].diff(previous[i]);
    if (patch != null) {
      if (regionStart < 0) {
        regionStart = i;
        regionPatches = [];
      }
      regionPatches.add(patch);
    } else if (regionStart >= 0) {
      patches.add(new ListUpdatePatch(regionStart, regionPatches));
      regionStart = -1;
    }
  }
  if (regionStart >= 0) {
    patches.add(new ListUpdatePatch(regionStart, regionPatches));
  }

  if (currentLength > previousLength) {
    patches.add(new ListInsertPatch(
        previousLength, currentLength - previousLength, current));
  } else if (currentLength < previousLength) {
    patches.add(new ListRemovePatch(
        currentLength, previousLength - currentLength, previous));
  }

  return patches.isEmpty ? null : new ListPatch(patches);
}
