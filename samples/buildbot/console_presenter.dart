// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'model.dart';
import 'dart/console_presenter_base.dart';
import 'dart/presentation_graph.dart' as node;

class ConsolePresenter extends ConsolePresenterBase {
  Project _project;
  ConsolePresenter(this._project);

  ConsoleNode present() =>
    node.console(title: "${_project.name}::${_project.console.title}",
                 status: _project.console.status);
}
