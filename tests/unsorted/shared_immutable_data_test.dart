// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';
import 'package:immutable/immutable.dart';

const int INSERTS_PER_PROCESS = 1000;
const int NUM_PROCESSES = 1000;

// This function:
//   * inserts [INSERTS_PER_PROCESS/2] numbers into a tree
//     * sends the tree to a child process
//     * waits for the modified tree of the child process
//   * inserts [INSERTS_PER_PROCESS/2] numbers into a tree
//   * sends the modified tree to the caller
stackProcess(Port caller, tree, int process) {
  if (process < 0) {
    caller.send(tree);
    return;
  }

  int offset = process * INSERTS_PER_PROCESS;
  int count = INSERTS_PER_PROCESS ~/ 2;

  for (int i = offset; i < offset + count; i++) tree = tree.insert(i, i);

  var channel = new Channel();
  final port = new Port(channel);
  final finalTree = tree;
  Process.spawn(() => stackProcess(port, finalTree, process - 1));
  var tree2 = channel.receive();

  offset += INSERTS_PER_PROCESS ~/ 2;
  for (int i = offset; i < offset + count; i++) tree2 = tree2.insert(i, i);

  caller.send(tree2);
}

void main() {
  var channel = new Channel();
  final port = new Port(channel);
  Process.spawn(() => stackProcess(port, new RedBlackTree(), NUM_PROCESSES));
  var modifiedTree = channel.receive();
  for (int i = 0; i < NUM_PROCESSES * INSERTS_PER_PROCESS; i++) {
    Expect.equals(i, modifiedTree.lookup(i));
  }
}

