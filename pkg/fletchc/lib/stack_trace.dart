// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

class StackFrame {
  final int functionId;
  final int bytecodePointer;

  StackFrame(this.functionId, this.bytecodePointer);

  String invokeString(FletchCompiler compiler, Bytecode bytecode) {
    if (bytecode is InvokeMethod) {
      String name =
          compiler.lookupFunctionNameBySelector(bytecode.uint32Argument0);
      return ' ($name)';
    }
    return '';
  }

  void list(FletchCompiler compiler) {
    print(compiler.sourceListString(functionId, bytecodePointer - 1));
  }

  void disasm(FletchCompiler compiler) {
    var bytecodes = compiler.lookupFunctionBytecodes(functionId);
    var offset = 0;
    for (var i = 0; i  < bytecodes.length; i++) {
      var source = compiler.astString(functionId, offset);
      var current = bytecodes[i];
      var byteNumberString = '$offset'.padLeft(4);
      var invokeInfo = invokeString(compiler, current);
      var bytecodeString = '$byteNumberString $current$invokeInfo';
      var sourceString = '// $source';
      var printString = bytecodeString.padRight(30) + sourceString;
      offset += current.size;
      var marker = (offset == bytecodePointer) ? '>' : ' ';
      print("  $marker$printString");
    }
    print('');
  }

  String shortString(FletchCompiler compiler, int frameNumber, maxNameLength) {
    String name = compiler.lookupFunctionName(functionId);
    String astString =
        compiler.astString(functionId, bytecodePointer - 1);
    astString = (astString != null) ? '@$astString' : '';
    return '  $frameNumber: ${name.padRight(maxNameLength)}\t$astString';
  }

  SourceLocation sourceLocation(FletchCompiler compiler) {
    return compiler.sourceLocation(functionId, bytecodePointer - 1);
  }

  ScopeInfo scopeInfo(FletchCompiler compiler) {
    return compiler.scopeInfo(functionId, bytecodePointer - 1);
  }

  bool isSameSourceLocation(FletchCompiler compiler,
                            int offset,
                            SourceLocation current) {
    SourceLocation location = compiler.sourceLocation(functionId, offset);
    // Treat locations for which we have no source information as the same
    // as the previous location.
    if (location == null || location.node == null) return true;
    return location == current;
  }

  int stepBytecodePointer(FletchCompiler compiler, SourceLocation current) {
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
           isSameSourceLocation(compiler, offset, current)) {
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

  void addFrame(compiler, StackFrame frame) {
    stackFrames[--framesToGo] = frame;
    String name = compiler.lookupFunctionName(frame.functionId);
    var nameLength = name == null ? 0 : name.length;
    if (nameLength > maxNameLength) maxNameLength = nameLength;
  }

  void write(FletchCompiler compiler, int currentFrame) {
    assert(framesToGo == 0);
    print("Stack trace:");
    for (var i = 0; i < stackFrames.length; i++) {
      var marker = currentFrame == i ? '> ' : '  ';
      var line = stackFrames[i].shortString(compiler, i, maxNameLength);
      print('$marker$line');
    }
  }

  void list(FletchCompiler compiler, int frame) {
    stackFrames[frame].list(compiler);
  }

  void disasm(FletchCompiler compiler, int frame) {
    stackFrames[frame].disasm(compiler);
  }

  SourceLocation sourceLocation(FletchCompiler compiler) {
    return stackFrames[0].sourceLocation(compiler);
  }

  ScopeInfo scopeInfo(FletchCompiler compiler, int frame) {
    return stackFrames[frame].scopeInfo(compiler);
  }

  int stepBytecodePointer(FletchCompiler compiler, SourceLocation location) {
    return stackFrames[0].stepBytecodePointer(compiler, location);
  }

  int get bytecodePointer => stackFrames[0].bytecodePointer;

  int get methodId => stackFrames[0].functionId;
}
