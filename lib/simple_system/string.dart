// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename String to e.g. _StringImpl.
abstract class String implements Comparable<String>, Pattern {
  static core.String fromCharCode(core.int charCode) {
    var result = _create(1);
    result._setCodeUnitAt(0, charCode);
    return result;
  }

  /* core.String */ toString() => this;

  @native external core.String operator +(core.String other);

  @native external static core.String _create(core.int length);

  @native external void _setCodeUnitAt(core.int offset, core.int char);
}
