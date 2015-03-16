// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class TodoMVCService {
  public static native void Setup();
  public static native void TearDown();

  public interface CreateItemCallback {
    public void handle();
  }

  public static native void createItem(BoxedStringBuilder title);
  public static native void createItemAsync(BoxedStringBuilder title, CreateItemCallback callback);

  public interface DeleteItemCallback {
    public void handle();
  }

  public static native void deleteItem(int id);
  public static native void deleteItemAsync(int id, DeleteItemCallback callback);

  public interface CompleteItemCallback {
    public void handle();
  }

  public static native void completeItem(int id);
  public static native void completeItemAsync(int id, CompleteItemCallback callback);

  public interface UncompleteItemCallback {
    public void handle();
  }

  public static native void uncompleteItem(int id);
  public static native void uncompleteItemAsync(int id, UncompleteItemCallback callback);

  public interface ClearItemsCallback {
    public void handle();
  }

  public static native void clearItems();
  public static native void clearItemsAsync(ClearItemsCallback callback);

  public interface SyncCallback {
    public void handle(PatchSet result);
  }

  public static native PatchSet sync();
  public static native void syncAsync(SyncCallback callback);

  public interface ResetCallback {
    public void handle();
  }

  public static native void reset();
  public static native void resetAsync(ResetCallback callback);
}
