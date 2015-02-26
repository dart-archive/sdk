// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'buildbot_impl.dart';
import 'dart/buildbot_service.dart';

main() {
  var impl = new BuildBotImpl();
  BuildBotService.initialize(impl);
  while (BuildBotService.hasNextEvent()) {
    BuildBotService.handleNextEvent();
  }
}
