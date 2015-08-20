// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import fletch.FletchApi;

public class DartDebugger implements Runnable {
  DartDebugger(int port) {
    this.port = port;
  }

  @Override
  public void run() {
    FletchApi.WaitForDebuggerConnection(port);
  }

  int port;
}
