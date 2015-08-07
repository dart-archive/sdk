// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc;

import 'dart:convert';

import 'dart:io';

import 'compiler.dart' show
    FletchCompiler;

import 'fletch_vm.dart';

import 'fletch_system.dart';

import 'session.dart';

import 'src/driver/options.dart' show
    Options;

const COMPILER_CRASHED = 253;
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

main(List<String> arguments) async {
  Options options = Options.parse(arguments);

  if (options.script == null) throw "No script supplied";

  exitCode = COMPILER_CRASHED;

  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler = new FletchCompiler(
      options: compilerOptions,
      script: options.script,
      packageRoot: options.packageRootPath);
  FletchDelta fletchDelta = await compiler.run();

  Socket socket;
  FletchVm vm;
  if (options.connectToExistingVm) {
    socket = await Socket.connect(
        InternetAddress.LOOPBACK_IP_V4, options.existingVmPort);
  } else {
    String vmPath = compiler.fletchVm.toFilePath();
    vm = await FletchVm.start(vmPath);
    vm.stdoutLines.listen((String line) {
      stdout.writeln('stdout: $line');
    });
    vm.stderrLines.listen((String line) {
      stderr.writeln('stderr: $line');
    });
    if (compiler.verbose) {
      print("Running '$vmPath'");
    }
    socket = await vm.connect();
  }

  var lineStream = stdin.transform(UTF8.decoder)
                        .transform(new LineSplitter());
  var session = new Session(
      socket, compiler, fletchDelta.system,
      lineStream, stdout, stderr, vm != null ? vm.exitCode : null);

  // If we started a vmProcess ourselves, we disable the normal
  // VM standard output as we already get it via the wire protocol.
  if (!options.connectToExistingVm) await session.disableVMStandardOutput();

  await session.runCommands(fletchDelta.commands);
  if (options.snapshotPath != null) {
    await session.writeSnapshot(options.snapshotPath);
  } else if (options.debugging) {
    if (options.testDebugger) {
      await session.testDebugger(options.testDebuggerCommands);
    } else {
      await session.debug();
    }
  } else {
    await session.run();
  }
  await session.shutdown();

  if (vm != null) {
    exitCode = await vm.exitCode;
    if (exitCode != 0) {
      print("Non-zero exit code from "
            "'${compiler.fletchVm.toFilePath()}' ($exitCode).");
    }
    if (exitCode < 0) {
      // TODO(ahe): Is there a better value for reporting a Vm crash?
      exitCode = COMPILER_CRASHED;
    }
  }
}
