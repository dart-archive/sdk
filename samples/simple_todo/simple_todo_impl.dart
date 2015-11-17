// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'todo_model.dart';
import 'generated/dart/simple_todo.dart';

class TodoImpl extends TodoService {
  TodoModel _model = new TodoModel();

  TodoImpl() {
    _model.createItem("Default todo.");
    _model.createItem("Another todo.");
  }

  void createItem(BoxString title) {
    _model.createItem(title.s);
  }

  void toggle(int id) {
    if (_model.todos.containsKey(id)) {
      Item item = _model.todos[id];
      if (item.done) {
	item.uncomplete();
      } else {
	item.complete();
      }
    }
  }

  void clearItems() {
    _model.clearItems();
  }

  void getItem(int index, TodoItemBuilder result) {
    Iterable<Item> items = _model.todos.values;
    if (index >= 0 && index < items.length) {
      Item item = items.elementAt(index);
      result.title = item.title;
      result.done = item.done;
      result.id = item.id;
    }
  }

  void getItemById(int id, TodoItemBuilder result) {
    if (_model.todos.containsKey(id)) {
      Item item = _model.todos[id];
      result.id = item.id;
      result.title = item.title;
      result.done = item.done;
    }
  }

  int getNoItems() {
    return _model.todos.values.length;
  }

  void deleteItem(int id) {
    _model.todos.remove(id);
  }
}
