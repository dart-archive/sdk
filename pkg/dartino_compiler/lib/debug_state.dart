// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino.debug_state;

import 'bytecodes.dart';
import 'dartino_system.dart';
import 'incremental/dartino_compiler_incremental.dart';
import 'vm_context.dart';
import 'src/debug_info.dart';
import 'src/class_debug_info.dart';

import 'vm_commands.dart' show
    Array,
    ArrayStructure,
    DartValue,
    InstanceStructure;

import 'dartino_class.dart' show
    DartinoClass;

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

/// A representation of a remote instance.
// TODO(sigurdm): Send partial arrays when they are very big. See issue #536.
class RemoteArray extends RemoteObject {
  /// An [Array] describing the remote instance.
  final ArrayStructure array;

  /// The values of the array as [DartValue]s of the remote instance.
  final List<DartValue> values;

  RemoteArray(this.array, this.values, {String name}) : super(name);
}

/// A representation of a remote primitive value (i.e. used for non-instances).
class RemoteValue extends RemoteObject {
  /// A [DartValue] describing the remote object.
  final DartValue value;

  RemoteValue(this.value, {String name}) : super(name);
  bool get isError => false;
}

/// A representation of a failure to retrieve a remote object.
class RemoteErrorObject extends RemoteObject {
  String message;
  RemoteErrorObject(this.message, {String name}) : super(name);

}

class Breakpoint {
  final DartinoFunction function;
  final int bytecodeIndex;
  final int id;
  String get methodName => function.name;

  Breakpoint(this.function, this.bytecodeIndex, this.id);

  String locationString(DebugState state) {
    return state.getDebugInfo(function).fileAndLineStringFor(bytecodeIndex);
  }

  SourceLocation location(DebugState state) {
    return state.getDebugInfo(function).locationFor(bytecodeIndex);
  }

  String toString() => "id: '$id' method: '$methodName' "
      "bytecode index: '$bytecodeIndex'";
}

class BackTraceFrame {
  final DartinoFunction function;
  final int bytecodePointer;
  final IncrementalCompiler compiler;
  final DebugState debugState;

  BackTraceFrame(this.function, this.bytecodePointer, this.compiler,
      this.debugState);

  bool get inPlatformLibrary => function.element.library.isPlatformLibrary;

  bool get isInternal => function.isInternal || inPlatformLibrary;

  String invokeString(Bytecode bytecode) {
    if (bytecode is InvokeMethod) {
      String name =
      compiler.lookupFunctionNameBySelector(bytecode.uint32Argument0);
      return ' ($name)';
    }
    return '';
  }

  bool get isVisible => debugState.showInternalFrames || !isInternal;

  DebugInfo get debugInfo => debugState.getDebugInfo(function);

  String list({bool colorsDisabled, int contextLines: 5}) {
    return debugInfo.sourceListStringFor(
        bytecodePointer - 1,
        contextLines: contextLines,
        colorsDisabled: colorsDisabled);
  }

  String disasm() {
    StringBuffer buffer = new StringBuffer();
    var bytecodes = function.bytecodes;
    var offset = 0;
    for (var bytecode in bytecodes) offset += bytecode.size;
    int offsetLength = '$offset'.length;
    offset = 0;
    for (var i = 0; i  < bytecodes.length; i++) {
      var source = debugInfo.astStringFor(offset);
      var current = bytecodes[i];
      var byteNumberString = '$offset:'.padLeft(offsetLength);
      var invokeInfo = invokeString(current);
      var bytecodeString = '$byteNumberString $current$invokeInfo';
      var sourceString = '// $source';
      var printString = bytecodeString.padRight(30) + sourceString;
      offset += current.size;
      var marker = (offset == bytecodePointer) ? '* ' : '  ';
      buffer.writeln("$marker$printString");
    }
    return buffer.toString();
  }

  String shortString([int namePadding = 0]) {
    String name = compiler.lookupFunctionName(function);
    String astString = debugInfo.astStringFor(bytecodePointer - 1);
    astString = (astString != null) ? '@$astString' : '';

    String paddedName = name.padRight(namePadding);
    String spaces = '';
    if (astString.isNotEmpty) {
      int missingSpaces = 4 - (paddedName.length % 4);
      spaces = ' ' * missingSpaces;
    }

    return '$paddedName$spaces$astString';
  }

  SourceLocation sourceLocation() {
    return debugInfo.sourceLocationFor(bytecodePointer - 1);
  }

  ScopeInfo scopeInfo() {
    return debugInfo.scopeInfoFor(bytecodePointer - 1);
  }

  bool isSameSourceLocation(int offset,
      SourceLocation current) {
    SourceLocation location = debugInfo.sourceLocationFor(offset);
    // Treat locations for which we have no source information as the same
    // as the previous location.
    if (location == null || location.node == null) return true;
    return location.isSameSourceLevelLocationAs(current);
  }

