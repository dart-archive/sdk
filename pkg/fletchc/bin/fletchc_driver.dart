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
import 'package:fletchc/commands.dart' as commands;

import 'package:compiler/compiler.dart' show
    Diagnostic;

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
  
  // TODO(lukechurch): This causes all sorts of problems with
  // interleaved errors and output. It needs a rework.
  targetFile.watch().listen((io.FileSystemEvent fse) { 
    List<String> options = []; //["--analyze-only"];
    FletchCompiler compiler =
      new FletchCompiler(
        options: options, 
        script: targetFile.path, 
        handler: diagnosticHandler);
      
    compiler.run()..catchError((e, trace) {
      print(e);
      print(trace);
      print("The compiler crashed, please try a diffrent program.");
    })..then((cmds) {
      print ('about to executeCmds');
      executeCmds(compiler, cmds, compiler.fletchVm.toFilePath());
    });
  
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
    print("Error: $message");
  } else if (kind == Diagnostic.WARNING) {
    print("Warning: $message");
  }
}

executeCmds(compiler, List cmds, String fletchVmPath) async {
  print ('executeCmds');
  var server = await io.ServerSocket.bind(io.InternetAddress.LOOPBACK_IP_V4, 0);

  List<String> vmOptions = <String>[
    '--port=${server.port}',
    '-Xvalidate-stack',
    "-Xbridge-connection"
  ];

  var connectionIterator = new StreamIterator(server);
  var vmProcess =
    await io.Process.start(fletchVmPath, vmOptions);

  vmProcess.stdout.listen(io.stdout.add);
  vmProcess.stderr.listen(io.stderr.add);

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = connectionIterator.current;
  server.close();

  vmSocket.listen(null);
  
  var mainFunction = compiler.backdoor.functionElementFromName('main');
  var fooFunction = compiler.backdoor.functionElementFromName('foo');
  var barFunction = compiler.backdoor.functionElementFromName('bar');
  
  cmds.forEach((command) => command.addTo(vmSocket));
  
  bool flipflop = false;
  Timer t = new Timer.periodic(new Duration(milliseconds: 50), (_) {
    flipflop = !flipflop;
    cmds = [];
    
    // Retarget the function being executed.
    cmds.add(new commands.PushFromMap(commands.MapId.methods, 
        compiler.backdoor.indexForFunctionElement(mainFunction)));
    if (flipflop) {
      cmds.add(new commands.PushFromMap(commands.MapId.methods, 
          compiler.backdoor.indexForFunctionElement(barFunction)));
    } else {
      cmds.add(new commands.PushFromMap(commands.MapId.methods, 
          compiler.backdoor.indexForFunctionElement(fooFunction)));        
    }
    
    // TODO(lukechurch): Compute this number.
    int constantPoolIndex = 0;
    cmds.add(new commands.ChangeMethodLiteral(constantPoolIndex));
    cmds.add(new commands.CommitChanges(1));
    
    // Apply the changes.
    cmds.forEach((command) => command.addTo(vmSocket));
  });
  
  /* Exit handling code. Renable once we have a way of terminating this.
   * 
   * var exitCode = await vmProcess.exitCode;
   * if (exitCode != 0) {
   *   print("Non-zero exit code from VM ($exitCode).");
   * }
   */
}


