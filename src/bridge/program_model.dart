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

  ProgramModel() { }

  Map lookupMap(int id) => _mapsMap[id];
}
