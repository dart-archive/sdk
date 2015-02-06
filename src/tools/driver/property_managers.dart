// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/**
 * Provides implementations of the property store.
 */
library driver.property_managers;

import 'dart:convert' as convert;
import 'dart:io' as io;

abstract class PropertyManager {
  String getProperty(String path, String name);
  void setProperty(String path, String name, String value);
}

class MemoryBasedPropertyManager extends PropertyManager {

  final pathToEntriesMaps = {};

  String getProperty(String path, String name) {
    if (!pathToEntriesMaps.containsKey(path)) return null;

    return pathToEntriesMaps[path][name];
  }

  void setProperty(String path, String name, String value) {
    pathToEntriesMaps.putIfAbsent(path, () => {})[name] = value;
  }
}

class FileBasedPropertyManager extends PropertyManager {

  String getProperty(String path, String name) {
    io.File propertiesFile = new io.File(path);

    if (!propertiesFile.existsSync()) return null;

    String propertiesFileContent = propertiesFile.readAsStringSync();
    Map json = convert.JSON.decode(propertiesFileContent);
    return json[name];
  }

  void setProperty(String path, String name, String value) {
    io.File propertiesFile = new io.File(path);

    String contents;
    if (!propertiesFile.existsSync()) {
      contents = "{}";
    } else {
      contents = propertiesFile.readAsStringSync();
    }

    Map json = convert.JSON.decode(contents);
    json[name] = value;
    propertiesFile.writeAsStringSync(convert.JSON.encode(json), flush: true);
  }
}
