// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/**
 * An interaction prototype for displaying results of executing a program
 * inline with the analysis of the program. It uses fletchc for determining
 * errors and warnings and the Dart VM for running the code.
 */
library fletchc.driver;

import 'dart:io' as io;
import 'dart:async';

import 'package:fletchc/compiler.dart' show
    FletchCompiler;

import 'package:compiler/compiler.dart' show
    Diagnostic;

// For the purpose of this prototype keep all the history of previous
// analyses.
// TODO(lukechurch): Add an upper limit of the number of previous results. 
List warnings = [[]];
List errors = [[]];

main(List<String> args) {
  if (args.length != 2) {
    print (r'''
Demo FletchC interaction driver
usage dart fletchc_driver <target file> <path to dart binary>''');
    io.exit(1);
  }
  
  final String targetPath = args[0];
  final String dartPath = args[1];
  
  io.File targetFile = new io.File(targetPath);
  print("Startup complete.");
  targetFile.watch().listen((io.FileSystemEvent fse) { 
    warnings.add([]);
    errors.add([]);
    updateErrorsAndWarnings(targetFile.path).then((_) {
      int warningsCount = warnings.length;
      
      // TODO(lukechurch): Fix this ugly repetitive code.
      Set newWarnings = diff(
        warnings[warningsCount-2],
        warnings[warningsCount-1]);
      
      Set fixedWarnings = diff(
        warnings[warningsCount-1],
        warnings[warningsCount-2]);
      
      Set newErrors = diff(
        errors[warningsCount-2],
        errors[warningsCount-1]);
      
      Set fixedErrors = diff(
        errors[warningsCount-1],
        errors[warningsCount-2]);

      if (fixedWarnings.length > 0) {
        print ("Fixed: ${fixedWarnings}");
      }
      if (fixedErrors.length > 0) {
        print ("Fixed: ${fixedErrors}");
      }
      if (newWarnings.length > 0) {
        print ("New: ${newWarnings}");
      }
      if (newErrors.length > 0) {
        print ("New: ${newErrors}");
      }
       
      execute(targetFile.path, dartPath);
    });
  });
}

Future updateErrorsAndWarnings(String path) {
  List<String> options = ["--analyze-only"];
  FletchCompiler compiler =
    new FletchCompiler(
      options: options, 
      script: path, 
      handler: diagnosticHandler);
  
  return compiler.run().catchError((e, trace) {
    print(e);
    print(trace);
    print("The compiler crashed, please try a diffrent program.");
  });
}

execute(String targetPath, String dartPath) {
  io.Process.run(dartPath, [targetPath]).then(
    (io.ProcessResult results) => print(results.stdout.trim())
  );
}

Set diff(List previous, List next) {
  Set previousSet = new Set()..addAll(previous);
  Set nextSet = new Set()..addAll(next);
  return nextSet.difference(previousSet);
}

void diagnosticHandler(Uri uri, int begin, int end,
                               String message, Diagnostic kind) {
  if (kind == Diagnostic.ERROR) {
    errors.last.add(message);
  } else if (kind == Diagnostic.WARNING) {
    warnings.last.add(message);
  }
}
