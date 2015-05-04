// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import '../github_services.dart';
import '../github_mock.dart';
import '../commit_list_presenter.dart';

import '../../generated/dart/github.dart';
import '../../generated/dart/github_presenter_service.dart';
import '../../generated/dart/struct.dart';

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

  // Initial rendering (don't assume much about this).
  CommitListNode initialNode = presenter.present(null);
  testDiff(null, initialNode);

  // Provide screen-size and re-render.
  // TODO(zerny): Remove unneeded parenthesis once issue #20 is resolved.
  (initialNode.display)(0, 5);
  CommitListNode subsequentNode = presenter.present(initialNode);
  Expect.equals(0, subsequentNode.startOffset);
  Expect.equals(5, subsequentNode.commits.length);
  Expect.stringEquals("Ian Zerny", subsequentNode.commits[0].author);
  testDiff(initialNode, subsequentNode);
}

testDiff(Node previous, Node current) {
  var path = [];
  var patches = [];
  Expect.isTrue(current.diff(previous, path, patches));
  Expect.isTrue(patches.length > 0);

  // Check that we can successfully serialize the data.
  var manager = new ResourceManager();
  var mb = new MessageBuilder(16);
  var builder = mb.initRoot(new PatchSetDataBuilder(), 8);
  var builders = builder.initPatches(patches.length);
  for (int i = 0; i < patches.length; ++i) {
    patches[i].serialize(builders[i], manager);
  }
}
