// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'buildbot_service.dart';
import 'presentation_utils.dart';
import '../trace.dart';

class CommitNode {
  final int revision;
  final String author;
  final String message;

  CommitNode(this.revision, this.author, this.message);

  CommitPatch diff(CommitNode previous) {
    assert(trace("CommitNode::diff"));
    if (previous is! CommitNode) {
      return new CommitReplacePatch(this, previous);
    }
    CommitUpdatePatch patch;
    if (revision != previous.revision) {
      patch = new CommitUpdatePatch();
      patch.revision = revision;
    }
    if (author != previous.author) {
      if (patch == null) patch = new CommitUpdatePatch();
      patch.author = author;
    }
    if (message != previous.message) {
      if (patch == null) patch = new CommitUpdatePatch();
      patch.message = message;
    }
    return patch;
  }

  void serialize(CommitNodeDataBuilder builder) {
    assert(trace("CommitNode::serialize"));
    builder.revision = revision;
    builder.author = author;
    builder.message = message;
  }
}

abstract class CommitPatch {
  void serialize(CommitPatchDataBuilder builder);
}

class CommitReplacePatch extends CommitPatch {
  final CommitNode replacement;
  final CommitNode previous;
  CommitReplacePatch(this.replacement, this.previous);
  void serialize(CommitPatchDataBuilder builder) {
    assert(trace("CommitReplacePatch::serialize"));
    replacement.serialize(builder.initReplace());
  }
}

class CommitUpdatePatch extends CommitPatch {
  int _revision;
  String _author;
  String _message;
  int _count = 0;

  set revision(revision) { ++_count; _revision = revision; }
  set author(author) { ++_count; _author = author; }
  set message(message) { ++_count; _message = message; }

  void serialize(CommitPatchDataBuilder builder) {
    assert(trace("CommitUpdatePatch::serialize"));
    assert(_count > 0);
    List<CommitUpdatePatchDataBuilder> builders = builder.initUpdates(_count);
    int index = 0;
    if (_revision != null) builders[index++].revision = _revision;
    if (_author != null) builders[index++].author = _author;
    if (_message != null) builders[index++].message = _message;
    assert(index == _count);
  }
}
