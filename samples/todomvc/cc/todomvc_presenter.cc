// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "todomvc_presenter.h"

static void VoidCallback() {}

void TodoMVCPresenter::createItem(char* title) {
  int length = 0;
  while (title[length] != '\0') ++length;
  int size = 40 + 8 + BoxedStringBuilder::kSize + length;
  MessageBuilder builder(size);
  BoxedStringBuilder box = builder.initRoot<BoxedStringBuilder>();
  box.setStr(title);
  TodoMVCService::createItemAsync(box, VoidCallback);
}

void TodoMVCPresenter::deleteItem(int id) {
  TodoMVCService::deleteItemAsync(id, VoidCallback);
}

void TodoMVCPresenter::completeItem(int id) {
  TodoMVCService::completeItemAsync(id, VoidCallback);
}

void TodoMVCPresenter::uncompleteItem(int id) {
  TodoMVCService::uncompleteItemAsync(id, VoidCallback);
}

void TodoMVCPresenter::clearItems() {
  TodoMVCService::clearItemsAsync(VoidCallback);
}

void TodoMVCPresenter::sync() {
  // Assuming a synchronous call will flush outstanding asynchronous calls.
  applyPatches(TodoMVCService::sync());
}

void TodoMVCPresenter::applyPatches(const PatchSet& patch_set) {
  List<Patch> patches = patch_set.getPatches();
  for (int i = 0; i < patches.length(); ++i) {
    applyPatch(patches[i]);
  }
}

void TodoMVCPresenter::applyPatch(const Patch& patch) {
  enterPatch();
  List<uint8_t> path = patch.getPath();
  for (int i = 0; i < path.length(); ++i) {
    switch (path[i]) {
      case TAG_CONS_FST: enterConsFst(); break;
      case TAG_CONS_SND: enterConsSnd(); break;
      default: abort();
    }
  }
  updateNode(patch.getContent());
}
