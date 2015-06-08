// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#define TESTING

#include <stdint.h>
#include <sys/time.h>

#include <cstdio>

#include "src/shared/assert.h"  // NOLINT(build/include)
#include "conformance_test_shared.h"  // NOLINT(build/include)
#include "cc/conformance_service.h"  // NOLINT(build/include)

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

static void* FooCallbackData = reinterpret_cast<void*>(101);
static void FooCallback(void* data) {
  EXPECT_EQ(FooCallbackData, data);
}

static void* BarCallbackData = reinterpret_cast<void*>(102);
static void BarCallback(int i, void* data) {
  EXPECT_EQ(BarCallbackData, data);
  EXPECT_EQ(24, i);
}

static void PingCallback(int result, void* data) {
  EXPECT_EQ(42, result);
}

static void CreateAgeStatsCallback(AgeStats stats, void* data) {
  EXPECT_EQ(42, stats.getAverageAge());
  EXPECT_EQ(42, stats.getSum());
  stats.Delete();
}

static void CreatePersonCallback(Person generated, void* data) {
  EXPECT_EQ(42, generated.getAge());
  char* name = generated.getName();
  int name_length = strlen(name);
  EXPECT_EQ(6, name_length);
  EXPECT(strcmp(name, "person") == 0);
  free(name);
  List<uint16_t> name_data = generated.getNameData();
  EXPECT_EQ(6, name_data.length());
  EXPECT_EQ('p', name_data[0]);
  EXPECT_EQ('n', name_data[5]);

  List<Person> children = generated.getChildren();
  EXPECT_EQ(10, children.length());
  for (int i = 0; i < children.length(); i++) {
    EXPECT_EQ(12 + i * 2, children[i].getAge());
  }
  generated.Delete();
}

static void CreateNodeCallback(Node node, void* data) {
  EXPECT_EQ(24680, node.ComputeUsed());
  EXPECT_EQ(10, Depth(node));
  node.Delete();
}

static void GetAgeCallback(int age, void* data) {
  EXPECT_EQ(140, age);
}

static void CountCallback(int count, void* data) {
  EXPECT_EQ(127, count);
}

static void GetAgeStatsCallback(AgeStats stats, void* data) {
  EXPECT_EQ(39, stats.getAverageAge());
  EXPECT_EQ(4940, stats.getSum());
  stats.Delete();
}

static void FlipTableCallback(TableFlip flip_result, void* data) {
  const char* expected_flip = "(╯°□°）╯︵ ┻━┻";
  EXPECT(strcmp(flip_result.getFlip(), expected_flip) == 0);
}

