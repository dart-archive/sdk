// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.todomvc;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;

import java.util.List;

public class TodoListAdapter extends ArrayAdapter<TodoItem> {
  private LayoutInflater inflater;

  public TodoListAdapter(Context context, List<TodoItem> items) {
    super(context, 0, items);
    inflater = LayoutInflater.from(context);
  }

  @Override
  public View getView(int position, View convertView, ViewGroup parent) {
    if (convertView == null) {
      convertView = inflater.inflate(R.layout.todo_item, parent, false);
    }
    getItem(position).populateView(convertView);
    return convertView;
  }
}
