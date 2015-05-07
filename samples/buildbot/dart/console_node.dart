// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'package:service/struct.dart';

import 'buildbot_service.dart';
import 'commit_node.dart';
import 'presentation_utils.dart';
import '../trace.dart';

class ConsoleNode {
  final String title;
  final String status;
  final int commitsOffset;
  final List commits;
  ConsoleNode(this.title, this.status, this.commitsOffset, this.commits);

  ConsolePatch diff(ConsoleNode previous) {
    assert(trace("ConsoleNode::diff"));
    if (previous is! ConsoleNode) {
      return new ConsoleReplacePatch(this, previous);
    }
    ConsoleUpdatePatch patch;
    if (title != previous.title) {
      patch = new ConsoleUpdatePatch();
      patch.title = title;
    }
    if (status != previous.status) {
      if (patch == null) patch = new ConsoleUpdatePatch();
      patch.status = status;
    }
    if (commitsOffset != previous.commitsOffset) {
      if (patch == null) patch = new ConsoleUpdatePatch();
      patch.commitsOffset = commitsOffset;
    }
    ListPatch commitsPatch = diffList(commits, previous.commits);
    if (commitsPatch != null) {
      if (patch == null) patch = new ConsoleUpdatePatch();
      patch.commits = commitsPatch;
    }
    return patch;
  }

  void serialize(ConsoleNodeDataBuilder builder) {
    assert(trace("ConsoleNode::serialize"));
    builder.title = title;
    builder.status = status;
    int length = commits.length;
    List<CommitNodeDataBuilder> builders = builder.initCommits(length);
    for (int i = 0; i < length; ++i) {
      commits[i].serialize(builders[i]);
    }
  }
}

abstract class ConsolePatch {
  void serialize(ConsolePatchDataBuilder builder);
}

class ConsoleReplacePatch extends ConsolePatch {
  final ConsoleNode replacement;
  final ConsoleNode previous;
  ConsoleReplacePatch(this.replacement, this.previous);

  void serialize(ConsolePatchDataBuilder builder) {
    assert(trace("ConsoleReplacePatch::serialize"));
    replacement.serialize(builder.initReplace());
  }
}

class ConsoleUpdatePatch extends ConsolePatch {
  String _title;
  String _status;
  int _commitsOffset;
  ListPatch _commits;
  int _count = 0;

  set title(title) { ++_count; _title = title; }
  set status(status) { ++_count; _status = status; }
  set commitsOffset(commitsOffset) { ++_count; _commitsOffset = commitsOffset; }
  set commits(commits) { ++_count; _commits = commits; }

  void serialize(ConsolePatchDataBuilder builder) {
    assert(trace("ConsoleUpdatePatch::serialize"));
    assert(_count > 0);
    List<ConsoleUpdatePatchDataBuilder> builders = builder.initUpdates(_count);
    int index = 0;
    if (_title != null) builders[index++].title = _title;
    if (_status != null) builders[index++].status = _status;
    if (_commitsOffset != null) {
      builders[index++].commitsOffset = _commitsOffset;
    }
    if (_commits != null) _commits.serialize(builders[index++].initCommits());
    assert(index == _count);
  }
}
