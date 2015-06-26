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
  final Session session;

  final Map<int, Breakpoint> breakpoints = <int, Breakpoint>{};
  final Map<FletchFunction, DebugInfo> debugInfos =
      <FletchFunction, DebugInfo>{};
  final Map<FletchClass, ClassDebugInfo> classDebugInfos =
      <FletchClass, ClassDebugInfo>{};

  bool showInternalFrames = false;
  StackFrame _topFrame;
  StackTrace _currentStackTrace;
  int currentFrame = 0;
  SourceLocation _currentLocation;

  DebugState(this.session);

  void reset() {
    _topFrame = null;
    _currentStackTrace = null;
    _currentLocation = null;
    currentFrame = 0;
  }

  int get actualCurrentFrameNumber {
    return currentStackTrace.actualFrameNumber(currentFrame);
  }

  ScopeInfo get currentScopeInfo {
    return currentStackTrace.scopeInfo(currentFrame);
  }

  SourceLocation get currentLocation => _currentLocation;

  StackTrace get currentStackTrace => _currentStackTrace;

  StackTrace set currentStackTrace(StackTrace stackTrace) {
    _currentLocation = stackTrace.sourceLocation();
    _topFrame = stackTrace.stackFrames[0];
    return _currentStackTrace = stackTrace;
  }

  StackFrame get topFrame => _topFrame;

  StackFrame set topFrame(StackFrame frame) {
    _currentLocation = frame.sourceLocation();
    _topFrame = frame;
  }

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

  bool atLocation(SourceLocation previous) {
    return (!topFrame.isVisible ||
            currentLocation == null ||
            currentLocation.isSameSourceLevelLocationAs(previous) ||
            currentLocation.node == null);
  }

  int get numberOfStackFrames => currentStackTrace.stackFrames.length;

  SourceLocation sourceLocationForFrame(int frame) {
    return currentStackTrace.stackFrames[frame].sourceLocation();
  }

  void list() {
    currentStackTrace.list(currentFrame);
  }

  void disasm() {
    currentStackTrace.disasm(currentFrame);
  }

  void printStackTrace() {
    currentStackTrace.write(currentFrame);
  }
}
