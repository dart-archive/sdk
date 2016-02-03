// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';

List<String> trimAll(List<String> list) {
  return list.map((s) => s.trim()).toList();
}

void main() {
  // Compute the binary size of Dartino when linked into an LK+Dartino
  // image. The computation is based on two files containing output
  // from the 'size' program on Linux.
  //
  // The output from 'size' contains two lines of the form:
  //
  //   text    data     bss     dec     hex filename
  //  25695     537    8240   34472    86a8 out/DebugIA32/dartino
  Uri executable = new Uri.file(Platform.resolvedExecutable);
  Uri lkBaselineSizeFile = executable.resolve('lk_sizes_baseline.txt');
  Uri lkDartinoSizeFile = executable.resolve('lk_sizes_dartino.txt');
  List<String> baselineLines =
      new File(lkBaselineSizeFile.toFilePath()).readAsLinesSync();
  List<String> dartinoLines =
      new File(lkDartinoSizeFile.toFilePath()).readAsLinesSync();
  List<String> baselineKeys = trimAll(baselineLines[0].split('\t'));
  List<String> baselineValues = trimAll(baselineLines[1].split('\t'));
  List<String> dartinoKeys = trimAll(dartinoLines[0].split('\t'));
  List<String> dartinoValues = trimAll(dartinoLines[1].split('\t'));
  List<String> interestingKeys = ['text', 'data', 'bss'];
  for (int i = 0; i < baselineKeys.length; i++) {
    for (var key in interestingKeys) {
      if (baselineKeys[i] == key) {
        int lkDartinoValue = int.parse(dartinoValues[i]);
        int lkBaselineValue = int.parse(baselineValues[i]);
        int dartinoSize = lkDartinoValue - lkBaselineValue;
        print("DartinoARMBinarySize_$key(CodeSize): ${dartinoSize}");
      }
    }
  }
}
