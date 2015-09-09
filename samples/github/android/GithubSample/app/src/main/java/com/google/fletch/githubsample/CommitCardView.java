// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;
import android.app.ActivityOptions;
import android.content.Context;
import android.content.Intent;
import android.graphics.drawable.BitmapDrawable;
import android.support.v7.widget.CardView;
import android.util.AttributeSet;
import android.util.Pair;
import android.widget.ImageView;

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

  public String getTitle() { return node.getMessage(); }
  public String getAuthor() { return node.getAuthor(); }
  public String getDetails() { return node.getMessage(); }
  public String getImageUrl() { return node.getImage().getUrl(); }

  public ActivityOptions prepareShowDetails(Activity activity, Intent intent) {
    intent.putExtra("Title", getTitle());
    intent.putExtra("Author", getAuthor());
    intent.putExtra("Details", getDetails());

    // TODO(zarah): Assess the performance of this. If it turns out to be too inefficient to send
    // over bitmaps, make the image cache accessible and send the image url instead.
    ImageView imageView = (ImageView)findViewById(R.id.avatar);
    BitmapDrawable bitmap = (BitmapDrawable)imageView.getDrawable();
    intent.putExtra("bitmap", bitmap != null ? bitmap.getBitmap() : null);

    // TODO(zarah): Find a way to transition the card smoothly as well.
    ActivityOptions options =
        ActivityOptions.makeSceneTransitionAnimation(activity,
            Pair.create(findViewById(R.id.avatar), "transition_image"),
            Pair.create(findViewById(R.id.author), "transition_author"),
            Pair.create(findViewById(R.id.title), "transition_title"));

    return options;
  }

  private CommitNode node;
}
