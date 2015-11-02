// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library todomvc.model;

// Very simple model for a collection of TODO items.

class Item {
  String title;
  bool _done = false;
  int _id;

  static int id_pool = 0;

  Item(this.title) {
    _id = id_pool++;
  }

  bool get done => _done;
  void complete() { _done = true; }
  void uncomplete() { _done = false; }
  int get id => _id;
}

class TodoModel {
  Map<int, Item> todos;

  TodoModel() : todos = new Map<int, Item>();

  void createItem(String title) {
    assert(title.isNotEmpty);
    Item item = new Item(title);
    todos.putIfAbsent( item.id, () => item );
  }

  void deleteItem(int id) {
    if (todos.containsKey(id)) {
      todos.remove(id);
    }
  }

  void completeItem(int id) {
    if (todos.containsKey(id)) {
      todos[id].complete();
    }
  }

  void uncompleteItem(int id) {
    if (todos.containsKey(id)) {
      todos[id].uncomplete();
    }
  }

  void clearItems() {
    List<int> toDelete = new List<int>();

    todos.forEach((k,v) {
      if (v.done) {
        toDelete.add(k);
      }
    });

    toDelete.forEach((key) {
      todos.remove(key);
    });
  }

}
