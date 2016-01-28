// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library immutable.rbtree_test;

import 'package:immutable/immutable.dart';

import 'package:test/test.dart';

main() {
  group('immutable', () {
    group('red-black-tree', () {
      const NUM = 1000 * 1000;

      test('insert-increasing', () {
        var tree = new RedBlackTree();

        for (int i = 0; i < NUM; i++) {
          tree = tree.insert(i, 100 + i);
        }

        for (int i = 0; i < NUM; i++) {
          expect(tree.lookup(i), 100 + i);
        }
      });

      test('insert-decreasing', () {
        var tree = new RedBlackTree();

        for (int i = NUM; i > 0; i--) {
          tree = tree.insert(i, 100 + i);
        }

        for (int i = NUM; i > 0; i--) {
          expect(tree.lookup(i), 100 + i);
        }
      });

      test('insert-divide-and-conquer', () {
        var tree = new RedBlackTree();

        insertRange(int from, int to) {
          if (from == to) {
            tree = tree.insert(from, 100 + from);
          } else {
            int mid = from + (to - from) ~/ 2;
            insertRange(mid + 1, to);
            insertRange(from, mid);
          }
        }

        insertRange(0, NUM - 1);
        for (int i = 0; i < NUM; i++) {
          expect(tree.lookup(i), 100 + i);
        }
      });
    });
  });
}

