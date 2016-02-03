// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import dartino.DartinoApi;

public class DebugRunner implements Runnable {
  DebugRunner(int port) { this.port = port; }
  @Override public void run() { DartinoApi.WaitForDebuggerConnection(port); }
  private int port;
}
