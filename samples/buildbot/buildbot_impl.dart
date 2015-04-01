// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'model.dart';
import 'dart/buildbot_service.dart';
import 'console_presenter.dart';
import 'trace.dart';

class BuildBotImpl extends BuildBotService {
  Project _project;
  ConsolePresenter _consolePresenter;
  ConsoleNode _consoleGraph = null;

  BuildBotImpl() {
    _project = new Project("Dart")
      ..console = new Console(
          "Main",
          new Resource("build.chromium.org", "/p/client.dart"),
          new Resource("dart-status.appspot.com", ""));

    _consolePresenter = new ConsolePresenter(_project);
  }

  void refresh(BuildBotPatchDataBuilder builder) {
    assert(trace("BuildBotImpl::refresh (${_project.console.commitCount})"));
    // TODO(zerny): How do we want to connect the presentation roots?
    ConsoleNode graph = _consolePresenter.present();
    ConsolePatch patch = graph.diff(_consoleGraph);
    if (patch != null) {
      _consoleGraph = graph;
      patch.serialize(builder.initConsolePatch());
      assert(trace("Sending non-empty patch"));
      return;
    }
    assert(trace("Sending empty patch"));
    builder.setNoPatch();
  }
}
