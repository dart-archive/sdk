// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of session;

class StackFrame {
  final Method method;
  final int bytecodePointer;

  StackFrame(this.method, this.bytecodePointer);

  void write(ProgramModel model, int frameNumber) {
    writeName(frameNumber);
    var bytecodes = method.bytecodes;
    var bcp = bytecodePointer;
    var i = 0;
    while (i < bytecodes.length) {
      var current = _bytecodes[bytecodes[i]];
      var bytecodeString = current.bytecodeToString(i, bytecodes, model);
      i += current.size;
      var marker = (i == bcp)
        ? " <---".padRight(40 - bytecodeString.length, "-") + " bcp"
        : "";
      print("    $bytecodeString$marker");
      if (current == _bytecodes.last) break;
    }
    print("");
  }

  void writeName(int frameNumber) => print("  $frameNumber: ${method.name}");
}

class StackTrace {
  final List<StackFrame> _stackFrames;
  int _framesToGo;

  factory StackTrace(int numberOfFrames) {
    return new StackTrace._internal(numberOfFrames, new List(numberOfFrames));
  }

  StackTrace._internal(this._framesToGo, this._stackFrames);

  int get frames => _stackFrames.length;

  void addFrame(StackFrame frame) { _stackFrames[--_framesToGo] = frame; }

  void write(ProgramModel model, int currentFrame) {
    assert(_framesToGo == 0);
    print("Stack trace:");
    for (var i = 0; i < _stackFrames.length; i++) {
      if (currentFrame < 0 || currentFrame == i) {
        _stackFrames[i].write(model, i);
      } else {
        _stackFrames[i].writeName(i);
      }
    }
  }
}
