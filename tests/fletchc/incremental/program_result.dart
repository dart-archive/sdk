// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fletchc.test.program_result;

import 'dart:convert' show
    JSON;

import 'source_update.dart';

class ProgramResult {
  final /* Map<String, String> or String */ code;

  final List<String> messages;

  final bool compileUpdatesShouldThrow;

  final bool commitChangesShouldFail;

  final bool hasCompileTimeError;

  const ProgramResult(
      this.code,
      this.messages,
      {this.compileUpdatesShouldThrow: false,
       this.commitChangesShouldFail: false,
       this.hasCompileTimeError: false});

  String toString() {
    return """
ProgramResult(
    ${JSON.encode(code)},
    ${JSON.encode(messages)},
    commitChangesShouldFail: $commitChangesShouldFail,
    compileUpdatesShouldThrow: $compileUpdatesShouldThrow,
    hasCompileTimeError: $hasCompileTimeError)""";
  }
}

class ProgramExpectation {
  final List<String> messages;

  final bool compileUpdatesShouldThrow;

  final bool commitChangesShouldFail;

  final bool hasCompileTimeError;

  const ProgramExpectation(
      this.messages,
      {this.compileUpdatesShouldThrow: false,
       this.commitChangesShouldFail: false,
       this.hasCompileTimeError: false});

  factory ProgramExpectation.fromJson(String json) {
    var data = JSON.decode(json);
    if (data is String) {
      data = <String>[data];
    }
    if (data is List) {
      return new ProgramExpectation(data);
    }
    return new ProgramExpectation(
        extractMessages(data),
        compileUpdatesShouldThrow: extractCompileUpdatesShouldThrow(data),
        commitChangesShouldFail: extractCommitChangesShouldFail(data),
        hasCompileTimeError: extractHasCompileTimeError(data));
  }

  ProgramResult toResult(/* Map<String, String> or String */ code) {
    return new ProgramResult(
        code,
        messages,
        compileUpdatesShouldThrow: compileUpdatesShouldThrow,
        commitChangesShouldFail: commitChangesShouldFail,
        hasCompileTimeError: hasCompileTimeError);
  }

  toJson() {
    if (!compileUpdatesShouldThrow && !commitChangesShouldFail) {
      return messages.length == 1 ? messages.first : messages;
    }
    Map<String, dynamic> result = <String, dynamic>{
      "messages": messages,
    };
    if (compileUpdatesShouldThrow) {
      result['compileUpdatesShouldThrow'] = 1;
    }
    if (commitChangesShouldFail) {
      result['commitChangesShouldFail'] = 1;
    }
    if (hasCompileTimeError) {
      result['hasCompileTimeError'] = 1;
    }
    return result;
  }

  String toString() {
    return """
ProgramExpectation(
    ${JSON.encode(messages)},
    commitChangesShouldFail: $commitChangesShouldFail,
    compileUpdatesShouldThrow: $compileUpdatesShouldThrow,
    hasCompileTimeError: $hasCompileTimeError)""";
  }

  static List<String> extractMessages(Map<String, dynamic> json) {
    return new List<String>.from(json["messages"]);
  }

  static bool extractCompileUpdatesShouldThrow(Map<String, dynamic> json) {
    return json["compileUpdatesShouldThrow"] == 1;
  }

  static bool extractCommitChangesShouldFail(Map<String, dynamic> json) {
    return json["commitChangesShouldFail"] == 1;
  }

  static bool extractHasCompileTimeError(Map<String, dynamic> json) {
    return json["hasCompileTimeError"] == 1;
  }
}

class EncodedResult {
  final /* String or List */ updates;

  final List expectations;

  const EncodedResult(this.updates, this.expectations);

