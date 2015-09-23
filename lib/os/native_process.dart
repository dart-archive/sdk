// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.fletch.os;

class NativeProcess {

  /// Starts a native (OS) process with stdin, stdout, and stderr detached.
  /// Returns the pid of the spawned process.
  static int startDetached(String path, List<String> arguments) {
    List<ForeignMemory> allocated = [];

    // Helper method to ensure we know what to free.
    int allocateString(String str) {
      var arg = new ForeignMemory.fromStringAsUTF8(str);
      allocated.add(arg);
      return arg.address;
    }

    // Validate arguments.
    if (path == null || path.isEmpty) {
      throw 'Empty path: Path must point to valid executable';
    }
    if (arguments == null) {
      arguments = const [];
    }
    var arrayOfArgs;
    try {
      // Convert list of String to native memory layout. We pass down
      // all the arguments as a NULL terminated array, including the path
      // as the first element. This is used in the native execv method
      // and avoids having to reallocate an array in native code.
      var numArgs = arguments.length + 2;
      arrayOfArgs = new Struct(numArgs);
      allocated.add(arrayOfArgs);
      arrayOfArgs.setField(0, allocateString(path));
      for (int i = 0; i < arguments.length; ++i) {
        arrayOfArgs.setField(1 + i, allocateString(arguments[i]));
      }
      arrayOfArgs.setField(numArgs - 1, 0);
      int pid = _spawnDetached(arrayOfArgs.address);
      if (pid < 0) {
        throw "Failed to start process from path '$path'. Got errno "
            "${Foreign.errno}";
      }
      return pid;
    } finally {
      for (var memory in allocated) {
        memory.free();
      }
    }
  }

  @fletch.native static int _spawnDetached(int argumentsAddress) {
    throw new UnsupportedError('_spawnDetached');
  }
}

