// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

class StackFrame {
  final int functionId;
  final int bytecodePointer;
  final FletchCompiler compiler;

  StackFrame(this.functionId, this.bytecodePointer, this.compiler);

  String invokeString(Bytecode bytecode) {
    if (bytecode is InvokeMethod) {
      String name =
          compiler.lookupFunctionNameBySelector(bytecode.uint32Argument0);
      return ' ($name)';
    }
    return '';
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
  int framesToGo;
  int maxNameLength = 0;

  factory StackTrace(int numberOfFrames) {
    return new StackTrace._(numberOfFrames, new List(numberOfFrames));
  }

  StackTrace._(this.framesToGo, this.stackFrames);

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
    for (var i = 0; i < stackFrames.length; i++) {
      var marker = currentFrame == i ? '> ' : '  ';
      var line = shortStringForFrame(i);
      String frameNumberString = '$i: '.padLeft(3);
      print('$marker$frameNumberString$line');
    }
  }

  void list(int frame) {
    stackFrames[frame].list();
  }

  void disasm(int frame) {
    stackFrames[frame].disasm();
  }

  SourceLocation sourceLocation() {
    return stackFrames[0].sourceLocation();
  }

  ScopeInfo scopeInfo(int frame) {
    return stackFrames[frame].scopeInfo();
  }

  int stepBytecodePointer(SourceLocation location) {
    return stackFrames[0].stepBytecodePointer(location);
  }

  int get bytecodePointer => stackFrames[0].bytecodePointer;

  int get methodId => stackFrames[0].functionId;
}
