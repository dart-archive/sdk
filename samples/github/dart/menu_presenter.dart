// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:immi/immi.dart';

// Export generated code for nodes in menu_presenter.immi
import 'package:immi_gen/dart/menu_presenter.dart';
export 'package:immi_gen/dart/menu_presenter.dart';

class MenuPresenter {
  List<MenuItemNode> items = [];

  MenuPresenter() {
    for (int i = 0; i < 10; ++i) {
      int index = i;
      items.add(new MenuItemNode(
          title: "My menu item $index",
          select: () { print("Selected item $index"); }));
    }
  }

  MenuNode present(Node previous) {
    return new MenuNode(items: items);
  }
}
