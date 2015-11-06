// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library servicec_blaze;

import 'dart:async';

import 'dart:io';

import 'package:servicec/compiler.dart' show
  compile;

import 'package:servicec/errors.dart' show
  CompilationError,
  ErrorReporter;

class ServicecRunner {

  Future<int> run(List<String> arguments) async {
    String idl = null;
    String out = null;
    String resources = null;

    for (int i = 0; i < arguments.length; ++i) {
      String arg = arguments[i];
      if (arg == "--out") {
        if (out != null) throw "Cannot supply multiple output directories";
        out = arguments[++i];
      } else if (arg == "--resources") {
        if (resources != null) {
          throw "Cannot supply multiple resource directories";
        }
        resources = arguments[++i];
      } else if (arg.startsWith("-")) {
        throw "Unknown option $arg";
      } else {
        if (idl != null) throw "Cannot compile multiple IDL files";
        idl = arg;
      }
    }

    if (idl == null) {
      throw "Supply an IDL file to compile";
    }
    if (out == null) {
      throw "Supply an output directory with "
          + "--out <path to output directory>";
    }
    if (resources == null) {
      throw "Supply the servicec resources root with "
          + "--resources <path to resources root>";
    }

    Iterable<CompilationError> errors = await compile(idl, resources, out);

    if (errors.isNotEmpty) {
      print("Encountered errors while compiling definitions in $idl.");
      new ErrorReporter(idl, idl).report(errors);
      return 1;
    }

    return 0;
  }
}

main(List<String> arguments) async {
  return await new ServicecRunner().run(arguments);
}
