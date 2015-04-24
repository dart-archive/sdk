// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import '../github_services.dart';
import '../github_mock.dart';
import '../commit_list_presenter.dart';

import '../../generated/dart/github.dart';

void main() {
  var mock = new GithubMock()..spawn();
  var server = new Server(mock.host, mock.port);
  var user = server.getUser('dart-lang');
  var repo = user.getRepository('fletch');
  testPresent(repo);
  mock.close();
}

void testPresent(Repository repo) {
  var presenter = new CommitListPresenter(repo);
  CommitListNode node = presenter.present(null);
  Expect.stringEquals("Ian Zerny", node.commits[0].author);
}
