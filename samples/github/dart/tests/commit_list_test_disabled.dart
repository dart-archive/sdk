// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import 'package:immi/immi.dart';
import 'package:service/struct.dart';

import '../github_services.dart';
import '../github_mock.dart';
import '../commit_list_presenter.dart';

import 'package:immi_gen/dart/github.dart';
import 'package:immi_gen/dart/immi_service.dart';

void main() {
  var mock = new GithubMock()..spawn();
  var server = new Server(mock.host, mock.port);
  var user = server.getUser('dart-lang');
  var repo = user.getRepository('fletch');
  testPresent(repo);
  server.close();
  mock.close();
}

void testPresent(Repository repo) {
  var presenter = new CommitListPresenter(repo);
  CommitListNode previous = null;
  CommitListNode current = null;

  // Initial rendering (don't assume much about this).
  current = presenter.present(previous);
  testDiff(previous, current);

  // Provide screen-size and re-render.
  (current.display)(0, 5);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(0, current.startOffset);
  Expect.equals(5, current.commits.length);
  Expect.stringEquals("Ian Zerny", current.commits[0].author);
  testDiff(previous, current);

  (current.display)(0, 6);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(0, current.startOffset);
  Expect.isTrue(current.commits.length >= 6);
  Expect.stringEquals("Ian Zerny", current.commits[0].author);
  testDiff(previous, current);

  (current.display)(1, 6);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(1, current.startOffset);
  Expect.equals(1, current.bufferOffset);
  Expect.isTrue(current.commits.length >= 5);
  Expect.stringEquals("Anders Johnsen", current.commits[1].author);
  testDiff(previous, current);

  (current.display)(100, 105);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(100, current.startOffset);
  Expect.equals(0, current.bufferOffset);

  (current.display)(99, 104);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(99, current.startOffset);
  Expect.equals(4, current.bufferOffset);
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
