// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.dartino.todomvc;

import android.view.View;
import android.widget.CheckBox;
import android.widget.TextView;

import dartino.TodoMVCService;

public class TodoItem {
  public String title;
  public boolean status;

  private int deleteEvent;
  private int completeEvent;
  private int uncompleteEvent;

  TodoItem(String title, boolean status, int deleteEvent, int completeEvent, int uncompleteEvent) {
    this.title = title;
    this.status = status;
    this.deleteEvent = deleteEvent;
    this.completeEvent = completeEvent;
    this.uncompleteEvent = uncompleteEvent;
  }

  public boolean done() {
    return status;
  }

  public void dispatchDeleteEvent() {
    TodoMVCPresenter.dispatch(deleteEvent);
  }

  public void dispatchCompleteEvent() {
    TodoMVCPresenter.dispatch(completeEvent);
  }

  public void dispatchUncompleteEvent() { TodoMVCPresenter.dispatch(uncompleteEvent); }

  public void setDeleteEvent(int deleteEvent) {
    this.deleteEvent = deleteEvent;
  }

  public void setCompleteEvent(int completeEvent) {
    this.completeEvent = completeEvent;
  }

  public void setUncompleteEvent(int uncompleteEvent) {
    this.uncompleteEvent = uncompleteEvent;
  }

  public void populateView(View view) {
    ((TextView) view.findViewById(R.id.todo_title)).setText(title);
    CheckBox box = (CheckBox) view.findViewById(R.id.todo_status);
    box.setChecked(status);
  }
}
