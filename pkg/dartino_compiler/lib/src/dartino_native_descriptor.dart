// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_native_descriptor;

import 'dart:convert' show
    JSON;

class DartinoNativeDescriptor {
  final String enumName;

  final String cls;

  final String name;

  final int index;

  final bool isDetachable;

  DartinoNativeDescriptor(this.enumName, this.cls, this.name, this.index,
                          this.isDetachable);

  String toString() {
    return "DartinoNativeDescriptor"
           "($enumName, $cls, $name, $index, $isDetachable)";
  }

  static void decode(
      String jsonData,
      Map<String, DartinoNativeDescriptor> natives,
      Map<String, String> names) {
    Map jsonObjects = JSON.decode(jsonData);
    int index = 0;
    for (Map native in jsonObjects['natives']) {
      String cls = native['class'];
      String name = native['name'];
      bool isDetachable = native['is_detachable'];
      assert(isDetachable != null);
      void add(cls, name) {
        natives['$cls.$name'] = new DartinoNativeDescriptor(
            native['enum'], cls, name, index, isDetachable);
        natives['$cls._dartinoNative$name'] = new DartinoNativeDescriptor(
            native['enum'], cls, name, index, isDetachable);
      }
      if (cls == "<none>") {
        cls = null;
        add("", name);
        if (name.startsWith("_")) {
          // For private top-level methods, create a public version as well.
          // TODO(ahe): Modify the VM table of natives.
          add("", name.substring(1));
        }
      } else {
        add(cls, name);
      }
      index++;
    }
    for (Map name in jsonObjects['names']) {
      names[name['name']] = name['value'];
    }
  }
}
