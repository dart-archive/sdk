// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.debug_state;

import 'dart:async';
import 'dart:convert';

import 'bytecodes.dart';
import 'compiler.dart' show FletchCompiler;
import 'session.dart';
import 'fletch_system.dart';
import 'src/debug_info.dart';
import 'src/class_debug_info.dart';

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
  final Map<FletchFunction, DebugInfo> debugInfos =
      <FletchFunction, DebugInfo>{};
  final Map<FletchClass, ClassDebugInfo> classDebugInfos =
      <FletchClass, ClassDebugInfo>{};

  bool showInternalFrames = false;

  final Session session;

  DebugState(this.session);

  DebugInfo getDebugInfo(FletchFunction function) {
    return debugInfos.putIfAbsent(function, () {
      return session.compiler.createDebugInfo(function);
    });
  }

  ClassDebugInfo getClassDebugInfo(FletchClass klass) {
    return classDebugInfos.putIfAbsent(klass, () {
      return session.compiler.createClassDebugInfo(klass);
    });
  }

  String lookupFieldName(FletchClass klass, int field) {
    while (field < klass.superclassFields) {
      klass = session.fletchSystem.lookupClass(klass.superclassId);
    }
    return getClassDebugInfo(klass).fieldNames[field - klass.superclassFields];
  }
}
