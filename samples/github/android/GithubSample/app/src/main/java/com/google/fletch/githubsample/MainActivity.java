// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;

import android.app.ActionBar;
import android.app.ActivityOptions;
import android.content.Intent;
import android.os.Bundle;

import android.transition.Explode;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.support.v4.widget.DrawerLayout;

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
    final ImmiService immi = new ImmiService();
    final ImmiRoot root = immi.registerPresenter(this, "DrawerPresenter");

    // If we are restoring, reset the presentation graph to get a complete graph.
    if (savedInstanceState != null) root.reset();

    // Ensure that we have a mock server running.
    // Once confirmed, initiate the initial graph refresh.
    new GithubMockServer().ensureServer(this, new GithubMockServer.EnsureServerCallback() {
      @Override
      public void handle(int port) {
        // TODO(zerny): We should dynamically configure which port the server is on.
        root.refresh();
      }
    });
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
    if (!drawer.isReady() || !drawer.getLeftVisible()) {
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
      startActivity(new Intent(this, LoginActivity.class));
      return true;
    }
    return super.onOptionsItemSelected(item);
  }

  public void restoreActionBar() {
    ActionBar actionBar = getActionBar();
    actionBar.setDisplayShowTitleEnabled(true);
    actionBar.setTitle(getTitle());
  }

  private Drawer drawer;
}
