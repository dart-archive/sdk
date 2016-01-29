// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';

List<String> trimAll(List<String> list) {
  return list.map((s) => s.trim()).toList();
}

void main() {
  // Compute the binary size of Fletch when linked into an LK+Fletch
  // image. The computation is based on two files containing output
  // from the 'size' program on Linux.
  //
  // The output from 'size' contains two lines of the form:
  //
  //   text    data     bss     dec     hex filename
  //  25695     537    8240   34472    86a8 out/DebugIA32/fletch
  Uri executable = new Uri.file(Platform.resolvedExecutable);
  Uri lkBaselineSizeFile = executable.resolve('lk_sizes_baseline.txt');
  Uri lkFletchSizeFile = executable.resolve('lk_sizes_fletch.txt');
  List<String> baselineLines =
      new File(lkBaselineSizeFile.toFilePath()).readAsLinesSync();
  List<String> fletchLines =
      new File(lkFletchSizeFile.toFilePath()).readAsLinesSync();
  List<String> baselineKeys = trimAll(baselineLines[0].split('\t'));
  List<String> baselineValues = trimAll(baselineLines[1].split('\t'));
  List<String> fletchKeys = trimAll(fletchLines[0].split('\t'));
  List<String> fletchValues = trimAll(fletchLines[1].split('\t'));
  List<String> interestingKeys = ['text', 'data', 'bss'];
  for (int i = 0; i < baselineKeys.length; i++) {
    for (var key in interestingKeys) {
      if (baselineKeys[i] == key) {
        int lkFletchValue = int.parse(fletchValues[i]);
        int lkBaselineValue = int.parse(baselineValues[i]);
        int fletchSize = lkFletchValue - lkBaselineValue;
        print("FletchARMBinarySize_$key(CodeSize): ${fletchSize}");
      }
    }
  }
}
