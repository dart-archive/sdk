// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'model.dart';
import 'dart/buildbot_service.dart';
import 'console_presenter.dart';

class BuildBotImpl extends BuildBotService {
  Project _project;
  ConsolePresenter _presenter;
  BuildBotImpl() {
    _project = new Project("Dart")
      ..console = new Console(
          "Main",
          "http://build.chromium.org/p/client.dart",
          "http://dart-status.appspot.com");

    _presenter = new ConsolePresenter(_project);
  }

  void refresh(PresenterPatchSetBuilder builder) {
    _presenter.refresh(null, builder.initConsolePatchSet());
  }
}
