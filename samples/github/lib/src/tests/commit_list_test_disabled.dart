// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import 'package:immi/immi.dart';
import 'package:immi_samples/sliding_window.dart';
import 'package:service/struct.dart';

import 'package:immi_gen/dart/immi_service.dart';

import '../../github_immi.dart';
import '../github_services.dart';
import '../github_mock.dart';
import '../commit_list_presenter.dart';
import '../commit_presenter.dart';

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
  SlidingWindowNode previous = null;
  SlidingWindowNode current = null;
  CommitNode commitNode = null;

  // Initial rendering (don't assume much about this).
  current = presenter.present(previous);
  testDiff(previous, current);

  // Provide screen-size and re-render.
  (current.display)(0, 5);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(0, current.startOffset);
  Expect.equals(5, current.window.length);
  commitNode = current.window[0];
  Expect.stringEquals("Ian Zerny", commitNode.author);
  testDiff(previous, current);

  (current.display)(0, 6);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(0, current.startOffset);
  Expect.isTrue(current.window.length >= 6);
  commitNode = current.window[0];
  Expect.stringEquals("Ian Zerny", commitNode.author);
  testDiff(previous, current);

  (current.display)(1, 6);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(1, current.startOffset);
  Expect.equals(1, current.windowOffset);
  Expect.isTrue(current.window.length >= 5);
  commitNode = current.window[1];
  Expect.stringEquals("Anders Johnsen", commitNode.author);
  testDiff(previous, current);

  (current.display)(100, 105);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(100, current.startOffset);
  Expect.equals(0, current.windowOffset);

  (current.display)(99, 104);
  previous = current;
  current = presenter.present(previous);
  Expect.equals(99, current.startOffset);
  Expect.equals(4, current.windowOffset);
}

testDiff(Node previous, Node current) {
  NodePatch patch = current.diff(previous);
  Expect.isNotNull(patch);

  // Check that we can successfully serialize the data.
  var manager = new ResourceManager();
  var mb = new MessageBuilder(24);
  PatchDataBuilder builder = mb.initRoot(new PatchDataBuilder(), 16);
  patch.serializeNode(builder.initNode(), manager);
}
