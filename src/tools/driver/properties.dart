// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/**
 * Stores a set of global properties for use by the command line
 * driver tools.
 *
 * The default implementation is a non-caching file based store.
 */
library driver.properties;

import 'property_managers.dart';

Properties global;

class Properties {
  static const String _SERVER_PORT_NUM_NAME = "serverPortNumber";
  PropertyManager manager = new FileBasedPropertyManager();
  String path;

  Properties(this.path);

  int get serverPortNumber {
    String port = manager.getProperty(path, _SERVER_PORT_NUM_NAME);
    return port != null ? int.parse(port) : null;
  }

  void set serverPortNumber(int value) {
    manager.setProperty(path, _SERVER_PORT_NUM_NAME, value.toString());
  }
}
