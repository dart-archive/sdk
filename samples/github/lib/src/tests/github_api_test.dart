// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import '../github_services.dart';
import '../github_mock.dart';

void main() {
  var mock = new GithubMock()..verbose = true..spawn();
  var server = new Server(mock.host, mock.port);
  testError(server);
  testUser(server);
  testRepository(server);
  testCommits(server);
  server.close();
  mock.close();
}

void testUser(Server server) {
  var user = server.getUser('dartino');
  Expect.stringEquals('dartino', user['login']);
}

void testRepository(Server server) {
  var user = server.getUser('dartino');
  var repo = user.getRepository('sdk');
  Expect.stringEquals('dartino/sdk', repo['full_name']);
}

void testError(Server server) {
  var user = server.getUser('dartino-no-such-user');
  Expect.throws(() { user['login']; });
}

void testCommits(Server server) {
  var user = server.getUser('dartino');
  var repo = user.getRepository('sdk');
  var commit = repo.getCommitAt(0);
  Expect.stringEquals('Martin Kustermann', commit['commit']['author']['name']);
  commit = repo.getCommitAt(60);
  Expect.stringEquals('Søren Gjesse', commit['commit']['author']['name']);
}
