// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_services.dart';

import 'package:immi/dart/immi.dart';
import 'package:immi/dart/image.dart';

import 'package:immi_samples/sequenced_presenter.dart';

// Export generated code for nodes in commit_presenter.immi
import 'package:immi/dart/commit_presenter.dart';
export 'package:immi/dart/commit_presenter.dart';

class CommitPresenter extends SequencedPresenter<CommitNode> {
  Repository _repository;
  Set<int> selectedIndices = new Set<int>();

  CommitPresenter(this._repository);

  void toggleAt(int index) {
    if (selectedIndices.contains(index)) {
      selectedIndices.remove(index);
    } else {
      selectedIndices.add(index);
    }
  }

  CommitNode presentAt(int index) {
    Map<String, dynamic> json = _repository.getCommitAt(index);
    if (json == null) return null;

    String imageUrl = json['author'] == null
      ? ""
      : json['author']['avatar_url'];

    return new CommitNode(
        author: json['commit']['author']['name'],
        message: json['commit']['message'],
        selected: selectedIndices.contains(index),
        image: new ImageNode(url: imageUrl));
  }
}
