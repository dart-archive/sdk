// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.src.guess_configuration;

import 'dart:io' show
    File,
    Link,
    Platform,
    Process;

const String _DARTINO_VM = const String.fromEnvironment("dartino-vm");

Uri get executable {
  return Uri.base.resolveUri(new Uri.file(Platform.resolvedExecutable));
}

bool _looksLikeDartinoVm(Uri uri) {
  return new File.fromUri(uri).existsSync();
}

// TODO(zerny): Guessing the VM path should only happen once and only if no
// prior configuration has happend. Make this a private method in
// dartino_compiler.dart
Uri guessDartinoVm(Uri dartinoVm, {bool mustExist: true}) {
  if (dartinoVm == null && _DARTINO_VM != null) {
    // Use Uri.base here because _DARTINO_VM is a constant relative to the
    // location of where the Dart VM was started, not relative to the C++
    // client.
    dartinoVm = Uri.base.resolve(_DARTINO_VM);
  } else {
    Uri uri = executable.resolve('dartino-vm');
    if (new File.fromUri(uri).existsSync()) {
      dartinoVm = uri;
    }
  }
  if (dartinoVm == null) {
    if (!mustExist) return null;
    throw new StateError("""
Unable to guess the location of the dartino VM (dartinoVm).
Try adding command-line option '-Ddartino-vm=<path to dartino VM>.""");
  } else if (!_looksLikeDartinoVm(dartinoVm)) {
    if (!mustExist) return null;
    throw new StateError("""
No dartino VM at '$dartinoVm'.
Try adding command-line option '-Ddartino-vm=<path to dartino VM>.""");
  }
  return dartinoVm;
}

String _cachedDartinoVersion;

String get dartinoVersion {
  if (_cachedDartinoVersion != null) return _cachedDartinoVersion;
  _cachedDartinoVersion = const String.fromEnvironment('dartino.version');
  if (_cachedDartinoVersion != null) return _cachedDartinoVersion;
  Uri dartinoVm = guessDartinoVm(null, mustExist: false);
  if (dartinoVm != null) {
    String vmPath = dartinoVm.toFilePath();
    return _cachedDartinoVersion =
        Process.runSync(vmPath, <String>["--version"]).stdout.trim();
  }
  return _cachedDartinoVersion = "version information not available";
}
