// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/commit_list_presenter.dart';
import 'dart/github_mock.dart';
import 'dart/github_services.dart';
import 'generated/dart/github.dart';

main() {
  var mock = new GithubMock()..spawn();
  var server = new Server(mock.host, mock.port);
  var root = new CommitListPresenter();
  var impl = new GithubImpl(root);
  impl.run();
}
