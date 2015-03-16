// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef TODOMVC_PRESENTER_H_
#define TODOMVC_PRESENTER_H_

#include <inttypes.h>

#include "todomvc_service.h"

const uint8_t TAG_CONS_FST = 0;
const uint8_t TAG_CONS_SND = 1;

class TodoMVCPresenter {
 public:
  // Async forwarding of commands to the Dart presenter.
  void createItem(char* title);
  void deleteItem(int id);
  void completeItem(int id);
  void uncompleteItem(int id);
  void clearItems();

  // Synchronize with the Dart presentation model.
  void sync();

 protected:
  // Patch apply callbacks.
  virtual void enterPatch() = 0;
  virtual void enterConsFst() = 0;
  virtual void enterConsSnd() = 0;
  virtual void updateNode(const Node&) = 0;

  // Default patch apply procedure.
  virtual void applyPatches(const PatchSet&);
  virtual void applyPatch(const Patch&);
};

#endif  // TODOMVC_PRESENTER_H_
