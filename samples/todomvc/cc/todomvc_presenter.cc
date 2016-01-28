// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "todomvc_presenter.h"

void VoidCallback(void*) {}

void TodoMVCPresenter::createItem(char* title) {
  int length = 0;
  while (title[length] != '\0') ++length;
  int size = 56 + BoxedStringBuilder::kSize + length;
  MessageBuilder builder(size);
  BoxedStringBuilder box = builder.initRoot<BoxedStringBuilder>();
  box.setStr(title);
  TodoMVCService::createItemAsync(box, VoidCallback, NULL);
}

void TodoMVCPresenter::clearItems() {
  TodoMVCService::clearItemsAsync(VoidCallback, NULL);
}

void TodoMVCPresenter::dispatch(event id) {
  TodoMVCService::dispatchAsync(id, VoidCallback, NULL);
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
      case TAG_CONS_DELETE_EVENT: enterConsDeleteEvent(); break;
      case TAG_CONS_COMPLETE_EVENT: enterConsCompleteEvent(); break;
      case TAG_CONS_UNCOMPLETE_EVENT: enterConsUncompleteEvent(); break;
      default: abort();
    }
  }
  updateNode(patch.getContent());
}
