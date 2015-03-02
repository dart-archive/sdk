// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class ConformanceService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class FooCallback {
    public abstract void handle();
  }

  public static native void foo();
  public static native void fooAsync(FooCallback callback);

  public static abstract class PingCallback {
    public abstract void handle(int result);
  }

  public static native int ping();
  public static native void pingAsync(PingCallback callback);
}
