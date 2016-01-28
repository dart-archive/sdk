// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library immutable.rbtree_test;

import 'package:immutable/immutable.dart';

import 'package:test/test.dart';

main() {
  group('immutable', () {
    group('linked-list', () {
      test('construct-manually', () {
        var tail = new LinkedList(42, null);
        var head = new LinkedList(43, tail);

        expect(head.length, 2);
        expect(head.head, 43);
        expect(head.tail.head, 42);
        expect(head.tail.tail, null);
      });

      test('fromList', () {
        expect(new LinkedList.fromList([]), null);
        expect(new LinkedList.fromList([42]).head, 42);
        expect(new LinkedList.fromList([42]).tail, null);
        expect(new LinkedList.fromList([42, 43]).head, 42);
        expect(new LinkedList.fromList([42, 43]).tail.head, 43);
        expect(new LinkedList.fromList([42, 43]).tail.tail, null);
      });
    });
  });
}

