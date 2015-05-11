// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';
import 'commit_presenter.dart';

import 'package:immi/immi.dart';
import 'package:immi_samples/sliding_window.dart';

// Export generated code for nodes in commit_list_presenter.immi
import 'package:immi_gen/dart/commit_list_presenter.dart';
export 'package:immi_gen/dart/commit_list_presenter.dart';

class CommitListPresenter {
  Repository _repository;
  SlidingWindow _presenter;

  CommitListPresenter(this._repository) {
    var commitPresenter = new CommitPresenter(_repository);
    _presenter = new SlidingWindow(commitPresenter);
  }

  CommitListNode present(Node previous) {
    // TODO(zerny): Eliminate this wrapping of the sliding-window presenter.
    SlidingWindowNode window = _presenter.present();
    return new CommitListNode(
        commits: window.window,
        startOffset: window.startOffset,
        bufferOffset: window.windowOffset,
        minimumCount: window.minimumCount,
        count: window.maximumCount,
        display: (int start, int end) {
          _repository.prefetchCommitsInRange(start, end);
          (window.display)(start, end);
        });
  }
}