static void RunPersonTests() {
  {
    MessageBuilder builder(512);
    PersonBuilder person = builder.initRoot<PersonBuilder>();
    BuildPerson(person, 7);
    EXPECT_EQ(3136, builder.ComputeUsed());
    int age = ConformanceService::getAge(person);
    EXPECT_EQ(140, age);
  }

  {
    MessageBuilder builder(512);
    PersonBuilder person = builder.initRoot<PersonBuilder>();
    BuildPerson(person, 7);
    EXPECT_EQ(3136, builder.ComputeUsed());
    ConformanceService::getAgeAsync(person, GetAgeCallback, NULL);
  }

  {
    MessageBuilder builder(512);
    PersonBuilder person = builder.initRoot<PersonBuilder>();
    BuildPerson(person, 7);
    EXPECT_EQ(3136, builder.ComputeUsed());
    int count = ConformanceService::count(person);
    EXPECT_EQ(127, count);
  }

  {
    MessageBuilder builder(512);
    PersonBuilder person = builder.initRoot<PersonBuilder>();
    BuildPerson(person, 7);
    EXPECT_EQ(3136, builder.ComputeUsed());
    ConformanceService::countAsync(person, CountCallback, NULL);
  }

  {
    MessageBuilder builder(512);
    PersonBuilder person = builder.initRoot<PersonBuilder>();
    BuildPerson(person, 7);
    EXPECT_EQ(3136, builder.ComputeUsed());
    AgeStats stats = ConformanceService::getAgeStats(person);
    EXPECT_EQ(39, stats.getAverageAge());
    EXPECT_EQ(4940, stats.getSum());
    stats.Delete();
  }

  {
    MessageBuilder builder(512);
    PersonBuilder person = builder.initRoot<PersonBuilder>();
    BuildPerson(person, 7);
    EXPECT_EQ(3136, builder.ComputeUsed());
    ConformanceService::getAgeStatsAsync(person, GetAgeStatsCallback, NULL);
  }

  {
    AgeStats stats = ConformanceService::createAgeStats(42, 42);
    EXPECT_EQ(42, stats.getAverageAge());
    EXPECT_EQ(42, stats.getSum());
    stats.Delete();
  }

  ConformanceService::createAgeStatsAsync(42, 42, CreateAgeStatsCallback, NULL);

  {
    Person generated = ConformanceService::createPerson(10);
    char* name = generated.getName();
    int name_length = strlen(name);
    EXPECT_EQ(42, generated.getAge());
    EXPECT_EQ(6, name_length);
    EXPECT(strcmp(name, "person") == 0);
    free(name);
    List<uint16_t> name_data = generated.getNameData();
    EXPECT_EQ(6, name_data.length());
    EXPECT_EQ('p', name_data[0]);
    EXPECT_EQ('n', name_data[5]);

    List<Person> children = generated.getChildren();
    EXPECT_EQ(10, children.length());
    for (int i = 0; i < children.length(); i++) {
      EXPECT_EQ(12 + i * 2, children[i].getAge());
    }
    generated.Delete();
  }

  ConformanceService::createPersonAsync(10, CreatePersonCallback, NULL);

  ConformanceService::foo();
  ConformanceService::fooAsync(FooCallback, FooCallbackData);

  {
    MessageBuilder builder(512);
    EmptyBuilder empty = builder.initRoot<EmptyBuilder>();
    int i = ConformanceService::bar(empty);
    EXPECT_EQ(24, i);
  }

  {
    MessageBuilder builder(512);
    EmptyBuilder empty = builder.initRoot<EmptyBuilder>();
    ConformanceService::barAsync(empty, BarCallback, BarCallbackData);
  }

  EXPECT_EQ(42, ConformanceService::ping());
  ConformanceService::pingAsync(PingCallback, NULL);

  {
    MessageBuilder builder(512);
    TableFlipBuilder flip = builder.initRoot<TableFlipBuilder>();
    const char* expected_flip = "(╯°□°）╯︵ ┻━┻";
    flip.setFlip(expected_flip);
    TableFlip flip_result = ConformanceService::flipTable(flip);
    EXPECT(strcmp(flip_result.getFlip(), expected_flip) == 0);
  }

  {
    MessageBuilder builder(512);
    TableFlipBuilder flip = builder.initRoot<TableFlipBuilder>();
    flip.setFlip("(╯°□°）╯︵ ┻━┻");
    ConformanceService::flipTableAsync(flip, FlipTableCallback, NULL);
  }
}

static void RunPersonBoxTests() {
  MessageBuilder builder(512);

  PersonBoxBuilder box = builder.initRoot<PersonBoxBuilder>();
  PersonBuilder person = box.initPerson();
  person.setAge(87);
  person.setName("fisk");

  int age = ConformanceService::getBoxedAge(box);
  EXPECT_EQ(87, age);
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
  int depth = ConformanceService::depth(root);
  EXPECT_EQ(10, depth);

  Node node = ConformanceService::createNode(10);
  EXPECT_EQ(24680, node.ComputeUsed());
  EXPECT_EQ(10, Depth(node));
  node.Delete();

  ConformanceService::createNodeAsync(10, CreateNodeCallback, NULL);
}

static void InteractWithService() {
  ConformanceService::setup();
  RunPersonTests();
  RunPersonBoxTests();
  RunNodeTests();
  ConformanceService::tearDown();
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot>\n", argv[0]);
    return 1;
  }
  SetupConformanceTest(argc, argv);
  InteractWithService();
  TearDownConformanceTest();
  return 0;
}
