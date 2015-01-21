// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

const Deprecated deprecated = const Deprecated("next release");
const Object override = const _Override();
const Object proxy = const _Proxy();

class Deprecated {
  final String expires;
  const Deprecated(this.expires);
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
