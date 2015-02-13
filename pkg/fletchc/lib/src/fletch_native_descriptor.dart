// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_native_descriptor;

import 'dart:convert' show
    JSON;

class FletchNativeDescriptor {
  final String enumName;

  final String cls;

  final String name;

  final int index;

  FletchNativeDescriptor(this.enumName, this.cls, this.name, this.index);

  String toString() => "FletchNativeDescriptor($enumName, $cls, $name, $index)";

  static Map<String, FletchNativeDescriptor> decode(String jsonData) {
    List jsonObjects = JSON.decode(jsonData);
    var result = <String, FletchNativeDescriptor>{};
    int index = 0;
    for (Map jsonObject in jsonObjects) {
      String cls = jsonObject['class'];
      String name = jsonObject['name'];
      String key;
      if (cls == "<none>") {
        cls = null;
        key = name;
      } else {
        key = '$cls.$name';
      }
      result[key] =
          new FletchNativeDescriptor(jsonObject['enum'], cls, name, index++);
    }
    return result;
  }
}
