// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:immi/dart/immi.dart';

// Export generated code for nodes in menu.immi
import 'package:immi/dart/menu.dart';
export 'package:immi/dart/menu.dart';

class MenuItem {
  String title;
  Function select;

  MenuItem(this.title, this.select);

  MenuItemNode present(Node previous) {
    return new MenuItemNode(title: title, select:select);
  }
}

class Menu {
  String title;
  List<MenuItem> items = [];

  Menu(this.title);

  void add(MenuItem item) {
    items.add(item);
  }

  MenuNode present(Node previous) {
    return new MenuNode(
        title: title,
        items:items.map((item) => item.present(null)).toList());
  }
}
