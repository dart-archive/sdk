// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';
import '../generated/dart/github.dart';

class CommitListPresenter {
  Repository _repository;

  int _offset = 0;
  int _visibleCount = 0;

  // TODO(zerny): Cache the tear-off to preserve identity. Eliminate this once
  // issue #25 is resovled.
  Function _setDisplayRangeTearOff;

  CommitListPresenter(this._repository) {
    _setDisplayRangeTearOff = _setDisplayRange;
  }

  CommitListNode present(Node previous) {
    return new CommitListNode(
        startOffset: _offset,
        commits: _presentCommits(),
        display: _setDisplayRangeTearOff);
  }

  void _setDisplayRange(int start, int end) {
    assert(start < end);
    _offset = start;
    _visibleCount = end - start;
  }

  List<CommitNode> _presentCommits() {
    List<CommitNode> commits = new List(_visibleCount);
    for (int i = 0; i < _visibleCount; ++i) {
      int index = _offset + i;
      Map<String, dynamic> json = _repository.getCommitAt(index);
      commits[i] = new CommitNode(
          author: json['commit']['author']['name'],
          message: json['commit']['message']);
    }
    return commits;
  }
}
