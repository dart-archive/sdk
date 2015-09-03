// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import fletch.ListPatchData;
import fletch.ListRegionData;
import fletch.ListRegionDataList;
import fletch.NodeDataList;
import fletch.NodePatchDataList;

public final class ListPatch<N extends Node> implements Patch {

  // Public interface.

  @Override
  public boolean hasChanged() { return changed; }

  public List<N> getCurrent() { return current; }
  public List<N> getPrevious() { return previous; }

  public static abstract class RegionPatch {
    public int getIndex() { return index; }

    RegionPatch(int index) {
      this.index = index;
    }

    static RegionPatch fromData(
        ListRegionData data,
        Type type,
        List<Node> previous,
        ImmiRoot root) {
      if (data.isRemove()) return new RemovePatch(data);
      if (data.isInsert()) return new InsertPatch(data, type, root);
      assert data.isUpdate();
      return new UpdatePatch(data, type, previous, root);
    }

    // Returns the change in size resulting from this region patch.
    abstract int delta();

    // Applies a region patch to the output list and returns the index increment
    // of the input list.
    abstract int apply(List<Node> output);

    private int index;
  }

  public static class RemovePatch extends RegionPatch {
    public int getCount() { return count; }

    int delta() { return -count; }

    int apply(List<Node> output) { return count; }

    private RemovePatch(ListRegionData data) {
      super(data.getIndex());
      count = data.getRemove();
    }

    private int count;
  }

  public static class InsertPatch extends RegionPatch {

    int delta() { return nodes.size(); }

    int apply(List<Node> output) {
      output.addAll(nodes);
      return 0;
    }

    private InsertPatch(ListRegionData data, Type type, ImmiRoot root) {
      super(data.getIndex());
      NodeDataList insertData = data.getInsert();
      int length = insertData.size();
      List<Node> mutableNodes = new ArrayList<Node>(length);
      if (type == Type.ANY_NODE) {
        for (int i = 0; i < length; ++i) {
          mutableNodes.add(new AnyNode(insertData.get(i), root));
        }
      } else {
        assert type == Type.SPECIFIC_NODE;
        for (int i = 0; i < length; ++i) {
          mutableNodes.add(AnyNode.fromData(insertData.get(i), root));
        }
      }
      nodes = Collections.unmodifiableList(mutableNodes);
    }

    private List<Node> nodes;
  }

  public static class UpdatePatch extends RegionPatch {

    int delta() { return 0; }

    int apply(List<Node> output) {
      int length = updates.size();
      for (int i = 0; i < length; ++i) {
        output.add(updates.get(i).getCurrent());
      }
      return length;
    }

    private UpdatePatch(
        ListRegionData data,
        Type type,
        List<Node> previous,
        ImmiRoot root) {
      super(data.getIndex());
      NodePatchDataList updateData = data.getUpdate();
      int length = updateData.size();
      List<NodePatch> mutableUpdates = new ArrayList<NodePatch>(length);
      if (type == Type.ANY_NODE) {
        for (int i = 0; i < length; ++i) {
          mutableUpdates.add(new AnyNodePatch(
              updateData.get(i), (AnyNode)previous.get(getIndex() + i), root));
        }
      } else {
        assert type == Type.SPECIFIC_NODE;
        for (int i = 0; i < length; ++i) {
          mutableUpdates.add(AnyNodePatch.fromData(
              updateData.get(i), previous.get(getIndex() + i), root));
        }
      }
      updates = Collections.unmodifiableList(mutableUpdates);
    }

    private List<NodePatch> updates;
  }

  // Package private implementation.

  ListPatch(List<N> previous) {
    changed = false;
    this.previous = previous;
    current = previous;
  }

  ListPatch(ListPatchData data, List<N> previous, ImmiRoot root) {
    changed = true;
    this.previous = previous;
    Type type = Type.fromInt(data.getType());
    ListRegionDataList regions = data.getRegions();
    List<RegionPatch> patches = new ArrayList<RegionPatch>(regions.size());
    for (int i = 0; i < regions.size(); ++i) {
      // TODO(zerny): Separate ListPatch<AnyNode> from ListPatch<Node> and avoid
      // dynamic casts.
      patches.add(RegionPatch.fromData(
          regions.get(i), type, (List<Node>)previous, root));
    }
    this.regions = patches;
    this.current = applyWith(previous);
  }

  List<N> applyWith(List<N> previous) {
    int newSize = previous.size();
    for (int i = 0; i < regions.size(); ++i) {
      newSize += regions.get(i).delta();
    }
    int sourceIndex = 0;
    List<N> newArray = new ArrayList<N>(newSize);
    for (int i = 0; i < regions.size(); ++i) {
      RegionPatch patch = regions.get(i);
      while (sourceIndex < patch.index) {
        newArray.add(previous.get(sourceIndex++));
      }
      // TODO(zerny): Separate ListPatch<AnyNode> from ListPatch<Node> and avoid
      // dynamic casts.
      sourceIndex += patch.apply((List<Node>)newArray);
    }
    while (sourceIndex < previous.size()) {
      newArray.add(previous.get(sourceIndex++));
    }
    return Collections.unmodifiableList(newArray);
  }

  private enum Type {
    ANY_NODE, SPECIFIC_NODE;

    public static Type fromInt(int tag) {
      return tag == 0 ? ANY_NODE : SPECIFIC_NODE;
    }
  }

  private boolean changed;
  private List<N> previous;
  private List<N> current;
  private List<RegionPatch> regions;
}
