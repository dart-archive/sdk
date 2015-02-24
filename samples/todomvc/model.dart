// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library todomvc.model;

// Very simple model for a collection of TODO items.

class Item {
  String title;
  bool done = false;
  Item(this.title);
}

class Model {
  List<Item> todos;

  Model() : todos = new List<Item>();

  void createItem(String title) {
    assert(title.isNotEmpty);
    Item item = new Item(title);
    todos.add(item);
  }

  void deleteItem(int id) {
    if (id < todos.length) {
      todos.removeAt(id);
    }
  }

  void completeItem(int id) {
    if (id < todos.length) {
      todos[id].done = true;
    }
  }

  void clearItems() {
    todos.removeWhere((item) => item.done);
  }

}
