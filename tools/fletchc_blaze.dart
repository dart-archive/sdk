// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc_blaze;

import 'dart:async';

import 'dart:convert' show
    LineSplitter,
    UTF8;

import 'dart:io';

import 'package:fletchc/session.dart' show
    Session;

import 'package:fletchc/src/hub/session_manager.dart';

import 'package:fletchc/src/worker/developer.dart' show
    Address,
    Settings,
    SessionState;

import 'package:fletchc/src/worker/developer.dart' as developer;

import 'package:fletchc/src/verbs/infrastructure.dart' show
    fileUri;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

class FletchRunner {

  Future<int> run(List<String> arguments) async {
    int debugPort;
    String packages;
    String snapshot;
    String script;
    Uri libraryRoot;
    Uri fletchVm;
    Uri nativesJson;

    for (int i = 0; i < arguments.length; ++i) {
      String arg = arguments[i];
      if (arg == "--debug") {
        if (debugPort != null) throw "Cannot supply multiple debug ports";
        debugPort = int.parse(arguments[++i]);
      } else if (arg == "--packages") {
        if (packages != null) throw "Cannot supply multiple package files";
        packages = arguments[++i];
      } else if (arg == "--snapshot") {
        if (snapshot != null) throw "Cannot export to multiple snapshot files";
        snapshot = arguments[++i];
      } else if (arg == "--library-root") {
        if (libraryRoot != null) throw "Cannot use multiple library roots";
        libraryRoot = Uri.base.resolve(appendSlash(arguments[++i]));
      } else if (arg == "--patch-root") {
        throw "--patch-root not supported anymore";
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

    Address device =
        (debugPort != null) ? new Address("localhost", debugPort) : null;

    Settings settings = new Settings(
        fileUri(packages, Uri.base), <String>["--verbose"], null, device, null);

    SessionState state = developer.createSessionState(
        "fletchc-blaze",
        settings,
        libraryRoot: libraryRoot,
        fletchVm: fletchVm,
        nativesJson: nativesJson);

    int result = await developer.compile(fileUri(script, Uri.base), state);

    if (result != 0) {
      print(state.getLog());
      return result;
    }

    if (device != null) {
      await developer.attachToVm(device.host, device.port, state);
      state.stdoutSink.attachCommandSender(stdout.add);
      state.stderrSink.attachCommandSender(stderr.add);

      Session session = state.session;
      for (FletchDelta delta in state.compilationResults) {
        await session.applyDelta(delta);
      }

      var input = stdin.transform(UTF8.decoder).transform(new LineSplitter());
      await session.debug(input);
    } else {
      await developer.startAndAttachDirectly(state);
      state.stdoutSink.attachCommandSender(stdout.add);
      state.stderrSink.attachCommandSender(stderr.add);

      if (snapshot != null) {
        await developer.export(state, fileUri(snapshot, Uri.base));
      } else {
        await developer.run(state);
      }
    }

    return result;
  }
}

main(List<String> arguments) async {
  return await new FletchRunner().run(arguments);
}
