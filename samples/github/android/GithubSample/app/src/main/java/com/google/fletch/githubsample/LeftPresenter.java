// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;

import com.google.fletch.immisamples.Drawer;
import com.google.fletch.immisamples.Menu;

import immi.AnyNode;
import immi.AnyNodePatch;
import immi.MenuNode;
import immi.MenuPatch;

public final class LeftPresenter extends Drawer.PanePresenter {

  LeftPresenter(Activity activity) {
    this.menu = new Menu(
        activity,
        android.R.layout.simple_list_item_activated_1,
        android.R.id.text1);

    fragment = (NavigationDrawerFragment)
        activity.getFragmentManager().findFragmentById(R.id.navigation_drawer);

    fragment.setupMenu(menu);
  }

  @Override
  public Drawer.PaneFragment getPaneFragment() {
    return fragment;
  }

  @Override
  public void present(AnyNode node) {
    menu.present(node.as(MenuNode.class));
  }

  @Override
  public void patch(AnyNodePatch patch) {
    menu.patch(patch.as(MenuPatch.class));
  }

  private NavigationDrawerFragment fragment;
  private Menu menu;
}