  List<ProgramResult> decode() {
    if (updates is List) {
      if (updates.length == 1) {
        throw new StateError("Trivial diff, no reason to use decode.");
      }
      List<String> sources = expandUpdates(updates);
      List expectations = this.expectations;
      if (sources.length != expectations.length) {
        throw new StateError(
            "Number of sources and expectations differ"
            " (${sources.length} sources,"
            " ${expectations.length} expectations).");
      }
      List<ProgramResult> result = new List<ProgramResult>(sources.length);
      for (int i = 0; i < sources.length; i++) {
        result[i] = expectations[i].toResult(sources[i]);
      }
      return result;
    } else if (updates is String) {
      Map<String, String> files = splitFiles(updates);
      Map<String, List<String>> fileMap = <String, List<String>>{};
      int updateCount = -1;
      for (String name in files.keys) {
        if (name.endsWith(".patch")) {
          String realname = name.substring(0, name.length - ".patch".length);
          if (files.containsKey(realname)) {
            throw new StateError("Patch '$name' conflicts with '$realname'");
          }
          if (fileMap.containsKey(realname)) {
            // Can't happen.
            throw new StateError("Duplicated entry for '$realname'.");
          }
          List<String> updates = expandUpdates(expandDiff(files[name]));
          if (updates.length == 1) {
            throw new StateError("No patches found in:\n ${files[name]}");
          }
          if (updateCount == -1) {
            updateCount = updates.length;
          } else if (updateCount != updates.length) {
            throw new StateError(
                "Unexpected number of patches: ${updates.length},"
                " expected ${updateCount}");
          }
          fileMap[realname] = updates;
        }
      }
      if (updateCount == -1) {
        throw new StateError("No patch files in $updates");
      }
      for (String name in files.keys) {
        if (!name.endsWith(".patch")) {
          fileMap[name] = new List<String>.filled(updateCount, files[name]);
        }
      }
      if (updateCount != expectations.length) {
        throw new StateError(
            "Number of patches and expectations differ "
            "(${updateCount} patches, ${expectations.length} expectations).");
      }
      List<ProgramResult> result = new List<ProgramResult>(updateCount);
      for (int i = 0; i < updateCount; i++) {
        ProgramExpectation expectation = decodeExpectation(expectations[i]);
        result[i] = expectation.toResult(<String, String>{});
      }
      for (String name in fileMap.keys) {
        for (int i = 0; i < updateCount; i++) {
          result[i].code[name] = fileMap[name][i];
        }
      }
      return result;
    } else {
      throw new StateError("Unknown encoding of updates");
    }
  }
}

ProgramExpectation decodeExpectation(expectation) {
  if (expectation is ProgramExpectation) {
    return expectation;
  } else if (expectation is String) {
    return new ProgramExpectation(<String>[expectation]);
  } else if (expectation is List) {
    return new ProgramExpectation(new List<String>.from(expectation));
  } else {
    throw new ArgumentError("Don't know how to decode $expectation");
  }
}

Map<String, EncodedResult> computeTests(List<String> tests) {
  Map<String, EncodedResult> result = <String, EncodedResult>{};
  for (String test in tests) {
    int firstLineEnd = test.indexOf("\n");
    String testName = test.substring(0, firstLineEnd);
    test = test.substring(firstLineEnd + 1);
    Map<String, String> files = splitFiles(test);
    bool isFirstPatch = true;
    List<ProgramExpectation> expectations;
    files.forEach((String filename, String source) {
      if (filename.endsWith(".patch")) {
        if (isFirstPatch) {
          expectations = extractJsonExpectations(source);
        }
        isFirstPatch = false;
      }
    });
    if (result.containsKey(testName)) {
      throw new StateError("'$testName' is duplicated");
    }
    result[testName] = new EncodedResult(test, expectations);
  }
  return result;
}

List<ProgramExpectation> extractJsonExpectations(String source) {
  return new List<ProgramExpectation>.from(source.split("\n")
      .where((l) => l.startsWith("<<<< ") || l.startsWith("==== "))
      .map((l) => l.substring("<<<< ".length))
      .map((l) => new ProgramExpectation.fromJson(l)));
}
