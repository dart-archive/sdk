// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'model.dart';
import 'dart/console_presenter_base.dart';
import 'dart/presentation_graph.dart' as node;
import 'trace.dart';

class ConsolePresenter extends ConsolePresenterBase {
  int _version = 0;
  Project _project;
  ConsolePresenter(this._project);

  int _index = 0;         // Index of first visible item.
  int _visibleCount = 0;  // Visible item count.
  int _beforeCount = 20;  // Minimum buffer before visible items.
  int _afterCount = 20;   // Minimum buffer after visible items.
  int _slackCount = 10;   // Slack before adjusting items.
  int _previousStart = 0;

  set firstVisibleItem(int index) { _index = index; }
  set visibleItemCount(int count) { _visibleCount = count; }
  set lastVisibleItem(int index) {
    _index = (index > _visibleCount) ? index - _visibleCount : 0;
  }

  ConsoleNode present() {
    assert(trace("ConsolePresenter::present"));
    int startIndex = (_index > _beforeCount) ? _index - _beforeCount : 0;
    int endIndex = _index + _visibleCount + _afterCount;
    // Avoid shifting the start offset by less than [_slackCount].
    if (startIndex == 0 ||
        startIndex + _slackCount < _previousStart ||
        startIndex - _slackCount > _previousStart) {
      _previousStart = startIndex;
    } else {
      startIndex = _previousStart;
    }
    return node.console(
        title: "${_project.name}::${_project.console.title}",
        status: "${_project.console.status}",
        commitsOffset: startIndex,
        commits: presentCommits(startIndex, endIndex));
  }

  List<CommitNode> presentCommits(int start, int end) {
    Console console = _project.console;
    if (console.commitCount < end) {
      end = console.commitCount;
    }
    int length = end - start;
    List commits = new List(length);
    assert(trace("ConsolePresenter::presentCommits"));
    for (int i = 0; i < length; ++i) {
      var data = console.commit(start + i);
      commits[i] = node.commit(revision: data["number"],
                               author: data["who"],
                               message: data["comments"]);
    }
    return commits;
  }
}
