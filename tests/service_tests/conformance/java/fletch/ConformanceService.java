// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class ConformanceService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class GetAgeCallback {
    public final java.lang.Class returnType = int.class;
    public abstract void handle(int result);
  }

  public static native int getAge(PersonBuilder person);
  public static native void getAgeAsync(PersonBuilder person, GetAgeCallback callback);

  public static abstract class GetBoxedAgeCallback {
    public final java.lang.Class returnType = int.class;
    public abstract void handle(int result);
  }

  public static native int getBoxedAge(PersonBoxBuilder box);
  public static native void getBoxedAgeAsync(PersonBoxBuilder box, GetBoxedAgeCallback callback);

  public static abstract class GetAgeStatsCallback {
    public final java.lang.Class returnType = AgeStats.class;
    public abstract void handle(AgeStats result);
  }

  public static native AgeStats getAgeStats(PersonBuilder person);
  public static native void getAgeStatsAsync(PersonBuilder person, GetAgeStatsCallback callback);

  public static abstract class CreateAgeStatsCallback {
    public final java.lang.Class returnType = AgeStats.class;
    public abstract void handle(AgeStats result);
  }

  public static native AgeStats createAgeStats(int averageAge, int sum);
  public static native void createAgeStatsAsync(int averageAge, int sum, CreateAgeStatsCallback callback);

  public static abstract class CreatePersonCallback {
    public final java.lang.Class returnType = Person.class;
    public abstract void handle(Person result);
  }

  public static native Person createPerson(int children);
  public static native void createPersonAsync(int children, CreatePersonCallback callback);

  public static abstract class CreateNodeCallback {
    public final java.lang.Class returnType = Node.class;
    public abstract void handle(Node result);
  }

  public static native Node createNode(int depth);
  public static native void createNodeAsync(int depth, CreateNodeCallback callback);

  public static abstract class CountCallback {
    public final java.lang.Class returnType = int.class;
    public abstract void handle(int result);
  }

  public static native int count(PersonBuilder person);
  public static native void countAsync(PersonBuilder person, CountCallback callback);

  public static abstract class DepthCallback {
    public final java.lang.Class returnType = int.class;
    public abstract void handle(int result);
  }

  public static native int depth(NodeBuilder node);
  public static native void depthAsync(NodeBuilder node, DepthCallback callback);

  public static abstract class FooCallback {
    public abstract void handle();
  }

  public static native void foo();
  public static native void fooAsync(FooCallback callback);

  public static abstract class BarCallback {
    public final java.lang.Class returnType = int.class;
    public abstract void handle(int result);
  }

  public static native int bar(EmptyBuilder empty);
  public static native void barAsync(EmptyBuilder empty, BarCallback callback);

  public static abstract class PingCallback {
    public final java.lang.Class returnType = int.class;
    public abstract void handle(int result);
  }

  public static native int ping();
  public static native void pingAsync(PingCallback callback);

  public static abstract class FlipTableCallback {
    public final java.lang.Class returnType = TableFlip.class;
    public abstract void handle(TableFlip result);
  }

  public static native TableFlip flipTable(TableFlipBuilder flip);
  public static native void flipTableAsync(TableFlipBuilder flip, FlipTableCallback callback);
}