  int stepBytecodePointer(SourceLocation current) {
    var bytecodes = function.bytecodes;
    // Zip forward to the current bytecode. The bytecode pointer in the stack
    // frame is the return address which is one bytecode after the current one.
    var offset = 0;
    var i = 0;
    for (; i < bytecodes.length; i++) {
      var currentSize = bytecodes[i].size;
      if (offset + currentSize == bytecodePointer) break;
      offset += currentSize;
    }
    // Move forward while we know step should not stop.
    while (!bytecodes[i].isBranching &&
        isSameSourceLocation(offset, current)) {
      offset += bytecodes[i++].size;
    }
    return offset <= bytecodePointer ? -1 : offset;
  }

  int get functionId => function.functionId;
}

class BackTrace {
  final List<BackTraceFrame> frames;
  final DebugState debugState;

  List<int> visibleFrameMapping;
  int framesToGo;
  int maxNameLength = 0;

  BackTrace(int framesToGo, this.debugState)
      : this.framesToGo = framesToGo,
        frames = new List(framesToGo);

  int get length => frames.length;

  int get visibleFrames {
    ensureVisibleFrameMap();
    return visibleFrameMapping.length;
  }

  void addFrame(IncrementalCompiler compiler, BackTraceFrame frame) {
    frames[--framesToGo] = frame;
    String name = compiler.lookupFunctionName(frame.function);
    var nameLength = name == null ? 0 : name.length;
    if (nameLength > maxNameLength) maxNameLength = nameLength;
  }

  String format([int frame]) {
    int currentFrame = frame != null ? frame : debugState.currentFrame;
    StringBuffer buffer = new StringBuffer();
    assert(framesToGo == 0);
    int frameNumber = 0;
    int frameNumberLength = '$frameNumber'.length;
    for (var i = 0; i < frames.length; i++) {
      if (!frames[i].isVisible) continue;
      var marker = currentFrame == frameNumber ? '* ' : '  ';
      var line = frames[i].shortString(maxNameLength);
      String frameNumberString =
      '${frameNumber++}: '.padLeft(frameNumberLength);
      buffer.writeln('$marker$frameNumberString$line');
    }
    return buffer.toString();
  }

  void ensureVisibleFrameMap() {
    if (visibleFrameMapping == null) {
      visibleFrameMapping = [];
      for (int i = 0; i < frames.length; i++) {
        if (frames[i].isVisible) visibleFrameMapping.add(i);
      }
    }
  }

  // Map user visible frame numbers to actual frame numbers.
  int actualFrameNumber(int visibleFrameNumber) {
    ensureVisibleFrameMap();
    return (visibleFrameNumber < visibleFrameMapping.length)
        ? visibleFrameMapping[visibleFrameNumber]
        : -1;
  }

  BackTraceFrame visibleFrame(int frame) {
    int frameNumber = actualFrameNumber(frame);
    if (frameNumber == -1) return null;
    return frames[frameNumber];
  }

  void visibilityChanged() {
    visibleFrameMapping = null;
  }

  String list({int frame, bool colorsDisabled}) {
    if (frame == null) frame = debugState.currentFrame;
    BackTraceFrame visibleStackFrame = visibleFrame(frame);
    if (visibleStackFrame == null) return null;
    return visibleStackFrame.list(colorsDisabled: colorsDisabled);
  }

  String disasm([int frame]) {
    if (frame == null) frame = debugState.currentFrame;
    BackTraceFrame visibleStackFrame = visibleFrame(frame);
    if (visibleStackFrame == null) return null;
    return visibleStackFrame.disasm();
  }

  SourceLocation sourceLocation() {
    return frames[0].sourceLocation();
  }

  ScopeInfo scopeInfo(int frame) {
    BackTraceFrame visibleStackFrame = visibleFrame(frame);
    if (visibleStackFrame == null) return null;
    return visibleStackFrame.scopeInfo();
  }

  ScopeInfo get scopeInfoForCurrentFrame => scopeInfo(debugState.currentFrame);

  int stepBytecodePointer(SourceLocation location) {
    return frames[0].stepBytecodePointer(location);
  }
}

class DebugState {
  final DartinoVmContext vmContext;

  final Map<int, Breakpoint> breakpoints = <int, Breakpoint>{};
  final Map<DartinoFunction, DebugInfo> debugInfos =
      <DartinoFunction, DebugInfo>{};
  final Map<DartinoClass, ClassDebugInfo> classDebugInfos =
      <DartinoClass, ClassDebugInfo>{};

  bool showInternalFrames = false;
  int currentProcess = -1;
  BackTraceFrame _topFrame;
  RemoteObject currentUncaughtException;
  BackTrace _currentBackTrace;
  int currentFrame = 0;
  SourceLocation _currentLocation;

  DebugState(this.vmContext);

  void reset() {
    currentProcess = -1;
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
      return vmContext.compiler.createDebugInfo(
          function, vmContext.dartinoSystem);
    });
  }

  ClassDebugInfo getClassDebugInfo(DartinoClass klass) {
    return classDebugInfos.putIfAbsent(klass, () {
      return vmContext.compiler.createClassDebugInfo(klass);
    });
  }

  String lookupFieldName(DartinoClass klass, int field) {
    while (field < klass.superclassFields) {
      klass = vmContext.dartinoSystem.lookupClassById(klass.superclassId);
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
