// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'model.dart';
import 'dart/buildbot_service.dart';
import 'console_presenter.dart';

class BuildBotImpl extends BuildBotService {
  Project _project;
  ConsolePresenter _presenter;
  ConsoleNode _presenter_graph = null;

  BuildBotImpl() {
    _project = new Project("Dart")
      ..console = new Console(
          "Main",
          new Resource("build.chromium.org", "/p/client.dart"),
          new Resource("dart-status.appspot.com", ""));

    _presenter = new ConsolePresenter(_project);
  }

  void refresh(PresenterPatchSetBuilder builder) {
    _presenter_graph = _presenter.refresh(_presenter_graph,
                                          builder.initConsolePatchSet());
  }
}
