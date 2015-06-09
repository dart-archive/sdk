// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

class StackFrame {
  final int functionId;
  final int bytecodePointer;
  final FletchCompiler compiler;
  final Session session;
  final bool isBelowMain;
  final bool isInternal;

  StackFrame(int functionId, this.bytecodePointer, FletchCompiler compiler,
             this.session, this.isBelowMain)
      : this.functionId = functionId,
        this.compiler = compiler,
        isInternal =
            compiler.lookupFletchFunctionBuilder(functionId).isParameterStub;

  String invokeString(Bytecode bytecode) {
    if (bytecode is InvokeMethod) {
      String name =
          compiler.lookupFunctionNameBySelector(bytecode.uint32Argument0);
      return ' ($name)';
    }
    return '';
  }

  bool get isVisible {
    return session.showInternalFrames || !(isInternal || isBelowMain);
  }

  void list() {
    print(compiler.sourceListString(functionId, bytecodePointer - 1));
  }

  void disasm() {
    var bytecodes = compiler.lookupFunctionBytecodes(functionId);
    var offset = 0;
    for (var i = 0; i  < bytecodes.length; i++) {
      var source = compiler.astString(functionId, offset);
      var current = bytecodes[i];
      var byteNumberString = '$offset'.padLeft(4);
      var invokeInfo = invokeString(current);
      var bytecodeString = '$byteNumberString $current$invokeInfo';
      var sourceString = '// $source';
      var printString = bytecodeString.padRight(30) + sourceString;
      offset += current.size;
      var marker = (offset == bytecodePointer) ? '>' : ' ';
      print("  $marker$printString");
    }
    print('');
  }

  String shortString(int maxNameLength) {
    String name = compiler.lookupFunctionName(functionId);
    String astString =
        compiler.astString(functionId, bytecodePointer - 1);
    astString = (astString != null) ? '@$astString' : '';

    return '${name.padRight(maxNameLength)}\t$astString';
  }

  SourceLocation sourceLocation() {
    return compiler.sourceLocation(functionId, bytecodePointer - 1);
  }

  ScopeInfo scopeInfo() {
    return compiler.scopeInfo(functionId, bytecodePointer - 1);
  }

  bool isSameSourceLocation(int offset,
                            SourceLocation current) {
    SourceLocation location = compiler.sourceLocation(functionId, offset);
    // Treat locations for which we have no source information as the same
    // as the previous location.
    if (location == null || location.node == null) return true;
    return location.isSameSourceLevelLocationAs(current);
  }

  int stepBytecodePointer(SourceLocation current) {
    var bytecodes = compiler.lookupFunctionBytecodes(functionId);
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
}

class StackTrace {
  final List<StackFrame> stackFrames;

  List<int> visibleFrameMapping;
  int framesToGo;
  int maxNameLength = 0;

  StackTrace(int framesToGo)
      : this.framesToGo = framesToGo,
        stackFrames = new List(framesToGo);

  int get frames => stackFrames.length;

  void addFrame(FletchCompiler compiler, StackFrame frame) {
    stackFrames[--framesToGo] = frame;
    String name = compiler.lookupFunctionName(frame.functionId);
    var nameLength = name == null ? 0 : name.length;
    if (nameLength > maxNameLength) maxNameLength = nameLength;
  }

  String shortStringForFrame(int frame) {
    return stackFrames[frame].shortString(maxNameLength);
  }

  void write(int currentFrame) {
    assert(framesToGo == 0);
    print("Stack trace:");
    var frameNumber = 0;
    for (var i = 0; i < stackFrames.length; i++) {
      if (!stackFrames[i].isVisible) continue;
      var marker = currentFrame == frameNumber ? '> ' : '  ';
      var line = shortStringForFrame(i);
      String frameNumberString = '${frameNumber++}: '.padLeft(3);
      print('$marker$frameNumberString$line');
    }
  }

  // Map user visible frame numbers to actual frame numbers.
  int actualFrameNumber(int visibleFrameNumber) {
    if (visibleFrameMapping == null) {
      visibleFrameMapping = [];
      for (int i = 0; i < stackFrames.length; i++) {
        if (stackFrames[i].isVisible) visibleFrameMapping.add(i);
      }
    }
    return (visibleFrameNumber < visibleFrameMapping.length)
        ? visibleFrameMapping[visibleFrameNumber]
        : -1;
  }

  StackFrame visibleFrame(int frame) {
    return stackFrames[actualFrameNumber(frame)];
  }

  void visibilityChanged() {
    visibleFrameMapping = null;
  }

  void list(int frame) {
    visibleFrame(frame).list();
  }

  void disasm(int frame) {
    visibleFrame(frame).disasm();
  }

  SourceLocation sourceLocation() {
    return stackFrames[0].sourceLocation();
  }

  ScopeInfo scopeInfo(int frame) {
    return visibleFrame(frame).scopeInfo();
  }

  int stepBytecodePointer(SourceLocation location) {
    return stackFrames[0].stepBytecodePointer(location);
  }

  int get bytecodePointer => stackFrames[0].bytecodePointer;

  int get methodId => stackFrames[0].functionId;
}
