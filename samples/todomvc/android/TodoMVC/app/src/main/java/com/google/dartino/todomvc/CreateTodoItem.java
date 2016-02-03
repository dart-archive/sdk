// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.dartino.todomvc;

import android.content.Intent;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.EditText;

public class CreateTodoItem extends ActionBarActivity {

  private EditText itemTitle;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_create_todo_item);
    itemTitle = (EditText) findViewById(R.id.new_item_text);
  }

  @Override
  public boolean onCreateOptionsMenu(Menu menu) {
    // Inflate the menu; this adds items to the action bar if it is present.
    getMenuInflater().inflate(R.menu.menu_create_todo_item, menu);
    return true;
  }

  @Override
  public boolean onOptionsItemSelected(MenuItem item) {
    switch (item.getItemId()) {
      case R.id.action_cancel:
        setResult(RESULT_CANCELED);
        finish();
        return true;
      case R.id.action_save:
        String title = itemTitle.getText().toString();
        if (!title.isEmpty()) {
          Intent intent = new Intent();
          intent.putExtra("ItemTitle", title);
          setResult(RESULT_OK, intent);
          finish();
          return true;
        }
    }

    return super.onOptionsItemSelected(item);
  }
}
