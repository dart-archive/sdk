// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

public class Commit {
  String title;
  String author;
  String details;
  String imageUrl;

  Commit(String title, String author, String details, String imageUrl) {
    this.title = title;
    this.author = author;
    this.details = details;
    this.imageUrl = imageUrl;
  }
}