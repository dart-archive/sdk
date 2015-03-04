// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import fletch.TreeNode;
import fletch.TreeNodeBuilder;

public class PerformanceService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class EchoCallback {
    public abstract void handle(int result);
  }

  public static native int echo(int n);
  public static native void echoAsync(int n, EchoCallback callback);

  public static abstract class BuildTreeCallback {
    public abstract void handle(TreeNode result);
  }

  private static native Object buildTree_raw(int n);
  public static native void buildTreeAsync(int n, BuildTreeCallback callback);
  public static TreeNode buildTree(int n) {
    Object rawData = buildTree_raw(n);
    if (rawData instanceof byte[]) {
      return new TreeNode((byte[])rawData, 8);
    }
    return new TreeNode((byte[][])rawData, 8);
  }
}
