// Copyright (c) 2011, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library benchmark_base;


class Expect {
  static void equals(var expected, var actual) {
    if (expected != actual) {
      throw "Values not equal: $expected vs $actual";
    }
  }

  static void listEquals(List expected, List actual) {
    if (expected.length != actual.length) {
      throw "Lists have different lengths: ${expected.length} vs ${actual.length}";
    }
    for (int i = 0; i < actual.length; i++) {
      equals(expected[i], actual[i]);
    }
  }

  fail(message) {
    throw message;
  }
}


const int MILLIS_PER_SECOND = 1000;
const int MICROS_PER_SECOND = 1000000;


class BenchmarkBase {
  final String name;

  // Empty constructor.
  const BenchmarkBase(String name) : this.name = name;

  // The benchmark code.
  // This function is not used, if both [warmup] and [exercise] are overwritten.
  void run() { }

  // Runs a short version of the benchmark. By default invokes [run] once.
  void warmup() {
    run();
  }

  // Exercices the benchmark. By default invokes [run] 10 times.
  void exercise() {
    for (int i = 0; i < 10; i++) {
      run();
    }
  }

  // Not measured setup code executed prior to the benchmark runs.
  void setup() { }

  // Not measured teardown code executed after the benchark runs.
  void teardown() { }

  // Measures the score for this benchmark by executing it repeately until
  // millisMinimum milliseconds has been reached.
  int measureFor(int millisMinimum) {
    int iter = 0;
    int elapsed = 0;
    Stopwatch watch = new Stopwatch();
    // StopWatch.frequency is in Hz.
    int ticksMinimum = watch.frequency * millisMinimum ~/ MILLIS_PER_SECOND;
    watch.start();
    while (elapsed < ticksMinimum) {
      exercise();
      elapsed = watch.elapsedTicks;
      iter++;
    }
    return (elapsed * MICROS_PER_SECOND) ~/ watch.frequency ~/ iter;
  }

  // Measures the score for the benchmark and returns it.
  int measure() {
    setup();
    // Warmup for at least 100ms. Discard result.
    measureFor(100);
    // Run the benchmark for at least 2000ms.
    int result = measureFor(2000);
    teardown();
    return result;
  }

  void report() {
    int score = measure();
    print("$name(RunTime): $score us.");
  }

}
