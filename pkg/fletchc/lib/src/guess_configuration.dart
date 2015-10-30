// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.src.guess_configuration;

import 'dart:io' show
    File,
    Link,
    Platform,
    Process;

const String _FLETCH_VM = const String.fromEnvironment("fletch-vm");

Uri get executable {
  return Uri.base.resolveUri(new Uri.file(Platform.resolvedExecutable));
}

bool _looksLikeFletchVm(Uri uri) {
  return new File.fromUri(uri).existsSync();
}

Uri guessFletchVm(Uri fletchVm, {bool mustExist: true}) {
  if (fletchVm == null && _FLETCH_VM != null) {
    // Use Uri.base here because _FLETCH_VM is a constant relative to the
    // location of where the Dart VM was started, not relative to the C++
    // client.
    fletchVm = Uri.base.resolve(_FLETCH_VM);
  } else {
    Uri uri = executable.resolve('fletch-vm');
    if (new File.fromUri(uri).existsSync()) {
      fletchVm = uri;
    }
  }
  if (fletchVm == null) {
    if (!mustExist) return null;
    throw new StateError("""
Unable to guess the location of the fletch VM (fletchVm).
Try adding command-line option '-Dfletch-vm=<path to fletch VM>.""");
  } else if (!_looksLikeFletchVm(fletchVm)) {
    if (!mustExist) return null;
    throw new StateError("""
No fletch VM at '$fletchVm'.
Try adding command-line option '-Dfletch-vm=<path to fletch VM>.""");
  }
  return fletchVm;
}

String _cachedFletchVersion;

String get fletchVersion {
  if (_cachedFletchVersion != null) return _cachedFletchVersion;
  _cachedFletchVersion = const String.fromEnvironment('fletch.version');
  if (_cachedFletchVersion != null) return _cachedFletchVersion;
  Uri fletchVm = guessFletchVm(null, mustExist: false);
  if (fletchVm != null) {
    String vmPath = fletchVm.toFilePath();
    return _cachedFletchVersion =
        Process.runSync(vmPath, <String>["--version"]).stdout.trim();
  }
  return _cachedFletchVersion = "version information not available";
}
