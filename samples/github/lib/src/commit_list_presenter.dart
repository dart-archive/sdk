// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';
import 'commit_presenter.dart';

import 'package:immi/immi.dart';
import 'package:immi_samples/sliding_window.dart';

class CommitListPresenter {
  Repository _repository;
  SlidingWindow _presenter;

  CommitListPresenter(this._repository) {
    var commitPresenter = new CommitPresenter(_repository);
    _presenter = new SlidingWindow(commitPresenter);
  }

  // TODO(zerny): We should represent methods on nodes in a class structure and
  // support identity-preserving composition.
  Function _displayCache = null;
  Function _wrappedDisplayCache = null;
  Function _wrapDisplayForPrefetching(Function display) {
    if (display != _displayCache) {
      _displayCache = display;
      _wrappedDisplayCache = (int start, int end) {
        _repository.prefetchCommitsInRange(start, end);
        (display)(start, end);
      };
    }
    return _wrappedDisplayCache;
  }

  SlidingWindowNode present(Node previous) {
    SlidingWindowNode window = _presenter.present();
    return new SlidingWindowNode(
        window: window.window,
        startOffset: window.startOffset,
        windowOffset: window.windowOffset,
        minimumCount: window.minimumCount,
        maximumCount: window.maximumCount,
        toggle: window.toggle,
        display: _wrapDisplayForPrefetching(window.display));
  }
}
