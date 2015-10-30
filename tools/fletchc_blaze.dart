// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc_blaze;

import 'dart:async';

import 'dart:io';

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart' show
    Settings,
    SessionState;

import 'package:fletchc/src/driver/developer.dart' as developer;

import 'package:fletchc/src/verbs/infrastructure.dart' show
    fileUri;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

class FletchRunner {

  Future<int> run(List<String> arguments) async {
    String packages;
    String snapshot;
    String script;
    Uri libraryRoot;
    Uri patchRoot;
    Uri fletchVm;
    Uri nativesJson;

    for (int i = 0; i < arguments.length; ++i) {
      String arg = arguments[i];
      if (arg == "--packages") {
        if (packages != null) throw "Cannot supply multiple package files";
        packages = arguments[++i];
      } else if (arg == "--snapshot") {
        if (snapshot != null) throw "Cannot export to multiple snapshot files";
        snapshot = arguments[++i];
      } else if (arg == "--library-root") {
        if (libraryRoot != null) throw "Cannot use multiple library roots";
        libraryRoot = Uri.base.resolve(appendSlash(arguments[++i]));
      } else if (arg == "--patch-root") {
        if (patchRoot != null) throw "Cannot use multiple patch roots";
        patchRoot = Uri.base.resolve(appendSlash(arguments[++i]));
      } else if (arg == "--fletch-vm") {
        if (fletchVm != null) throw "Cannot use multiple Fletch VMs";
        fletchVm = Uri.base.resolve(arguments[++i]);
      } else if (arg == "--natives-json") {
        if (nativesJson != null) throw "Cannot use multiple natives json files";
        nativesJson = Uri.base.resolve(arguments[++i]);
      } else if (arg.startsWith("-")) {
        throw "Unknown option $arg";
      } else {
        if (script != null) throw "Cannot run multiple scripts";
        script = arg;
      }
    }

    if (script == null) {
      throw "Supply a script to run";
    }

    if (packages == null) {
      packages = ".packages";
    }

    Settings settings = new Settings(
        fileUri(packages, Uri.base), <String>["--verbose"], null, null, null);

    SessionState state = developer.createSessionState(
        "fletchc-blaze",
        settings,
        libraryRoot: libraryRoot,
        patchRoot: patchRoot,
        fletchVm: fletchVm,
        nativesJson: nativesJson);

    int result = await developer.compile(fileUri(script, Uri.base), state);
    await developer.startAndAttachDirectly(state);
    state.stdoutSink.attachCommandSender(stdout.add);
    state.stderrSink.attachCommandSender(stderr.add);

    if (snapshot != null) {
      await developer.export(state, fileUri(snapshot, Uri.base));
    } else {
      await developer.run(state);
    }

    print(state.getLog());
    return result;
  }
}

main(List<String> arguments) async {
  return await new FletchRunner().run(arguments);
}
