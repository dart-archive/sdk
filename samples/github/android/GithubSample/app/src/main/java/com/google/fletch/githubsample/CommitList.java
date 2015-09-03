// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import java.util.ArrayList;
import java.util.List;

public class CommitList {

  public List<Commit> commitList;

  CommitList() {
    String loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus non ex " +
        "facilisis, consequat velit cursus, ullamcorper felis. Sed efficitur est felis, mollis " +
        "aliquam dui dictum id. Phasellus commodo id arcu in dignissim. Vivamus ut eros ligula. " +
        "Curabitur a odio turpis. Aliquam non elit urna. Mauris posuere sagittis justo quis " +
        "pretium. Pellentesque fringilla felis nec metus lacinia, at finibus sapien cursus. " +
        "Phasellus facilisis sed libero sit amet laoreet. Proin risus dui, molestie sit amet " +
        "consequat vel, malesuada sit amet quam. Donec eu posuere nisi.";

    this.commitList = new ArrayList<Commit>();
    for (int i = 0; i < 50; i += 5) {
      commitList.add(new Commit(
          "Title", "Author", loremIpsum, "https://www.dartlang.org/logos/dart-logo.png"));
      commitList.add(new Commit(
          "Title", "Author", loremIpsum, "https://avatars.githubusercontent.com/u/2156198?v=3"));
      commitList.add(new Commit(
          "Title", "Author", loremIpsum, "https://avatars.githubusercontent.com/u/2909286?v=3"));
      commitList.add(new Commit(
          "Title", "Author", loremIpsum, "https://avatars.githubusercontent.com/u/22043?v=3"));
      commitList.add(new Commit(
          "Title", "Author", loremIpsum, "https://avatars.githubusercontent.com/u/5689005?v=3"));
    }
  }
}