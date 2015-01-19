# Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Compile using:
#
#   $ capnp compile -o ./capnp-dart.sh tests/person.capnp
#

@0xc82815f8a9701393;

struct Person {
  name @0 :Text;
  age @1 :UInt16;
  children @2 :List(Person);
}
