// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'model.dart';
import 'dart/todomvc_presenter.dart';
import 'dart/todomvc_presenter_model.dart';

import 'dart/presentation_graph.dart' as node;

class ItemPair {
  final Item item;
  final Immutable presentation;
  ItemPair(this.item, this.presentation);
}

class TodoMVCImpl extends TodoMVCPresenter {

  Model _model = new Model();

  TodoMVCImpl() {
    _model.createItem("My default todo");
    _model.createItem("Some other todo");
  }

  void createItem(title) {
    _model.createItem(title.str);
  }

  void deleteItem(int id) {
    _model.deleteItem(id);
  }

  void completeItem(int id) {
    _model.completeItem(id);
  }

  void uncompleteItem(int id) {
    _model.uncompleteItem(id);
  }

  void clearItems() {
    _model.clearItems();
  }

  // Cache of previously drawn items.
  // TODO(zerny): use a map once we have a proper implementation.
  List<ItemPair> _cachePrevious = new List();
  List<ItemPair> _cacheCurrent = new List();

  Immutable _lookup(Item item, int index) {
    // Look for a cached item in the range [index; index + 1]
    for (var i = 0; i < 2; ++i) {
      var j = index + i;
      if (j >= _cachePrevious.length) return null;
      ItemPair cached = _cachePrevious[j];
      if (cached.item == item) return cached.presentation;
    }
    return null;
  }

  void _add(int index, Item item, Immutable presentation) {
    _cacheCurrent[index] = new ItemPair(item, presentation);
  }

  Immutable render(previous) {
    // Swap previous and current cache and resize current to model-item count.
    var tmp = _cachePrevious;
    tmp.length = _model.todos.length;
    _cachePrevious = _cacheCurrent;
    _cacheCurrent = tmp;
    return _renderList(0, previous);
  }

  Immutable _renderList(int index, Immutable previous) =>
    (index == _model.todos.length)
      ? node.nil(previous)
      : node.cons(
          _renderItemFromCache(index, node.getConsFst(previous)),
          _renderList(index + 1, node.getConsSnd(previous)),
          null,
          null,
          null,
          previous);

  Immutable _renderItemFromCache(int index, Immutable previous) {
    Item item = _model.todos[index];
    Cons cached = _lookup(item, index);
    Immutable current = (cached == null)
        ? _renderItem(item, previous)
        : node.cons(
              node.str(item.title, cached.fst),
              node.bool(item.done, cached.snd),
              // Reuse the handlers since we know that item is the same as the
              // item used for the creating the cached handlers.
              cached.deleteEvent,
              cached.completeEvent,
              cached.uncompleteEvent,
              cached);
    _add(index, item, current);
    return current;
  }

  Immutable _renderItem(Item item, Immutable previous) =>
    node.cons(
        node.str(item.title, node.getConsFst(previous)),
        node.bool(item.done, node.getConsSnd(previous)),
        new EventHandler(() { _model.todos.remove(item); }),
        new EventHandler(item.complete),
        new EventHandler(item.uncomplete));
}
