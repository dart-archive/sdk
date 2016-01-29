// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io' as io;

import 'package:fletchc/program_info.dart';

main(List<String> arguments) async {
  Profile profile = await decodeTickSamples(arguments, io.stdin, io.stdout);
  if (profile != null) profile.Print();
}
