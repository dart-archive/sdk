// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename to _DoubleImpl.
abstract class double implements core.double {
  int get hashCode => truncate();

  @native external int ceil();

  @native external String toString();

  @native external num operator -();

  @native num operator +(other) {
    // TODO(kasperl): Check error.
    return other._addFromDouble(this);
  }

  @native num operator -(other) {
    // TODO(kasperl): Check error.
    return other._subFromDouble(this);
  }

  @native num operator *(other) {
    // TODO(kasperl): Check error.
    return other._mulFromDouble(this);
  }

  @native num operator %(other) {
    // TODO(kasperl): Check error.
    return other._modFromDouble(this);
  }

  @native num operator /(other) {
    // TODO(kasperl): Check error.
    return other._divFromDouble(this);
  }

  @native bool operator ==(other) {
    // TODO(kasperl): Check error.
    return other._compareEqFromDouble(this);
  }

  @native bool operator <(other) {
    // TODO(kasperl): Check error.
    return other._compareLtFromDouble(this);
  }

  @native bool operator <=(other) {
    // TODO(kasperl): Check error.
    return other._compareLeFromDouble(this);
  }

  @native bool operator >(other) {
    // TODO(kasperl): Check error.
    return other._compareGtFromDouble(this);
  }

  @native bool operator >=(other) {
    // TODO(kasperl): Check error.
    return other._compareGeFromDouble(this);
  }

  @native int truncate() {
    throw new UnsupportedError("double.truncate $this");
  }
}
