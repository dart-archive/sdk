// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;

import android.app.ActionBar;
import android.app.ActivityOptions;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.os.Bundle;

import android.transition.Explode;
import android.util.Pair;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.support.v4.widget.DrawerLayout;
import android.widget.ImageView;
import android.widget.Toast;

import com.google.fletch.immisamples.Drawer;

import immi.AnyNode;
import immi.AnyNodePatch;
import immi.AnyNodePresenter;
import immi.DrawerNode;
import immi.DrawerPatch;
import immi.ImmiRoot;
import immi.ImmiService;

public class MainActivity extends Activity implements AnyNodePresenter {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);

    drawer = new Drawer(
        (DrawerLayout)findViewById(R.id.drawer_layout),
        new LeftPresenter(this),
        new CenterPresenter(this),
        null);

    // Create an immi service and attach a root graph.
    ImmiService immi = new ImmiService();
    ImmiRoot root = immi.registerPresenter(this, "DrawerPresenter");

    // If we are restoring, reset the presentation graph to get a complete graph.
    if (savedInstanceState != null) root.reset();

    // Initiate presentation.
    root.refresh();
  }

  @Override
  public void present(AnyNode node) {
    drawer.present(node.as(DrawerNode.class));
  }

  @Override
  public void patch(AnyNodePatch patch) {
    drawer.patch(patch.as(DrawerPatch.class));
  }

  @Override
  public boolean onCreateOptionsMenu(Menu menu) {
    if (!drawer.getLeftVisible()) {
      // Only show items in the action bar relevant to this screen
      // if the drawer is not showing. Otherwise, let the drawer
      // decide what to show in the action bar.
      getMenuInflater().inflate(R.menu.menu_main, menu);
      restoreActionBar();
      return true;
    }
    return super.onCreateOptionsMenu(menu);
  }

  @Override
  public boolean onOptionsItemSelected(MenuItem item) {
    int id = item.getItemId();
    if (id == R.id.login) {
      startActivity(new Intent(this, LoginActivity.class));j
      return true;
    }
    return super.onOptionsItemSelected(item);
  }

  public void restoreActionBar() {
    ActionBar actionBar = getActionBar();
    actionBar.setDisplayShowTitleEnabled(true);
    actionBar.setTitle(getTitle());
  }

  public void showDetails(View view) {
    Intent intent = new Intent(this, DetailsViewActivity.class);
    Commit commitItem = ((CommitCardView) view).getCommitItem();
    intent.putExtra("Title", commitItem.title);
    intent.putExtra("Author", commitItem.author);
    intent.putExtra("Details", commitItem.details);

    // TODO(zarah): Assess the performance of this. If it turns out to be too inefficient to send
    // over bitmaps, make the image cache accessible and send the image url instead.
    Bitmap bitmap =
        ((BitmapDrawable)((ImageView) view.findViewById(R.id.avatar)).getDrawable()).getBitmap();
    intent.putExtra("bitmap", bitmap);

    // TODO(zarah): Find a way to transition the card smoothly as well.
    ActivityOptions options =
        ActivityOptions.makeSceneTransitionAnimation(this,
            Pair.create(view.findViewById(R.id.avatar), "transition_image"),
            Pair.create(view.findViewById(R.id.author), "transition_author"),
            Pair.create(view.findViewById(R.id.title), "transition_title"));
    getWindow().setExitTransition(new Explode());
    startActivity(intent, options.toBundle());
  }

  private Drawer drawer;
  private com.google.fletch.immisamples.Menu menu;
}
