// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library immi;

import 'package:service/struct.dart';

// TODO(zerny): Can we find a way to depend on the generated builder hierarchy
// so we can use the actual builder types below? Otherwise, remove the commented
// builder types.

abstract class Node {
  bool diff(Node previous, List<int> path, List<Patch> patches);
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

abstract class Patch {
  final List<int> path;
  Patch(path) : this.path = path.toList();
  void serialize(/*PatchDataBuilder*/ builder, ResourceManager manager) {
    int length = path.length;
    List pathBuilder = builder.initPath(length);
    for (int i = 0; i < length; ++i) {
      pathBuilder[i] = path[i];
    }
  }
}

class PrimitivePatch extends Patch {
  final String type;
  final current;
  final previous;
  PrimitivePatch(this.type, this.current, this.previous, path) : super(path);
  void serialize(/*PatchDataBuilder*/ builder, ResourceManager manager) {
    super.serialize(builder, manager);
    /*PrimitiveDataBuilder*/ var dataBuilder =
        builder.initContent().initPrimitive();
    switch (type) {
      case 'bool': dataBuilder.boolData = current; break;
      case 'uint8': dataBuilder.uint8Data = current; break;
      case 'uint16': dataBuilder.uint16Data = current; break;
      case 'uint32': dataBuilder.uint32Data = current; break;
      case 'uint64': dataBuilder.uint64Data = current; break;
      case 'int8': dataBuilder.int8Data = current; break;
      case 'int16': dataBuilder.int16Data = current; break;
      case 'int32': dataBuilder.int32Data = current; break;
      case 'int64': dataBuilder.int64Data = current; break;
      case 'float32': dataBuilder.float32Data = current; break;
      case 'float64': dataBuilder.float64Data = current; break;
      case 'String': dataBuilder.StringData = current; break;
      default: throw 'Invalid primitive data type';
    }
  }
}

class MethodPatch extends Patch {
  final Function current;
  final Function previous;
  MethodPatch(this.current, this.previous, path) : super(path);
  void serialize(/*PatchDataBuilder*/ builder, ResourceManager manager) {
    super.serialize(builder, manager);
    manager.removeHandler(previous);
    int id = manager.addHandler(current);
    /*PrimitiveDataBuilder*/ var dataBuilder =
        builder.initContent().initPrimitive();
    dataBuilder.uint16Data = id;
  }
}

class NodePatch extends Patch {
  final Node current;
  final Node previous;
  NodePatch(this.current, this.previous, path) : super(path);
  void serialize(/*PatchDataBuilder*/ builder, ResourceManager manager) {
    if (previous != null) previous.unregisterHandlers(manager);
    super.serialize(builder, manager);
    current.serializeNode(builder.initContent().initNode(), manager);
  }
}

abstract class ListPatch extends Patch {
  final int index;
  ListPatch(this.index, path) : super(path);
  void serialize(/*PatchDataBuilder*/ builder, ResourceManager manager) {
    super.serialize(builder, manager);
    /*ListPatchDataBuilder*/ var listPatch = builder.initListPatch();
    listPatch.index = index;
    serializeListPatch(listPatch, manager);
  }
  void serializeListPatch(/*ListPatchDataBuilder*/ builder,
                          ResourceManager manager);
}

class ListInsertPatch extends ListPatch {
  final int length;
  final List current;
  ListInsertPatch(int index, this.length, this.current, path)
      : super(index, path);
  void serializeListPatch(/*ListPatchDataBuilder*/ builder,
                          ResourceManager manager) {
    List/*<ContentDataBuilder*/ builders = builder.initInsert(length);
    for (int i = 0; i < length; ++i) {
      // TODO(zerny): Abstract seralization of values to support non-nodes.
      current[index + i].serializeNode(builders[i].initNode(), manager);
    }
  }
}

class ListRemovePatch extends ListPatch {
  final int length;
  final List previous;
  ListRemovePatch(int index, this.length, this.previous, path)
      : super(index, path);
  void serializeListPatch(/*ListPatchDataBuilder*/ builder,
                          ResourceManager manager) {
    for (int i = 0; i < length; ++i) {
      previous[index + i].unregisterHandlers(manager);
    }
    builder.remove = length;
  }
}

class ListUpdatePatch extends ListPatch {
  final List updates;
  ListUpdatePatch(int index, this.updates, path)
      : super(index, path);
  void serializeListPatch(/*ListPatchDataBuilder*/ builder,
                          ResourceManager manager) {
    int length = updates.length;
    List patchSetBuilders = builder.initUpdate(length);
    for (int i = 0; i < length; ++i) {
      List patches = updates[i];
      int patchesLength = patches.length;
      List patchBuilders = patchSetBuilders[i].initPatches(patchesLength);
      for (int j = 0; j < patchesLength; ++j) {
        patches[j].serialize(patchBuilders[j], manager);
      }
    }
  }
}

bool diffList(List current, List previous, List path, List patches) {
  int currentLength = current.length;
  int previousLength = previous.length;
  if (currentLength == 0 && previousLength == 0) {
    return false;
  }
  if (previousLength == 0) {
    patches.add(new ListInsertPatch(0, currentLength, current, path));
    return true;
  }
  if (currentLength == 0) {
    patches.add(new ListRemovePatch(0, previousLength, previous, path));
    return true;
  }

  // TODO(zerny): be more clever about diffing a list.
  int patchesLength = patches.length;
  int minLength =
      (currentLength < previousLength) ? currentLength : previousLength;
  int regionStart = -1;
  List regionPatches = [];
  List regionPath = [];
  List memberPatches = [];
  for (int i = 0; i < minLength; ++i) {
    assert(regionPath.isEmpty);
    assert(memberPatches.isEmpty);
    if (current[i].diff(previous[i], regionPath, memberPatches)) {
      regionPatches.add(memberPatches);
      memberPatches = [];
      if (regionStart < 0) regionStart = i;
    } else if (regionStart >= 0) {
      patches.add(new ListUpdatePatch(regionStart, regionPatches, path));
      regionStart = -1;
      regionPatches = [];
    }
  }
  if (regionStart >= 0) {
    patches.add(new ListUpdatePatch(regionStart, regionPatches, path));
  }

  if (currentLength > previousLength) {
    patches.add(new ListInsertPatch(
        previousLength, currentLength - previousLength, current, path));
  } else if (currentLength < previousLength) {
    patches.add(new ListRemovePatch(
        currentLength, previousLength - currentLength, previous, path));
  }

  return patches.length > patchesLength;
}
