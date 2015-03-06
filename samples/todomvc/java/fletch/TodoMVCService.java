// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class TodoMVCService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class CreateItemCallback {
    public abstract void handle();
  }

  public static native void createItem(StrBuilder title);
  public static native void createItemAsync(StrBuilder title, CreateItemCallback callback);

  public static abstract class DeleteItemCallback {
    public abstract void handle();
  }

  public static native void deleteItem(int id);
  public static native void deleteItemAsync(int id, DeleteItemCallback callback);

  public static abstract class CompleteItemCallback {
    public abstract void handle();
  }

  public static native void completeItem(int id);
  public static native void completeItemAsync(int id, CompleteItemCallback callback);

  public static abstract class ClearItemsCallback {
    public abstract void handle();
  }

  public static native void clearItems();
  public static native void clearItemsAsync(ClearItemsCallback callback);

  public static abstract class SyncCallback {
    public abstract void handle(PatchSet result);
  }

  public static native PatchSet sync();
  public static native void syncAsync(SyncCallback callback);
}
