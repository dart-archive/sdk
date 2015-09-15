// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.immisamples;

import android.os.Handler;
import android.os.Looper;
import android.support.v7.widget.RecyclerView;

import immi.AnyNode;
import immi.ListPatch;
import immi.SlidingWindowNode;
import immi.SlidingWindowPatch;
import immi.SlidingWindowPresenter;

public abstract class SlidingWindow<T extends RecyclerView.ViewHolder>
    extends RecyclerView.Adapter<T>
    implements SlidingWindowPresenter {

  /**
   * Implementors must implement this method instead of onBindViewHolder(T, int).
   *
   * @param holder ViewHolder being recycled.
   * @param node Node to use for repopulating the view or null if the data is unavailable.
   */
  public abstract void onBindViewHolder(T holder, AnyNode node);

  // RecyclerVier.Adapter

  @Override
  public final void onBindViewHolder(T holder, int position) {
    assert root != null;
    if (position < windowStart() + bufferSlack) {
      shiftDown(position);
    } else if (windowEnd() - bufferSlack <= position) {
      shiftUp(position);
    }
    int adjusted = viewPositionToWindowIndex(position);
    AnyNode node = adjusted < 0 ? null : root.getWindow().get(adjusted);
    onBindViewHolder(holder, node);
  }

  @Override
  final public int getItemCount() {
    return root == null ? 0 : root.getMinimumCount();
  }

  // SlidingWindowPresenter

  // Notice: In the present/patch methods below, if a change has been made and we need to call one
  // of the notifyXYZ methods on RecyclerView then we *don't* update the value of root until on the
  // main thread. Doing so can lead to a race between layout and the notification methods.

  @Override
  final public void present(final SlidingWindowNode node) {
    // When presenting anew, calculate appropriate buffer sizes to adjust the display.
    if (root == null) {
      calculateBufferSizes();
      node.getDisplay().dispatch(node.getStartOffset(), node.getStartOffset() + bufferCount);
    }
    // If the item list is non-empty notify the view.
    if (node.getMinimumCount() > 0) {
      new Handler(Looper.getMainLooper()).post(new Runnable() {
        @Override
        public void run() {
          root = node;
          notifyItemRangeInserted(0, node.getMinimumCount());
        }
      });
    } else {
      root = node;
    }
  }

  @Override
  final public void patch(final SlidingWindowPatch patch) {
    if (!patch.getWindow().hasChanged()) {
      root = patch.getCurrent();
      return;
    }
    new Handler(Looper.getMainLooper()).post(new Runnable() {
      @Override
      public void run() {
        root = patch.getCurrent();
        int previousCount = patch.getPrevious().getMinimumCount();
        int currentCount = patch.getCurrent().getMinimumCount();
        for (ListPatch.RegionPatch region : patch.getWindow().getRegions()) {
          if (!region.isUpdate()) continue;
          int start = windowIndexToViewPosition(region.getIndex());
          if (start < previousCount) {
            notifyItemRangeChanged(start, region.getCount());
          }
        }
        if (currentCount > previousCount) {
          notifyItemRangeInserted(previousCount, currentCount - previousCount);
        } else if (previousCount > currentCount) {
          notifyItemRangeRemoved(currentCount, previousCount - currentCount);
        }
      }
    });
  }

  private void calculateBufferSizes() {
    // TODO(zerny): Caclulate this based on the views.
    int cellCount = 10;
    bufferSlack = 1;
    bufferAdvance = cellCount;
    bufferCount = 4 * bufferAdvance + cellCount;
  }

  private void shiftUp(int index) {
    int end = index + bufferAdvance + 1;
    if (end > maximumCount()) end = maximumCount();
    if (end == windowEnd()) return;
    if (end > bufferCount) {
      refreshDisplay(end - bufferCount, end);
    } else {
      refreshDisplay(0, bufferCount);
    }
  }

  private void shiftDown(int index) {
    int start = (index > bufferAdvance) ? index - bufferAdvance : 0;
    if (start == windowStart()) return;
    refreshDisplay(start, start + bufferCount);
  }

  private int windowIndexToViewPosition(int index) {
    int delta = index - windowOffset();
    if (delta < 0) delta += windowCount();
    return windowStart() + delta;
  }

  private int viewPositionToWindowIndex(int position) {
    if (position < windowStart() || windowEnd() <= position) return -1;
    int i = windowOffset() + position - windowStart();
    return i % windowCount();
  }

  private int minimumCount() {
    return root.getMinimumCount();
  }

  private int maximumCount() {
    return root.getMaximumCount() < 0 ? Integer.MAX_VALUE : root.getMaximumCount();
  }

  private int windowStart() {
    return root.getStartOffset();
  }

  private int windowEnd() {
    return windowStart() + windowCount();
  }

  private int windowCount() {
    return root.getWindow().size();
  }

  private int windowOffset() {
    return root.getWindowOffset();
  }

  private void refreshDisplay(int start, int end) {
    root.getDisplay().dispatch(start, end);
  }

  private int bufferCount;
  private int bufferSlack;
  private int bufferAdvance;
  private SlidingWindowNode root;
}
