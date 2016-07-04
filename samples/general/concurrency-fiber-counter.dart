// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Concurrency sample that uses three concurrent Fibers to increment a shared
// counter illustrating cooperative scheduling and shared data.
//
// For additional concurrency info, see https://dartino.org/guides/concurrency/
import 'dart:dartino';

// A shared counter incremented by all Fibers.
int sharedCounter = 0;
// An `id` counter used to identify each Fiber.
int fiberId = 0;

void main() {
  Fiber.fork(entry);  // Fiber 1.
  Fiber.fork(entry);  // Fiber 2.
  entry();            // Current Fiber, i.e. Fiber 3.
}

void entry() {
  int currentFiber = fiberId++;
  print('Fiber $currentFiber spawned');

  while (sharedCounter < 10) {
    print("Fiber ${currentFiber}: shared counter is ${sharedCounter}");
    sharedCounter++;

    print('Fiber $currentFiber yielding');
    Fiber.yield();
  }
}
