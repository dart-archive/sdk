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

  void write(FletchCompiler compiler, int frameNumber) {
    writeName(compiler, frameNumber);
    var bytecodes = compiler.lookupFunctionBytecodes(functionId);
    var offset = 0;
    for (var i = 0; i  < bytecodes.length; i++) {
      var source = compiler.sourceString(functionId, offset);
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

  void writeName(FletchCompiler compiler, int frameNumber) {
    String name = compiler.lookupFunctionName(functionId);
    print("  $frameNumber: $name");
  }
}

class StackTrace {
  final List<StackFrame> stackFrames;
  int framesToGo;

  factory StackTrace(int numberOfFrames) {
    return new StackTrace._(numberOfFrames, new List(numberOfFrames));
  }

  StackTrace._(this.framesToGo, this.stackFrames);

  int get frames => stackFrames.length;

  void addFrame(StackFrame frame) { stackFrames[--framesToGo] = frame; }

  void write(FletchCompiler compiler, int currentFrame) {
    assert(framesToGo == 0);
    print("Stack trace:");
    for (var i = 0; i < stackFrames.length; i++) {
      if (currentFrame < 0 || currentFrame == i) {
        stackFrames[i].write(compiler, i);
      } else {
        stackFrames[i].writeName(compiler, i);
      }
    }
  }
}
