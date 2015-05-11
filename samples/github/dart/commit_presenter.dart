// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';

import 'package:immi/immi.dart';
import 'package:immi_samples/sequenced_presenter.dart';

// Export generated code for nodes in commit_presenter.immi
import 'package:immi_gen/dart/commit_presenter.dart';
export 'package:immi_gen/dart/commit_presenter.dart';

class CommitPresenter extends SequencedPresenter<CommitNode> {
  Repository _repository;
  CommitPresenter(this._repository);
  CommitNode presentAt(int index) {
    Map<String, dynamic> json = _repository.getCommitAt(index);
    if (json == null) return null;
    return new CommitNode(
        author: json['commit']['author']['name'],
        message: json['commit']['message']);
  }
}
