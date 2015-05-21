// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library immi_samples.sliding_window;

import 'sequenced_presenter.dart';

import 'package:immi/immi.dart';

// Export generated code for nodes in sliding_window.immi
import 'package:immi_gen/dart/sliding_window.dart';
export 'package:immi_gen/dart/sliding_window.dart';

class _Window {
  int startOffset = 0;
  int windowOffset = 0;
  int windowCount = 0;

  void update(int start, int end) {
    int shift = start - startOffset;
    int absShift = shift < 0 ? -shift : shift;
    if (absShift > 0) {
      if (absShift < windowCount) {
        windowOffset = (windowOffset + shift) % windowCount;
        if (windowOffset < 0) {
          windowOffset += windowCount;
        }
      } else {
        windowOffset = 0;
      }
      startOffset = start;
    }
    windowCount = end - start;
  }
}

class SlidingWindow<T extends Node> {
  SequencedPresenter<T> _presenter;

  _Window _display = new _Window();
  int _start = 0;
  int _end = 0;
  int _minimumCount = 0;
  int _maximumCount = -1;

  SlidingWindow(this._presenter);

  SlidingWindowNode present() {
    _display.update(_start, _end);
    List items = _presentWindow();
    return new SlidingWindowNode(
        window: items,
        startOffset: _display.startOffset,
        windowOffset: _display.windowOffset,
        minimumCount: _minimumCount,
        maximumCount: _maximumCount,
        display: _setDisplayRange);
  }

  void _setDisplayRange(int start, int end) {
    assert(start < end);
    _start = start;
    _end = end;
  }

  List<Node> _presentWindow() {
    int length = _display.windowCount;
    List<Node> items = new List(length);
    int startOffset = _display.startOffset;
    int windowOffset = _display.windowOffset;
    int i = 0;
    for (; i < length; ++i) {
      int index = startOffset + i;
      int windowIndex = (windowOffset + i) % length;
      Node item = _presenter.presentAt(index);
      if (item == null) break;
      items[windowIndex] = item;
    }
    if (startOffset + i > _minimumCount) {
      _minimumCount = startOffset + i;
    }
    if (i == length) return items;
    // If we have reached the last item re-adjust the display info.
    _maximumCount = _minimumCount;
    _display.windowOffset = 0;
    _display.windowCount = i;
    List<Node> lastItems = new List(i);
    for (int j = 0; j < i; ++j) {
      int windowIndex = (windowOffset + j) % length;
      lastItems[j] = items[windowIndex];
    }
    return lastItems;
  }
}
