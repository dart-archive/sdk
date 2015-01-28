// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class EchoService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class EchoCallback {
    public abstract void handle(int result);
  }

  public static native int Echo(int n);
  public static native void EchoAsync(int n, EchoCallback callback);

  public static abstract class SumCallback {
    public abstract void handle(int result);
  }

  public static native int Sum(int x, int y);
  public static native void SumAsync(int x, int y, SumCallback callback);
}
