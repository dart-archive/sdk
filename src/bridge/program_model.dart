// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of session;

enum SelectorKind {
  Method,
  Getter,
  Setter
}

class Selector {
  final int _value;

  Selector(this._value);

  int get arity => _value & 0xFF;
  SelectorKind get kind => SelectorKind.values[(_value >> 8) & 0x3];
  int get id => _value >> 10;
}

class Method {
  final String name;
  final List<int> bytecodes;

  Method(this.name, this.bytecodes);

  void dump(int index, ProgramModel model) {
    print("method @$index: $name");
    var i = 0;
    while (i < bytecodes.length) {
      var current = _bytecodes[bytecodes[i]];
      var bytecodeString = current.bytecodeToString(i, bytecodes, model);
      i += current.size;
      print("$bytecodeString");
      if (current == _bytecodes.last) break;
    }
    print("");
  }
}

class Class {
  final String name;
  final int fieldCount;
  final Map<int, Method> methods = new Map();

  Class(this.name, this.fieldCount);
}

class ProgramModel {
  final Map<int, Map> _mapsMap = new Map();
  final Map<int, Method> methodMap = new Map();
  final Map<int, Class> classMap = new Map();
  final Map<int, String> methodNameMap = new Map();

  int methodMapId;
  int classMapId;

  void setMethodMapId(int id) {
    methodMapId = id;
    _mapsMap[id] = methodMap;
  }

  void setClassMapId(int id) {
    classMapId = id;
    _mapsMap[id] = classMap;
  }

  Map lookupMap(int id) => _mapsMap[id];

  void dumpMethods() {
    methodMap.forEach((int index, Method method) {
      method.dump(index, this);
    });
  }
}
