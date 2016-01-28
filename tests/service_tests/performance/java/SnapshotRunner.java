// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.FletchApi;

public class SnapshotRunner implements Runnable {
    SnapshotRunner(byte[] s) { snapshot = s; }
    public void run() { FletchApi.RunSnapshot(snapshot); }
    private byte[] snapshot;
}
