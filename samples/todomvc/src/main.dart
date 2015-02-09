// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';

import 'model.dart';
import 'presenter.dart';

main() {
  Model model = new Model();
  model.createItem("My default todo");
  model.createItem("Some other todo");

  var server = new ServerSocket("127.0.0.1", 8182);
  if (server == null) {
    print("Failed to start server on port 8182");
    exit(0);
  }
  print("Started server on port ${server.port}");

  while (true) {
    var client = server.accept();
    print("Accepted client session");

    var presenter = new TodoListPresenter(model, client);
    Thread.fork(presenter.run);
  }
  server.close();
}
