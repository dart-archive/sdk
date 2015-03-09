// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

import 'presentation_utils.dart';

class CommitNode {
  int revision;
  String author;
  String message;
  CommitNode(this.revision, this.author, this.message);

  // TODO(zerny): implement diff

  void serialize(CommitNodeDataBuilder builder) {
    builder.revision = revision;
    serializeString(author, builder.initAuthor());
    serializeString(message, builder.initMessage());
  }
}

// TODO(zerny): implement CommitNode patches.
