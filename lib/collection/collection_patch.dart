// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;

const patch = "patch";

@patch class LinkedHashMap<K, V> {
  @patch factory LinkedHashMap({ bool equals(K key1, K key2),
                                 int hashCode(K key),
                                 bool isValidKey(potentialKey) }) {
    if (equals != null ||
        hashCode != null ||
        isValidKey != null) {
      throw new UnsupportedError("LinkedHashMap arguments are not implemented");
    }
    return new fletch.LinkedHashMapImpl<K, V>();
  }
}

@patch class LinkedHashSet<E> {
  @patch factory LinkedHashSet({ bool equals(E key1, E key2),
                                 int hashCode(E key),
                                 bool isValidKey(potentialKey) }) {
    if (equals != null ||
        hashCode != null ||
        isValidKey != null) {
      throw new UnsupportedError("LinkedHashMap arguments are not implemented");
    }
    return new fletch.LinkedHashSetImpl<E>();
  }
}
