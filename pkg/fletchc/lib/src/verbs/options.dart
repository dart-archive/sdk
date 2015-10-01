// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.options;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

class Options {
  final String script;
  final String snapshotPath;
  final bool debugging;
  final bool testDebugger;
  final String testDebuggerCommands;
  final String packageConfigPath;
  final String attachArgument;
  final bool connectToExistingVm;
  final int existingVmPort;
  final List<String> defines;  // List of all -D options.

  Options(
      this.script,
      this.snapshotPath,
      this.debugging,
      this.testDebugger,
      this.testDebuggerCommands,
      this.packageConfigPath,
      this.attachArgument,
      this.connectToExistingVm,
      this.existingVmPort,
      this.defines);

  static final RegExp defineFlagPattern = new RegExp('^-D.+=.*\$');

  /// Parse [options] which is a list of command-line arguments, such as those
  /// passed to `main`.
  static Options parse(Iterable<String> options) {
    String script;
    String snapshotPath;
    bool debugging = false;
    bool testDebugger = false;
    String testDebuggerCommands = "";
    String packageConfigPath = ".packages";
    String attachArgument;
    bool connectToExistingVm = false;
    int existingVmPort = 0;
    List<String> defines = <String>[];

    Iterator<String> iterator = options.iterator;
    String getRequiredArgument(String errorMessage) {
      if (iterator.moveNext()) {
        return iterator.current;
      } else {
        // TODO(ahe): Improve error recovery.
        throwFatalError(
            DiagnosticKind.missingRequiredArgument,
            message: errorMessage);
      }
    }

    while (iterator.moveNext()) {
      String option = iterator.current;
      switch (option) {
        case '-o':
        case '--out':
          snapshotPath = getRequiredArgument(
              "The option '$option' requires a file name.");
          break;

        case '-d':
        case '--debug':
          debugging = true;
          break;

        case '--test-debugger':
          testDebugger = true;
          break;

        case '--packages':
          packageConfigPath = getRequiredArgument(
              "The option '$option' requires a file name.");
          break;

        case '-a':
        case '--attach':
          attachArgument = getRequiredArgument(
              "The option '$option' requires host name and port number in the "
              "form of host:port.");
          break;

        // TODO(ahe): Remove this option (use --attach instead).
        case '--port':
          connectToExistingVm = true;
          existingVmPort = int.parse(
              getRequiredArgument(
                  "The option '$option' requires a port number."));
          break;

        default:
          const String packageConfigFlag = '--packages=';
          if (option.startsWith(packageConfigFlag)) {
            packageConfigPath = option.substring(packageConfigFlag.length);
            break;
          }

          const String testDebuggerFlag = '--test-debugger=';
          if (option.startsWith(testDebuggerFlag)) {
            testDebugger = true;
            testDebuggerCommands = option.substring(testDebuggerFlag.length);
            break;
          }

          const String portFlag = '--port=';
          if (option.startsWith(portFlag)) {
            connectToExistingVm = true;
            existingVmPort = int.parse(option.substring(portFlag.length));
            break;
          }

          const String attachFlag = '--attach=';
          if (option.startsWith(attachFlag)) {
            attachArgument = option.substring(attachFlag.length);
            break;
          }

          if (defineFlagPattern.firstMatch(option) != null) {
            defines.add(option.substring(2));
            break;
          }

          if (script != null || option.startsWith("-")) {
            throwFatalError(DiagnosticKind.unknownOption, userInput: option);
          }

          script = option;
          break;
      }
    }

    return new Options(
        script, snapshotPath, debugging, testDebugger, testDebuggerCommands,
        packageConfigPath, attachArgument, connectToExistingVm, existingVmPort,
        defines);
  }
}
