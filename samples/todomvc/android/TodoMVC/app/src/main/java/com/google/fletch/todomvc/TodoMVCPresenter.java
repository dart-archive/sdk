// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.todomvc;

import fletch.MessageBuilder;
import fletch.Node;
import fletch.Patch;
import fletch.PatchList;
import fletch.PatchSet;
import fletch.StrBuilder;
import fletch.TodoMVCService;
import fletch.Uint8List;
import fletch.Uint8ListBuilder;

abstract class TodoMVCPresenter {
  abstract protected void enterPatch();
  abstract protected void enterConsFst();
  abstract protected void enterConsSnd();
  abstract protected void updateNode(Node node);

  static final int TAG_CONS_FST = 0;
  static final int TAG_CONS_SND = 1;

  public void createItem(String title) {
    int length = title.length();
    int messageSize = 48 + StrBuilder.kSize + length;
    MessageBuilder builder = new MessageBuilder(messageSize);
    StrBuilder str = new StrBuilder();
    builder.initRoot(str, StrBuilder.kSize);
    Uint8ListBuilder chars = str.initChars(length);
    for (int i = 0; i < length; ++i) {
      chars.set(i, title.charAt(i));
    }
    TodoMVCService.createItem(str);
  }

  public void deleteItem(int id) {
    TodoMVCService.deleteItemAsync(id, new TodoMVCService.DeleteItemCallback() {
      @Override
      public void handle() { }
    });
  }

  public void completeItem(int id) {
    TodoMVCService.completeItemAsync(id, new TodoMVCService.CompleteItemCallback() {
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
        default: throw new RuntimeException("Invalid patch tag");
      }
    }
    updateNode(patch.getContent());
  }
}
