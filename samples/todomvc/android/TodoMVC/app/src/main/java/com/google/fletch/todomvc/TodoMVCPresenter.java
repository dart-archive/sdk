// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.todomvc;

import java.lang.Override;

import fletch.BoxedStringBuilder;
import fletch.MessageBuilder;
import fletch.Node;
import fletch.Patch;
import fletch.PatchList;
import fletch.PatchSet;
import fletch.TodoMVCService;
import fletch.Uint8List;
import fletch.Uint8ListBuilder;

abstract class TodoMVCPresenter {
  abstract protected void enterPatch();
  abstract protected void enterConsFst();
  abstract protected void enterConsSnd();
  abstract protected void enterConsDeleteEvent();
  abstract protected void enterConsCompleteEvent();
  abstract protected void enterConsUncompleteEvent();
  abstract protected void updateNode(Node node);

  static final int TAG_CONS_FST = 0;
  static final int TAG_CONS_SND = 1;
  static final int TAG_CONS_DELETE_EVENT = 2;
  static final int TAG_CONS_COMPLETE_EVENT = 3;
  static final int TAG_CONS_UNCOMPLETE_EVENT = 4;

  public void createItem(String title) {
    int length = title.length();
    int messageSize = 48 + BoxedStringBuilder.kSize + length;
    MessageBuilder builder = new MessageBuilder(messageSize);
    BoxedStringBuilder box = new BoxedStringBuilder();
    builder.initRoot(box, BoxedStringBuilder.kSize);
    box.setStr(title);
    TodoMVCService.createItem(box);
  }

  static public void dispatch(int id) {
    TodoMVCService.dispatchAsync(id, new TodoMVCService.DispatchCallback() {
      @Override
      public void handle() { }
    });
  }

  public void applyPatches(PatchSet patchSet) {
    PatchList patches = patchSet.getPatches();
    for (int i = 0; i < patches.size(); ++i) {
      applyPatch(patches.get(i));
    }
  }

  private void applyPatch(Patch patch) {
    enterPatch();
    Uint8List path = patch.getPath();
    for (int i = 0; i < path.size(); ++i) {
      switch (path.get(i)) {
        case TAG_CONS_FST: enterConsFst(); break;
        case TAG_CONS_SND: enterConsSnd(); break;
        case TAG_CONS_DELETE_EVENT: enterConsDeleteEvent(); break;
        case TAG_CONS_COMPLETE_EVENT: enterConsCompleteEvent(); break;
        case TAG_CONS_UNCOMPLETE_EVENT: enterConsUncompleteEvent(); break;
        default: throw new RuntimeException("Invalid patch tag");
      }
    }
    updateNode(patch.getContent());
  }
}
