// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import java.util.ArrayList;
import java.util.List;

public class CommitList {

  public List<Commit> commitList;

  CommitList() {
    this.commitList = new ArrayList<Commit>();
    for (int i = 0; i < 50; i++) {
      commitList.add(new Commit("Title", "Author", "https://www.dartlang.org/logos/dart-logo.png"));
    }
  }
}