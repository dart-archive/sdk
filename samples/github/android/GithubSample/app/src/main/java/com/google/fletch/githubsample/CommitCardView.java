// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.content.Context;
import android.support.v7.widget.CardView;
import android.util.AttributeSet;

public class CommitCardView extends CardView {
  Commit commitItem;

  public CommitCardView(Context context) {
    super(context);
  }

  public CommitCardView(Context context, AttributeSet attrs) {
    super(context, attrs);
  }

  public CommitCardView(Context context, AttributeSet attrs, int defStyleAttr) {
    super(context, attrs, defStyleAttr);
  }

  public void setCommitItem(Commit commitItem) {
    this.commitItem = commitItem;
  }

  public Commit getCommitItem() {
    return commitItem;
  }
}
