// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:math';
import 'dart:typed_data' show ByteData;

import 'person.capnp.dart';
import '../lib/message.dart';
import '../lib/serialize.dart';

void main() {
  for (int i = 0; i < 5; i++) test(10, 100000, 100000);
  test(15, 1000, 1000);
  test(20, 10, 10);
  test(24, 1, 1);
}

void test(int generations, int writeIterations, int readIterations) {
  int expected = pow(2, generations) - 1;
  print('Generating $expected persons:');

  ByteData bytes;
  Stopwatch watch = new Stopwatch()..start();
  for (int i = 0; i < writeIterations; i++) {
    MessageBuilder builder = new BufferedMessageBuilder();
    writePerson(builder.initRoot(new PersonBuilder()), generations);
    bytes = builder.toFlatList();
  }
  watch.stop();

  double mbs = (writeIterations * bytes.lengthInBytes / 1024)
      / watch.elapsedMilliseconds;
  double ps = (writeIterations * expected)
      /  watch.elapsedMilliseconds;
  print('  - writing performance: ${mbs.toStringAsFixed(1)} MB/s :: '
        '${ps.toStringAsFixed(1)}K persons/s');

  int actual;
  watch.reset();
  watch.start();
  for (int i = 0; i < readIterations; i++) {
     MessageReader reader = new BufferedMessageReader(bytes);
     actual = countPersons(reader.getRoot(new Person()));
  }
  watch.stop();

  mbs = (readIterations * bytes.lengthInBytes / 1024)
      / watch.elapsedMilliseconds;
  ps = (readIterations * expected)
      / watch.elapsedMilliseconds;
  print('  - reading performance: ${mbs.toStringAsFixed(1)} MB/s :: '
        '${ps.toStringAsFixed(1)}K persons/s');

  if (actual != expected) {
    print('Expected <$expected> persons for $generations generations, '
          'but got <$actual> persons.');
  }
}

void writePerson(PersonBuilder person, int n) {
  person.age = n * 20;
  if (n > 1) {
    List<PersonBuilder> children = person.initChildren(2);
    writePerson(children[0], n - 1);
    writePerson(children[1], n - 1);
  }
}

int countPersons(Person person) {
  int sum = 1;
  for (Person child in person.children) sum += countPersons(child);
  return sum;
}
