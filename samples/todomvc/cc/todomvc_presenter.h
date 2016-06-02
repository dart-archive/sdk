// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef TODOMVC_PRESENTER_H_
#define TODOMVC_PRESENTER_H_

#include <inttypes.h>

#include "todomvc_service.h"

typedef uint16_t event;

const uint8_t TAG_CONS_FST = 0;
const uint8_t TAG_CONS_SND = 1;
const uint8_t TAG_CONS_DELETE_EVENT = 2;
const uint8_t TAG_CONS_COMPLETE_EVENT = 3;
const uint8_t TAG_CONS_UNCOMPLETE_EVENT = 4;

void VoidCallback(void*);

class TodoMVCPresenter {
 public:
  // Async forwarding of commands to the Dart presenter.
  void createItem(char* title);
  void clearItems();

  static void dispatch(event id);

  // Synchronize with the Dart presentation model.
  void sync();

 protected:
  // Patch apply callbacks.
  virtual void enterPatch() = 0;
  virtual void enterConsFst() = 0;
  virtual void enterConsSnd() = 0;
  virtual void enterConsDeleteEvent() = 0;
  virtual void enterConsCompleteEvent() = 0;
  virtual void enterConsUncompleteEvent() = 0;
  virtual void updateNode(const Node&) = 0;

  // Default patch apply procedure.
  virtual void applyPatches(const PatchSet&);
  virtual void applyPatch(const Patch&);
};

#endif  // TODOMVC_PRESENTER_H_
