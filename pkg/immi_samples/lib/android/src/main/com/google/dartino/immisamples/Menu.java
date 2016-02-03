// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.dartino.immisamples;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;

import immi.MenuItemNode;
import immi.MenuNode;
import immi.MenuPatch;
import immi.MenuPresenter;

public class Menu
    extends ArrayAdapter<String>
    implements MenuPresenter, AdapterView.OnItemClickListener {

  public Menu(Context context, int resource, int textViewResourceId) {
    // ArrayAdapter
    super(context, resource, textViewResourceId);
  }

  public void setListView(ListView view) {
    view.setOnItemClickListener(this);
    view.setAdapter(this);
    // TODO(zerny): Implement selected state for menus.
  }

  // From MenuPresenter

  @Override
  public void present(MenuNode node) {
    root = node;
    new Handler(Looper.getMainLooper()).post(updateItems);
  }

  @Override
  public void patch(MenuPatch patch) {
    root = patch.getCurrent();
    new Handler(Looper.getMainLooper()).post(updateItems);
  }

  // From OnItemClickListener

  @Override
  public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
    assert position < root.getItems().size();
    root.getItems().get(position).getSelect().dispatch();
  }

  // Private implementation.

  private Runnable updateItems = new Runnable() {
    @Override
    public void run() {
      if (getCount() > 0) clear();
      for (MenuItemNode item : root.getItems()) {
        add(item.getTitle());
      }
    }
  };

  private MenuNode root;
}
