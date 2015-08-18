// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import java.util.ArrayList;
import java.util.List;

public class Commit {
  String title;
  String author;
  int imageId;

  Commit(String title, String author, int imageId){
    this.title = title;
    this.author = author;
    this.imageId = imageId;
  }
}