// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.content.Context;
import android.os.Bundle;
import android.support.v7.widget.CardView;
import android.util.AttributeSet;

import immi.CommitNode;

public class CommitCardView extends CardView {
  public CommitCardView(Context context) {
    super(context);
  }

  public CommitCardView(Context context, AttributeSet attrs) {
    super(context, attrs);
  }

  public CommitCardView(Context context, AttributeSet attrs, int defStyleAttr) {
    super(context, attrs, defStyleAttr);
  }

  public void setCommitNode(CommitNode node) {
    this.node = node;
  }

  public boolean isReady() {
    return node != null;
  }

  public String getTitle() { return node.getMessage(); }
  public String getAuthor() { return node.getAuthor(); }
  public String getDetails() { return node.getMessage(); }
  public String getImageUrl() { return node.getImage().getUrl(); }

  public Bundle prepareDetailsFragmentArgs() {
    Bundle args = new Bundle();
    args.putString(DetailsViewFragment.TITLE, getTitle());
    args.putString(DetailsViewFragment.AUTHOR, getAuthor());
    args.putString(DetailsViewFragment.DETAILS, getDetails());
    args.putString(DetailsViewFragment.IMAGE_URL,getImageUrl());
    return args;
  }

  private CommitNode node;
}
