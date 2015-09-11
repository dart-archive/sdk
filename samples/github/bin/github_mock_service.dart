// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:service/dart/github_mock.dart';
import 'package:github_sample/src/github_mock.dart';
import 'package:github_sample/src/github_mock_data.dart';

class GithubMockServerImpl extends GithubMockServer {
  GithubMock mock;

  GithubMockServerImpl() {
    mock = new GithubMock('127.0.0.1', 8321);
    mock.dataStorage = new ByteMapDataStorage();
    mock.verbose = true;
  }

  void start(int port) {
    mock.spawn();
  }

  void stop() {
    mock.close();
  }
}

main() {
  var impl = new GithubMockServerImpl();
  GithubMockServer.initialize(impl);
  while (GithubMockServer.hasNextEvent()) {
    GithubMockServer.handleNextEvent();
  }
}
