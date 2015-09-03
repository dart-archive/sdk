// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

public class DetailsViewActivity extends Activity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_details);
    getActionBar().hide();

    Intent intent = getIntent();
    configureCard(
        (Bitmap) intent.getParcelableExtra("bitmap"),
        intent.getStringExtra("Title"),
        intent.getStringExtra("Author"),
        intent.getStringExtra("Details"));
  }

  @Override
  public boolean onOptionsItemSelected(MenuItem item) {
    switch (item.getItemId()) {
      // Respond to the action bar's Up/Home button
      case android.R.id.home:
        finishAfterTransition();
        return true;
    }
    return super.onOptionsItemSelected(item);
  }

  public void endDetailsView(View view) {
    finishAfterTransition();
  }

  private void configureCard(Bitmap bitmap, String title, String author, String details) {
    ImageView avatar = (ImageView) findViewById(R.id.details_avatar);
    avatar.setImageBitmap(bitmap);
    TextView titleView = (TextView) findViewById(R.id.details_title);
    titleView.setText(title);
    TextView authorView = (TextView) findViewById(R.id.details_author);
    authorView.setText(author);
    TextView detailsView = (TextView) findViewById(R.id.details);
    detailsView.setText(details);
  }
}
