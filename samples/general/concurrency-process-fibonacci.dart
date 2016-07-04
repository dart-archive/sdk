// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Concurrency sample that uses concurrent processes to calculate Fibinacci
// numbers and increment a counter. Illustrates the preemptive scheduling of
// processes.
//
// For additional concurrency info, see https://dartino.org/guides/concurrency/
import 'dart:dartino';

void main() {
  // Spawn a separate process that will calculate Fibonacci numbers.
  Process.spawn(doFibonacci);

  // Run doCount in the the main fiber of the main process.
  doCount();
}

void doCount() {
  int i = 0;
  while (i < 30) {
    i++;
    print("I'm still alive $i");
    sleep(1000);
  }
}

void doFibonacci() {
  int f = 25;
  while (true) {
    f++;
    int result = fibonacci(f);
    print("Fibonacci of $f is $result");
  }
}

int fibonacci(int f) {
  if (f == 0)
    return 0;
  else if (f == 1)
    return 1;
  else
    return fibonacci(f - 1) + fibonacci(f - 2);
}
