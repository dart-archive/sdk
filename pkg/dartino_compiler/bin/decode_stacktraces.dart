// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io' as io;

import 'package:dartino_compiler/program_info.dart';

main(List<String> arguments) async {
  await decodeProgramMain(arguments, io.stdin, io.stdout);
}
