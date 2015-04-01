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

  ConsoleNode present() {
    assert(trace("ConsolePresenter::present"));
    return node.console(
        title: "${_project.name}::${_project.console.title}",
        status: "${_project.console.status}",
        commits: presentCommits());
  }

  List<CommitNode> presentCommits() {
    assert(trace("ConsolePresenter::presentCommits"));
    Console console = _project.console;
    int length = console.commitCount;
    List commits = new List(length);
    for (int i = 0; i < length; ++i) {
      var data = console.commit(i);
      commits[i] = node.commit(revision: data["number"],
                               author: data["who"],
                               message: data["comments"]);
    }
    return commits;
  }
}
