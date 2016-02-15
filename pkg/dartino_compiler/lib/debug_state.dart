// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino.debug_state;

import 'bytecodes.dart';
import 'dartino_system.dart';
import 'incremental/dartino_compiler_incremental.dart';
import 'vm_session.dart';
import 'src/debug_info.dart';
import 'src/class_debug_info.dart';

import 'vm_commands.dart' show
    DartValue,
    InstanceStructure;

import 'src/hub/session_manager.dart' show
    SessionState;

import 'dartino_class.dart' show
    DartinoClass;

part 'back_trace.dart';

/// A representation of a remote object.
abstract class RemoteObject {
  String name;

  RemoteObject(this.name);
}

/// A representation of a remote instance.
class RemoteInstance extends RemoteObject {
  /// An [InstanceStructure] describing the remote instance.
  final InstanceStructure instance;

  /// The fields as [DartValue]s of the remote instance.
  final List<DartValue> fields;

  RemoteInstance(this.instance, this.fields, {String name}) : super(name);
}

/// A representation of a remote primitive value (i.e. used for non-instances).
class RemoteValue extends RemoteObject {
  /// A [DartValue] describing the remote object.
  final DartValue value;

  RemoteValue(this.value, {String name}) : super(name);
}

class Breakpoint {
  final String methodName;
  final int bytecodeIndex;
  final int id;
  Breakpoint(this.methodName, this.bytecodeIndex, this.id);
  String toString() => "id: '$id' method: '$methodName' "
      "bytecode index: '$bytecodeIndex'";
}

class DebugState {
  final Session session;

  final Map<int, Breakpoint> breakpoints = <int, Breakpoint>{};
  final Map<DartinoFunction, DebugInfo> debugInfos =
      <DartinoFunction, DebugInfo>{};
  final Map<DartinoClass, ClassDebugInfo> classDebugInfos =
      <DartinoClass, ClassDebugInfo>{};

  bool showInternalFrames = false;
  bool verbose = true;
  BackTraceFrame _topFrame;
  RemoteObject currentUncaughtException;
  BackTrace _currentBackTrace;
  int currentFrame = 0;
  SourceLocation _currentLocation;

  DebugState(this.session);

  void reset() {
    _topFrame = null;
    currentUncaughtException = null;
    _currentBackTrace = null;
    _currentLocation = null;
    currentFrame = 0;
  }

  int get actualCurrentFrameNumber {
    return currentBackTrace.actualFrameNumber(currentFrame);
  }

  ScopeInfo get currentScopeInfo {
    return currentBackTrace.scopeInfo(currentFrame);
  }

  SourceLocation get currentLocation => _currentLocation;

  BackTrace get currentBackTrace => _currentBackTrace;

  void set currentBackTrace(BackTrace backTrace) {
    _currentLocation = backTrace.sourceLocation();
    _topFrame = backTrace.frames[0];
    _currentBackTrace = backTrace;
  }

  BackTraceFrame get topFrame => _topFrame;

  void set topFrame(BackTraceFrame frame) {
    _currentLocation = frame.sourceLocation();
    _topFrame = frame;
  }

  DebugInfo getDebugInfo(DartinoFunction function) {
    return debugInfos.putIfAbsent(function, () {
      return session.compiler.createDebugInfo(function, session.dartinoSystem);
    });
  }

  ClassDebugInfo getClassDebugInfo(DartinoClass klass) {
    return classDebugInfos.putIfAbsent(klass, () {
      return session.compiler.createClassDebugInfo(klass);
    });
  }

  String lookupFieldName(DartinoClass klass, int field) {
    while (field < klass.superclassFields) {
      klass = session.dartinoSystem.lookupClassById(klass.superclassId);
    }
    return getClassDebugInfo(klass).fieldNames[field - klass.superclassFields];
  }

  bool atLocation(SourceLocation previous) {
    return (!topFrame.isVisible ||
            currentLocation == null ||
            currentLocation.isSameSourceLevelLocationAs(previous) ||
            currentLocation.node == null);
  }

  SourceLocation sourceLocationForFrame(int frame) {
    return currentBackTrace.frames[frame].sourceLocation();
  }
}
