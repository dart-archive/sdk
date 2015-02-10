// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "person_shared.h"
#include "cc/person_counter.h"

#include <cstdio>
#include <stdint.h>
#include <sys/time.h>

static uint64_t GetMicroseconds() {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) return -1;
  uint64_t result = tv.tv_sec * 1000000LL;
  result += tv.tv_usec;
  return result;
}

static void BuildPerson(PersonBuilder person, int n) {
  person.setAge(n * 20);
  if (n > 1) {
    List<PersonBuilder> children = person.initChildren(2);
    BuildPerson(children[0], n - 1);
    BuildPerson(children[1], n - 1);
  }
}

static int Depth(Node node) {
  if (node.isNum()) return 1;
  int left = Depth(node.getCons().getFst());
  int right = Depth(node.getCons().getSnd());
  return 1 + ((left > right) ? left : right);
}

static void RunPersonTests() {
  MessageBuilder builder(512);

  uint64_t start = GetMicroseconds();
  PersonBuilder person = builder.initRoot<PersonBuilder>();
  BuildPerson(person, 7);
  uint64_t end = GetMicroseconds();

  int used = builder.ComputeUsed();
  int building_us = static_cast<int>(end - start);
  printf("Generated size: %i bytes\n", used);
  printf("Building (c++) took %i us.\n", building_us);
  printf("    - %.2f MB/s\n", static_cast<double>(used) / building_us);

  int age = PersonCounter::getAge(person);
  ASSERT(age == 140);
  start = GetMicroseconds();
  int count = PersonCounter::count(person);
  end = GetMicroseconds();
  ASSERT(count == 127);
  int reading_us = static_cast<int>(end - start);
  printf("Reading (fletch) took %i us.\n", reading_us);
  printf("    - %.2f MB/s\n", static_cast<double>(used) / reading_us);

  AgeStats stats = PersonCounter::getAgeStats(person);
  ASSERT(stats.getAverageAge() == 39);
  ASSERT(stats.getSum() == 4940);
  stats.Delete();
  AgeStats stats2 = PersonCounter::createAgeStats(42, 42);
  ASSERT(stats2.getAverageAge() == 42);
  ASSERT(stats2.getSum() == 42);
  stats2.Delete();
  Person generated = PersonCounter::createPerson(10);

  ASSERT(generated.getAge() == 42);
  List<Person> children = generated.getChildren();
  ASSERT(children.length() == 10);
  for (int i = 0; i < children.length(); i++) {
    ASSERT(children[i].getAge() == 12 + i * 2);
  }
  generated.Delete();
  start = GetMicroseconds();
  Node node = PersonCounter::createNode(10);
  end = GetMicroseconds();
  building_us = static_cast<int>(end - start);
  used = node.ComputeUsed();
  printf("Generated size: %i bytes\n", used);
  printf("Building (fletch) took %i us.\n", building_us);
  printf("    - %.2f MB/s\n", static_cast<double>(used) / building_us);
  int depth = Depth(node);
  printf("Generated Node in Dart with depth: %d\n", depth);
  node.Delete();
}

static void RunPersonBoxTests() {
  MessageBuilder builder(512);

  PersonBoxBuilder box = builder.initRoot<PersonBoxBuilder>();
  PersonBuilder person = box.initPerson();
  person.setAge(87);

  int age = PersonCounter::getBoxedAge(box);
  ASSERT(age == 87);
}

static void BuildNode(NodeBuilder node, int n) {
  if (n > 1) {
    ConsBuilder cons = node.initCons();
    BuildNode(cons.initFst(), n - 1);
    BuildNode(cons.initSnd(), n - 1);
  } else {
    node.setCond(true);
    node.setNum(42);
  }
}

static void RunNodeTests() {
  MessageBuilder builder(512);

  NodeBuilder root = builder.initRoot<NodeBuilder>();
  BuildNode(root, 10);
  int depth = PersonCounter::depth(root);
  ASSERT(depth == 10);
}

static void InteractWithService() {
  PersonCounter::setup();
  RunPersonTests();
  RunPersonBoxTests();
  RunNodeTests();
  PersonCounter::tearDown();
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot>\n", argv[0]);
    return 1;
  }
  SetupPersonTest(argc, argv);
  InteractWithService();
  TearDownPersonTest();
  return 0;
}
