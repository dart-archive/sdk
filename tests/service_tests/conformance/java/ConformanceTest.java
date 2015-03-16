// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.*;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.List;

class ConformanceTest {
  public static void main(String args[]) {
    // Expecting a snapshot of the dart service code on the command line.
    if (args.length != 1) {
      System.out.println("Usage: java ConformanceTest <snapshot>");
      System.exit(1);
    }

    // Load libfletch.so.
    System.loadLibrary("fletch");

    // Setup Fletch.
    FletchApi.Setup();
    FletchServiceApi.Setup();
    FletchApi.AddDefaultSharedLibrary("libfletch.so");

    try {
      // Load snapshot and start Dart code on a separate thread.
      FileInputStream snapshotStream = new FileInputStream(args[0]);
      int available = snapshotStream.available();
      byte[] snapshot = new byte[available];
      snapshotStream.read(snapshot);
      Thread dartThread = new Thread(new SnapshotRunner(snapshot));
      dartThread.start();
    } catch (FileNotFoundException e) {
      System.err.println("Failed loading snapshot");
      System.exit(1);
    } catch (IOException e) {
      System.err.println("Failed loading snapshot");
      System.exit(1);
    }

    // Run conformance tests.
    ConformanceService.Setup();
    runPersonTests();
    runPersonBoxTests();
    runNodeTests();
    ConformanceService.TearDown();
  }

  private static void buildPerson(PersonBuilder person, int n) {
    person.setAge(n * 20);
    if (n > 1) {
      PersonListBuilder children = person.initChildren(2);
      buildPerson(children.get(0), n - 1);
      buildPerson(children.get(1), n - 1);
    }
  }

