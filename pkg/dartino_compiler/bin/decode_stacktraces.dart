// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartino_compiler/src/decode_stacktraces.dart';

usage(message) {
  print("Invalid arguments: $message");
  print("Usage: ${Platform.script} <script.dart> [script.snapshot]");
}

main(List<String> arguments) async {
  try {
    await decodeProgramMain(arguments, stdin, stdout);
  } on DecodeException catch (e) {
    usage(e.message);
    exit(1);
  }
}
