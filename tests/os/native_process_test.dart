// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.ffi';
import 'dart:fletch.io';
import 'dart:fletch.os';

import 'package:expect/expect.dart';

void main() {
  testStartDetachedValid();
  testStartDetachedNullPath();
  testStartDetachedEmptyPath();
  testStartDetachedInvalidPath();
  testStartDetachedNonExecutablePath();
}

final ForeignFunction _kill = ForeignLibrary.main.lookup('kill');

void testStartDetachedValid() {
  const SIGTERM = 15;
  int kill(int pid) => _kill.icall$2(pid, SIGTERM);

  // In debug mode tests can timeout after about 120 secs. Make sure we
  // sleep for a little more to ensure we are not failing the test because
  // sleep process exited.
  int pid = NativeProcess.startDetached('/bin/sleep', ['130']);
  Expect.notEquals(-1, pid, "Failed to start '/bin/sleep'");
  // kill fails if the pid is not found, hence it validates it was spawned.
  Expect.equals(0, kill(pid), 'Failed to kill test process with pid: $pid');
}

void testStartDetachedNullPath() {
  // No path
  Expect.throws(() => NativeProcess.startDetached(null, null),
      (e) => e == 'Empty path: Path must point to valid executable');
}

void testStartDetachedEmptyPath() {
  // Empty path
  Expect.throws(() => NativeProcess.startDetached('', null),
      (e) => e == 'Empty path: Path must point to valid executable');
}
void testStartDetachedInvalidPath() {
  // Non-existing path
  Expect.throws(() => NativeProcess.startDetached('bla', null),
      (e) => e == "Failed to start process from path 'bla'. Got errno 2");
}

void testStartDetachedNonExecutablePath() {
  // Invalid executable.
  var nonExecFile = new File.temporary('OsTest');
  Expect.throws(() => NativeProcess.startDetached(nonExecFile.path, null),
      (e) => e == "Failed to start process from path '${nonExecFile.path}'. "
                  "Got errno 13");
  File.delete(nonExecFile.path);
}
