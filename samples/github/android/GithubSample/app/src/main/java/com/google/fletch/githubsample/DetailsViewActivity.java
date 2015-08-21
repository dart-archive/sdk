// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

public class DetailsViewActivity extends Activity{

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_details);
    configureCard();
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

  private void configureCard() {
    ImageView avatar = (ImageView) findViewById(R.id.details_avatar);
    avatar.setImageResource(R.drawable.dart_logo);
    TextView title = (TextView) findViewById(R.id.details_title);
    title.setText("Title");
    TextView author = (TextView) findViewById(R.id.details_author);
    author.setText("Author");
    TextView details = (TextView) findViewById(R.id.details);
    details.setText("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus non ex " +
        "facilisis, consequat velit cursus, ullamcorper felis. Sed efficitur est felis, mollis " +
        "aliquam dui dictum id. Phasellus commodo id arcu in dignissim. Vivamus ut eros ligula. " +
        "Curabitur a odio turpis. Aliquam non elit urna. Mauris posuere sagittis justo quis " +
        "pretium. Pellentesque fringilla felis nec metus lacinia, at finibus sapien cursus. " +
        "Phasellus facilisis sed libero sit amet laoreet. Proin risus dui, molestie sit amet " +
        "consequat vel, malesuada sit amet quam. Donec eu posuere nisi.");
  }
}
