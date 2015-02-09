// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

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
  BuildPerson(person, 5);
  uint64_t end = GetMicroseconds();

  int used = builder.ComputeUsed();
  int building_us = static_cast<int>(end - start);
  printf("Building took %.2f ms.\n", building_us / 1000.0);
  printf("    - %.2f MB/s\n", static_cast<double>(used) / building_us);

  int age = PersonCounter::getAge(person);
  start = GetMicroseconds();
  int count = PersonCounter::count(person);
  end = GetMicroseconds();
  AgeStats stats = PersonCounter::getAgeStats(person);
  printf("AgeStats avg: %d sum: %d\n", stats.getAverageAge(), stats.getSum());
  stats.Delete();
  AgeStats stats2 = PersonCounter::createAgeStats(42, 42);
  printf("AgeStats create avg: %d sum: %d \n",
         stats2.getAverageAge(),
         stats2.getSum());
  stats2.Delete();
  Person generated = PersonCounter::createPerson(10);
  printf("Generate age: %d\n", generated.getAge());
  List<Person> children = generated.getChildren();
  printf("Generated children: %d ages: [ ", children.length());
  for (int i = 0; i < children.length(); i++) {
    if (i != 0) printf(", ");
    printf("%d", children[i].getAge());
  }
  printf("]\n");
  generated.Delete();
  Node node = PersonCounter::createNode(10);
  int depth = Depth(node);
  printf("Generated Node in Dart with depth: %d\n", depth);
  node.Delete();
  int reading_us = static_cast<int>(end - start);
  printf("Reading took %.2f us.\n", reading_us / 1000.0);
  printf("    - %.2f MB/s\n", static_cast<double>(used) / reading_us);

  printf("Verification: age = %d, count = %d\n", age, count);
}

static void RunPersonBoxTests() {
  MessageBuilder builder(512);

  PersonBoxBuilder box = builder.initRoot<PersonBoxBuilder>();
  PersonBuilder person = box.initPerson();
  person.setAge(87);

  int age = PersonCounter::getBoxedAge(box);
  printf("Verification: age = %d\n", age);
}

static void BuildNode(NodeBuilder node, int n) {
  if (n > 1) {
    ConsBuilder cons = node.initCons();
    BuildNode(cons.initFst(), n - 1);
    BuildNode(cons.initSnd(), n - 1);
  } else {
    node.setNum(42);
  }
}

static void RunNodeTests() {
  MessageBuilder builder(512);

  NodeBuilder root = builder.initRoot<NodeBuilder>();
  BuildNode(root, 10);
  int depth = PersonCounter::depth(root);
  printf("Verification: depth = %d\n", depth);
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
