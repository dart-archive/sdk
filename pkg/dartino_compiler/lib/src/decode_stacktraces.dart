// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../dartino_system.dart';
import '../program_info.dart';
import 'dartino_selector.dart';
import 'hub/session_manager.dart';
import 'worker/developer.dart';
import 'debug_info.dart';
import 'diagnostic.dart';

final RegExp _ConfigurationRegExp =
new RegExp(r'^VM Configuration (32|64) (32|64)$');

final RegExp _FrameRegExp =
new RegExp(r'^Frame +([0-9]+): Function\(([0-9]+)\) Bytecode\(([0-9]+)\)$');

final RegExp _NSMRegExp =
new RegExp(r'^NoSuchMethodError\(([0-9]+), ([0-9]+)\)$');

Stream<String> decodeStackFrames(
    DartinoSystem system,
    IdOffsetMapping info,
    Stream<String> input,
    SessionState state) async* {
  Configuration conf;
  await for (String line in input) {
    Match configurationMatch = _ConfigurationRegExp.firstMatch(line);
    Match frameMatch = _FrameRegExp.firstMatch(line);
    Match nsmMatch = _NSMRegExp.firstMatch(line);
    if (configurationMatch != null) {
      conf = _getConfiguration(
          configurationMatch.group(1), configurationMatch.group(2));
    } else if (frameMatch != null) {
      if (conf == null) throw "Frame description before configuration.";

      String frameNr = frameMatch.group(1);
      int functionOffset = int.parse(frameMatch.group(2));

      String functionName = info.nameOffsets.functionName(conf, functionOffset);
      int functionId = info.functionIdFromOffset(conf, functionOffset);
      DebugInfo debugInfo =
      state.compiler.createDebugInfo(system.functionsById[functionId], system);
      int bytecodeOffset = int.parse(frameMatch.group(3));
      if (functionName == null) {
        yield '   $frameNr: <unknown function (offset $functionOffset)>\n';
      } else {
        yield '   $frameNr: ${shortName(functionName)} '
            '${debugInfo.fileAndLineStringFor(bytecodeOffset)}\n';
      }
    } else if (nsmMatch != null) {
      if (conf == null) throw "Error description before configuration.";
      int classOffset = int.parse(nsmMatch.group(1));
      DartinoSelector selector =
      new DartinoSelector(int.parse(nsmMatch.group(2)));
      String selectorName = info.nameOffsets.selectorName(selector);
      String className = info.nameOffsets.className(conf, classOffset);

      if (className != null && selectorName != null) {
        yield 'NoSuchMethodError: ${shortName(className)}.$selectorName\n';
      } else if (selectorName != null) {
        yield 'NoSuchMethodError: $selectorName\n';
      } else {
        yield 'NoSuchMethodError: <unknown method>\n';
      }
    } else {
      yield '$line\n';
    }
  }
}

class DecodeException {
  final String message;
  DecodeException(this.message);
  toString() => message;
}

Configuration _getConfiguration(String bits, String floatOrDouble) {
  int wordSize = const {'32': 32, '64': 64}[bits];
  int dartinoDoubleSize = const {'32': 32, '64': 64}[floatOrDouble];
  return getConfiguration(wordSize, dartinoDoubleSize);
}

Future<Null> decodeProgramMain(
    List<String> arguments,
    Stream<List<int>> input,
    StreamSink<List<int>> output) async {

  if (arguments.length < 1 || arguments.length > 2) {
    throw new DecodeException("1 or 2 arguments must be supplied.");
  }

  Uri script = Uri.base.resolve(arguments[0]);
  Uri snapshot = arguments.length == 1
      ? defaultSnapshotLocation(script)
      : Uri.base.resolve(arguments[1]);
  Uri info = snapshot.replace(path: "${snapshot.path}.info.json");
  File infoFile = new File.fromUri(info);
  if (!await infoFile.exists()) {
    throw new DecodeException(
        "The file '${info.toFilePath()}' does not exist.");
  }

  NameOffsetMapping nameOffsetMapping;
  try {
    nameOffsetMapping = ProgramInfoJson.decode(await infoFile.readAsString());
  } on FormatException {
    throw new DecodeException("Info file ${info.toFilePath()} malformed.");
  }
  SessionState state = createSessionState("decode", Uri.base,
      new Settings(
          Uri.base.resolve(".packages"), [], {}, [], null, null, null, IncrementalMode.none));
  try {
    await compile(script, state, Uri.base);
  } on InputError catch (e) {
    throw new DecodeException("Compilation failed ${e}");
  }
  DartinoSystem dartinoSystem = state.compilationResults.last.system;

  IdOffsetMapping idOffsetMapping = new IdOffsetMapping(
      dartinoSystem.computeSymbolicSystemInfo(
          state.compiler.compiler.libraryLoader.libraries), nameOffsetMapping);

  Stream<String> inputLines =
  input.transform(UTF8.decoder).transform(new LineSplitter());

  Stream<String> decodedFrames =
  decodeStackFrames(dartinoSystem, idOffsetMapping, inputLines, state);
  await decodedFrames.transform(UTF8.encoder).pipe(output);
}