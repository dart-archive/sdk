// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename to e.g. _IntImpl when old compiler is out.
// TODO(ajohnsen): Implements int.
abstract class int {
}

class _Smi extends int {
  /* core.int */ get hashCode => this;

  @native external core.String toString();

  @native external num operator -();
  @native external num operator +(num other);
  @native external num operator -(num other);
  @native external num operator *(num other);
  @native external num operator /(num other);
  @native external int operator ~/(num other);

  @native external int operator ~();
  @native external int operator &(int other);
  @native external int operator |(int other);
  @native external int operator ^(int other);
  @native external int operator >>(int other);
  @native external int operator <<(int other);

  @native external bool operator ==(other);
  @native external bool operator <(num other);
  @native external bool operator <=(num other);
  @native external bool operator >(num other);
  @native external bool operator >=(num other);
}

class _Mint extends int {
  /* core.int */ get hashCode => this;

  @native external core.String toString();

  @native external num operator -();
  @native external num operator +(num other);
  @native external num operator -(num other);
  @native external num operator *(num other);
  @native external num operator /(num other);
  @native external int operator ~/(num other);

  @native external int operator ~();
  @native external int operator &(int other);
  @native external int operator |(int other);
  @native external int operator ^(int other);
  @native external int operator >>(int other);
  @native external int operator <<(int other);

  @native external bool operator ==(other);
  @native external bool operator <(num other);
  @native external bool operator <=(num other);
  @native external bool operator >(num other);
  @native external bool operator >=(num other);
}
