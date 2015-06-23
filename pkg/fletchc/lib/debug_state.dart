// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.debug_state;

import 'dart:async';
import 'dart:convert';

import 'bytecodes.dart';
import 'compiler.dart' show FletchCompiler;
import 'session.dart';
import 'src/debug_info.dart';

part 'stack_trace.dart';

class Breakpoint {
  final String methodName;
  final int bytecodeIndex;
  final int id;
  Breakpoint(this.methodName, this.bytecodeIndex, this.id);
  String toString() => "$id: $methodName @$bytecodeIndex";
}

class DebugState {
  final Map<int, Breakpoint> breakpoints = <int, Breakpoint>{};
  final Map<int, DebugInfo> debugInfos = <int, DebugInfo>{};

  bool showInternalFrames = false;

  final Session session;

  DebugState(this.session);

  DebugInfo getDebugInfo(int functionId) {
    return debugInfos.putIfAbsent(functionId, () {
      return session.compiler.createDebugInfo(functionId);
    });
  }
}
