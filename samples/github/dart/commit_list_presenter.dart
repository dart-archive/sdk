// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';
import '../generated/dart/github.dart';

class CommitListPresenter {
  Repository _repository;

  // TODO(zerny): Make these adjustable from the UI.
  int _offset = 0;
  int _visibleCount = 20;

  CommitListPresenter(this._repository);

  CommitListNode present(Node previous) {
    return new CommitListNode(commits: _presentCommits());
  }

  List<CommitNode> _presentCommits() {
    List<CommitNode> commits = new List(_visibleCount);
    for (int i = 0; i < _visibleCount; ++i) {
      int index = _offset + i;
      Map<String, dynamic> json = _repository.getCommitAt(index);
      commits[i] = new CommitNode(
          // TODO(zerny): Can we construct a meaningful revision here?
          revision: 0,
          author: json['commit']['author']['name'],
          message: json['commit']['message']);
    }
    return commits;
  }
}
