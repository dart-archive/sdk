// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/**
 * Provides an extensible key-value map for storing properties such as the
 * connection port.
 *
 * It is intended for use by the command line driver tools. The default
 * implementation is a non-caching file based store.
 */
library driver.properties;

import 'property_managers.dart';

PropertyManager _manager = new FileBasedPropertyManager();

String getProperty(String path, String name) {
  return _manager.getProperty(path, name);
}

void setProperty(String path, String name, String value) {
  _manager.setProperty(path, name, value);
}

void useMemoryBackedProperties() {
  _manager = new MemoryBasedPropertyManager();
}