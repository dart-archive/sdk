// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.todomvc;

import android.view.View;
import android.widget.CheckBox;
import android.widget.TextView;

public class TodoItem {
  public String title;
  public boolean status;

  TodoItem(String title, boolean status) {
    this.title = title;
    this.status = status;
  }

  public boolean done() {
    return status;
  }

  public void populateView(View view) {
    ((TextView) view.findViewById(R.id.todo_title)).setText(title);
    CheckBox box = (CheckBox) view.findViewById(R.id.todo_status);
    box.setChecked(status);
  }
}
