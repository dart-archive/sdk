// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';
import '../generated/dart/github.dart';

class _Display {
  int startOffset = 0;
  int bufferOffset = 0;
  int bufferCount = 0;

  void update(int start, int end) {
    int shift = start - startOffset;
    int absShift = shift < 0 ? -shift : shift;
    if (absShift > 0) {
      if (absShift < bufferCount) {
        bufferOffset = (bufferOffset + shift) % bufferCount;
        if (bufferOffset < 0) {
          bufferOffset += bufferCount;
        }
      } else {
        bufferOffset = 0;
      }
      startOffset = start;
    }
    bufferCount = end - start;
  }
}

class CommitListPresenter {
  Repository _repository;
  _Display _display = new _Display();
  int _start = 0;
  int _end = 0;
  int _count = -1;
  int _minimumCount = 0;

  // TODO(zerny): Cache the tear-off to preserve identity. Eliminate this once
  // issue #25 is resovled.
  Function _setDisplayRangeTearOff;

  CommitListPresenter(this._repository) {
    _setDisplayRangeTearOff = _setDisplayRange;
  }

  CommitListNode present(Node previous) {
    _display.update(_start, _end);
    List commits = _presentCommits();
    return new CommitListNode(
        commits: commits,
        startOffset: _display.startOffset,
        bufferOffset: _display.bufferOffset,
        count: _count,
        minimumCount: _minimumCount,
        display: _setDisplayRangeTearOff);
  }

  void _setDisplayRange(int start, int end) {
    assert(start < end);
    _start = start;
    _end = end;
    _repository.prefetchCommitsInRange(start, end);
  }

  List<CommitNode> _presentCommits() {
    int length = _display.bufferCount;
    List<CommitNode> commits = new List(length);
    int startOffset = _display.startOffset;
    int bufferOffset = _display.bufferOffset;
    int i = 0;
    for (; i < length; ++i) {
      int index = startOffset + i;
      int bufferIndex = (bufferOffset + i) % length;
      Map<String, dynamic> json = _repository.getCommitAt(index);
      if (json == null) break;
      commits[bufferIndex] = new CommitNode(
          author: json['commit']['author']['name'],
          message: json['commit']['message']);
    }
    if (startOffset + i > _minimumCount) {
      _minimumCount = startOffset + i;
    }
    if (i == length) return commits;
    // If we have reached the last commit item re-adjust the display info.
    _count = _minimumCount;
    _display.bufferOffset = 0;
    _display.bufferCount = i;
    List<CommitNode> lastCommits = new List(i);
    for (int j = 0; j < i; ++j) {
      int bufferIndex = (bufferOffset + j) % length;
      lastCommits[j] = commits[bufferIndex];
    }
    return lastCommits;
  }
}
