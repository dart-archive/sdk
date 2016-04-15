// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io' as io;

import 'package:dartino_compiler/program_info.dart';

main(List<String> arguments) async {
  usage(message) {
    print("Invalid arguments: $message");
    print("Usage: ${io.Platform.script} <dartino.ticks> <snapshot.info.json>");
  }

  if (arguments.length != 2) {
    usage("Exactly 2 arguments must be supplied");
    io.exit(-1);
  }

  String sample_filename = arguments[0];
  io.File sample_file = new io.File(sample_filename);
  if (!await sample_file.exists()) {
    usage("The file '$sample_filename' does not exist.");
    io.exit(-1);
  }

  String info_filename = arguments[1];
  if (!info_filename.endsWith('.info.json')) {
    usage("The program info file must end in '.info.json' "
        "(was: '$info_filename').");
    io.exit(-1);
  }

  io.File info_file = new io.File(info_filename);
  if (!await info_file.exists()) {
    usage("The file '$info_filename' does not exist.");
    io.exit(-1);
  }

  NameOffsetMapping info =
      ProgramInfoJson.decode(await info_file.readAsString());

  Profile profile = await decodeTickSamples(
      info, sample_file.openRead(), io.stdin, io.stdout);
  if (profile != null) io.stdout.write(profile.formatted(info));
}