  private static void runPersonTests() {
    {
      MessageBuilder builder = new MessageBuilder(512);
      PersonBuilder person = new PersonBuilder();
      builder.initRoot(person, PersonBuilder.kSize);
      buildPerson(person, 7);
      assert 3128 == builder.computeUsed();
      int age = ConformanceService.getAge(person);
      assert 140 == age;
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      PersonBuilder person = new PersonBuilder();
      builder.initRoot(person, PersonBuilder.kSize);
      buildPerson(person, 7);
      assert 3128 == builder.computeUsed();
      ConformanceService.getAgeAsync(
          person,
          new ConformanceService.GetAgeCallback() {
            public void handle(int age) {
              assert 140 == age;
            }
          });
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      PersonBuilder person = new PersonBuilder();
      builder.initRoot(person, PersonBuilder.kSize);
      buildPerson(person, 7);
      assert 3128 == builder.computeUsed();
      int count = ConformanceService.count(person);
      assert 127 == count;
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      PersonBuilder person = new PersonBuilder();
      builder.initRoot(person, PersonBuilder.kSize);
      buildPerson(person, 7);
      assert 3128 == builder.computeUsed();
      ConformanceService.countAsync(
          person,
          new ConformanceService.CountCallback() {
              public void handle(int count) {
                assert 127 == count;
              }
            });
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      PersonBuilder person = new PersonBuilder();
      builder.initRoot(person, PersonBuilder.kSize);
      buildPerson(person, 7);
      assert 3128 == builder.computeUsed();
      AgeStats stats = ConformanceService.getAgeStats(person);
      assert 39 == stats.getAverageAge();
      assert 4940 == stats.getSum();
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      PersonBuilder person = new PersonBuilder();
      builder.initRoot(person, PersonBuilder.kSize);
      buildPerson(person, 7);
      assert 3128 == builder.computeUsed();
      ConformanceService.getAgeStatsAsync(
          person,
          new ConformanceService.GetAgeStatsCallback() {
            public void handle(AgeStats stats) {
              assert 39 == stats.getAverageAge();
              assert 4940 == stats.getSum();
            }
          });
    }

    {
      AgeStats stats = ConformanceService.createAgeStats(42, 42);
      assert 42 == stats.getAverageAge();
      assert 42 == stats.getSum();
    }

    {
      ConformanceService.createAgeStatsAsync(
          42, 42,
          new ConformanceService.CreateAgeStatsCallback() {
            public void handle(AgeStats stats) {
              assert 42 == stats.getAverageAge();
              assert 42 == stats.getSum();
            }
          });
    }

    {
      Person generated = ConformanceService.createPerson(10);
      assert 42 == generated.getAge();
      String name = generated.getName();
      assert 6 == name.length();
      assert name.equals("person");
      Uint16List nameData = generated.getNameData();
      assert 6 == nameData.size();
      assert "p".charAt(0) == nameData.get(0);
      assert "n".charAt(0) == nameData.get(5);
      PersonList children = generated.getChildren();
      assert 10 == children.size();
      for (int i = 0; i < children.size(); i++) {
        assert (12 + i * 2) == children.get(i).getAge();
      }
    }

    {
      ConformanceService.createPersonAsync(
          10,
          new ConformanceService.CreatePersonCallback() {
            public void handle(Person generated) {
              assert 42 == generated.getAge();
              String name = generated.getName();
              assert 6 == name.length();
              assert name.equals("person");
              Uint16List nameData = generated.getNameData();
              assert 6 == nameData.size();
              assert "p".charAt(0) == nameData.get(0);
              assert "n".charAt(0) == nameData.get(5);
              PersonList children = generated.getChildren();
              assert 10 == children.size();
              for (int i = 0; i < children.size(); i++) {
                assert (12 + i * 2) == children.get(i).getAge();
              }
            }
          });
    }

    ConformanceService.foo();
    ConformanceService.fooAsync(new ConformanceService.FooCallback() {
        public void handle() { }
    });

    {
      MessageBuilder builder = new MessageBuilder(512);
      EmptyBuilder empty = new EmptyBuilder();
      builder.initRoot(empty, EmptyBuilder.kSize);
      int i = ConformanceService.bar(empty);
      assert 24 == i;
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      EmptyBuilder empty = new EmptyBuilder();
      builder.initRoot(empty, EmptyBuilder.kSize);
      ConformanceService.barAsync(empty, new ConformanceService.BarCallback() {
        public void handle(int i) { assert 24 == i; }
      });
    }

    assert 42 == ConformanceService.ping();
    ConformanceService.pingAsync(new ConformanceService.PingCallback() {
        public void handle(int result) { assert 42 == result; }
    });

    {
      MessageBuilder builder = new MessageBuilder(512);
      TableFlipBuilder flip = new TableFlipBuilder();
      builder.initRoot(flip, TableFlipBuilder.kSize);
      String expectedFlip = "(╯°□°）╯︵ ┻━┻";
      flip.setFlip(expectedFlip);
      TableFlip flipResult = ConformanceService.flipTable(flip);
      assert flipResult.getFlip().equals(expectedFlip);
    }

    {
      MessageBuilder builder = new MessageBuilder(512);
      TableFlipBuilder flip = new TableFlipBuilder();
      builder.initRoot(flip, TableFlipBuilder.kSize);
      final String expectedFlip = "(╯°□°）╯︵ ┻━┻";
      flip.setFlip(expectedFlip);
      ConformanceService.flipTableAsync(
          flip,
          new ConformanceService.FlipTableCallback() {
            public void handle(TableFlip flipResult) {
              assert flipResult.getFlip().equals(expectedFlip);
            };
          });
    }
  }

  private static void runPersonBoxTests() {
    MessageBuilder builder = new MessageBuilder(512);

    PersonBoxBuilder box = new PersonBoxBuilder();
    builder.initRoot(box, PersonBoxBuilder.kSize);
    PersonBuilder person = box.initPerson();
    person.setAge(87);
    person.setName("fisk");
    int age = ConformanceService.getBoxedAge(box);
    assert 87 == age;
  }


  private static int depth(Node node) {
    if (node.isNum()) return 1;
    int left = depth(node.getCons().getFst());
    int right = depth(node.getCons().getSnd());
    return 1 + ((left > right) ? left : right);
  }

  private static void buildNode(NodeBuilder node, int n) {
    if (n > 1) {
      ConsBuilder cons = node.initCons();
      buildNode(cons.initFst(), n - 1);
      buildNode(cons.initSnd(), n - 1);
    } else {
      node.setCond(true);
      node.setNum(42);
    }
  }

  private static void runNodeTests() {
    MessageBuilder builder = new MessageBuilder(512);

    NodeBuilder root = new NodeBuilder();
    builder.initRoot(root, NodeBuilder.kSize);
    buildNode(root, 10);
    int depth = ConformanceService.depth(root);
    assert 10 == depth;

    Node node = ConformanceService.createNode(10);
    assert 24680 == node.computeUsed();
    assert 10 == depth(node);
  }
}
