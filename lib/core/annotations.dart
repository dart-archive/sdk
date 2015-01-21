// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
const Deprecated deprecated = const Deprecated("next release");

// Matches dart:core on Jan 21, 2015.
const Object override = const _Override();

// Matches dart:core on Jan 21, 2015.
const Object proxy = const _Proxy();

// Matches dart:core on Jan 21, 2015.
class Deprecated {
  final String expires;
  const Deprecated(this.expires);
  String toString() => "Deprecated feature. Will be removed $expires";
}

class _Override {
  const _Override();
}

class _Proxy {
  const _Proxy();
}

class _CyclicInitializationMarker {
  const _CyclicInitializationMarker();
}
