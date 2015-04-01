// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

// This file provides utility functions for constructing presentation graphs.

import 'commit_node.dart';
import 'console_node.dart';

// TODO(zerny): Should we support default values?

CommitNode commit({int revision, String author, String message}) =>
  new CommitNode(revision, author, message);

ConsoleNode console({
    String title,
    String status,
    int commitsOffset,
    List commits}) =>
  new ConsoleNode(title, status, commitsOffset, commits);
