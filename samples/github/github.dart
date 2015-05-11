// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/commit_list_presenter.dart';
import 'dart/commit_presenter.dart';
import 'dart/github_mock.dart';
import 'dart/github_services.dart';

import 'package:immi_gen/dart/immi_service_impl.dart';

main() {
  var mock = new GithubMock()..spawn();
  var server = new Server(mock.host, mock.port);
  var user = server.getUser('dart-lang');
  var repo = user.getRepository('fletch');
  var commitListPresenter = new CommitListPresenter(repo);
  var impl = new ImmiServiceImpl(commitListPresenter);
  impl.run();
  server.close();
  mock.close();
}
