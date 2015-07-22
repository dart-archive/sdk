// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc;
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

  FletchVm vm;
  if (options.connectToExistingVm) {
    var socket = await Socket.connect("127.0.0.1", options.existingVmPort);
    vm = new FletchVm.existing(socket);
  } else {
    vm = await FletchVm.start(compiler);
  }

  var session = new Session(vm.socket, compiler, fletchDelta.system,
                            vm.stdoutSyncMessages, vm.stderrSyncMessages,
                            vm.process != null ? vm.process.exitCode : null);

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

  if (!options.connectToExistingVm) {
    exitCode = await vm.process.exitCode;
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
