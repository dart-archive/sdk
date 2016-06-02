// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'todomvc_impl.dart';
import 'dart/todomvc_service.dart';

main() {
  var impl = new TodoMVCImpl();
  TodoMVCService.initialize(impl);
  while (TodoMVCService.hasNextEvent()) {
    TodoMVCService.handleNextEvent();
  }
}
