// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Construction and transformation utilities.

import 'todomvc_presenter_model.dart';

Bool truth(bool value, [previous]) =>
    (previous is Bool && previous.value == value) ? previous : new Bool(value);

Str str(String value, [previous]) =>
    (previous is Str && previous.value == value) ? previous : new Str(value);

Nil nil([previous]) => (previous is Nil) ? previous : new Nil();

Cons cons(fst, snd, [deleteEvent, completeEvent, uncompleteEvent, previous]) {
  if (previous is Cons) {
    bool equal = true;
    if (fst == previous.fst) {
      fst = previous.fst;
    } else {
      equal = false;
    }
    if (snd == previous.snd) {
      snd = previous.snd;
    } else {
      equal = false;
    }
    if (deleteEvent == previous.deleteEvent) {
      deleteEvent = previous.deleteEvent;
    } else {
      equal = false;
    }
    if (completeEvent == previous.completeEvent) {
      completeEvent = previous.completeEvent;
    } else {
      equal = false;
    }
    if (uncompleteEvent == previous.uncompleteEvent) {
      uncompleteEvent = previous.uncompleteEvent;
    } else {
      equal = false;
    }
    if (equal) {
      return previous;
    }
  }
  return new Cons(fst, snd, deleteEvent, completeEvent, uncompleteEvent);
}

Immutable getConsFst(Immutable node) => (node is Cons) ? node.fst : null;
Immutable getConsSnd(Immutable node) => (node is Cons) ? node.snd : null;
