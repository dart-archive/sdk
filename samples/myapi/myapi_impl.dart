// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library myapi_impl;

const myapi = const Api('MyApi');

int calls = 0;
@myapi MyObject foo() {
  return (calls++ & 1 == 0) ? new Bar() : new Baz();
}

abstract class MyObject {
  @myapi void funk(MyObject o);
}

class Bar implements MyObject {
  void funk(MyObject o) {
    print("Bar!");
    if (o != null) o.funk(null);
  }
}

class Baz implements MyObject {
  void funk(MyObject o) {
    print("Baz!");
    if (o != null) o.funk(null);
  }
}


// ---------------------------------------------------------------

class Api {
  final String name;
  const Api(this.name);
}
