// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class PerformanceService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class EchoCallback {
    public abstract void handle(int result);
  }

  public static native int echo(int n);
  public static native void echoAsync(int n, EchoCallback callback);

  public static abstract class CountTreeNodesCallback {
    public abstract void handle(int result);
  }

  public static native int countTreeNodes(TreeNodeBuilder node);
  public static native void countTreeNodesAsync(TreeNodeBuilder node, CountTreeNodesCallback callback);

  public static abstract class BuildTreeCallback {
    public final java.lang.Class returnType = TreeNode.class;
    public abstract void handle(TreeNode result);
  }

  public static native TreeNode buildTree(int n);
  public static native void buildTreeAsync(int n, BuildTreeCallback callback);
}
