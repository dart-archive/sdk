// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../generated/dart/github.dart';

class CommitListPresenter {
  int revision = 0;
  CommitListNode present(Node previous) {
    return new CommitListNode(
        commits: [new Commit(
            revision: ++revision,
            author: 'zerny@google.com',
            message: 'Fletchy fletch fletch')]);
  }
}
