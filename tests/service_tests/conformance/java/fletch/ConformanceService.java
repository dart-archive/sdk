// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class ConformanceService {
  public static native void Setup();
  public static native void TearDown();

  public interface GetAgeCallback {
    public void handle(int result);
  }

  public static native int getAge(PersonBuilder person);
  public static native void getAgeAsync(PersonBuilder person, GetAgeCallback callback);

  public interface GetBoxedAgeCallback {
    public void handle(int result);
  }

  public static native int getBoxedAge(PersonBoxBuilder box);
  public static native void getBoxedAgeAsync(PersonBoxBuilder box, GetBoxedAgeCallback callback);

  public interface GetAgeStatsCallback {
    public void handle(AgeStats result);
  }

  public static native AgeStats getAgeStats(PersonBuilder person);
  public static native void getAgeStatsAsync(PersonBuilder person, GetAgeStatsCallback callback);

  public interface CreateAgeStatsCallback {
    public void handle(AgeStats result);
  }

  public static native AgeStats createAgeStats(int averageAge, int sum);
  public static native void createAgeStatsAsync(int averageAge, int sum, CreateAgeStatsCallback callback);

  public interface CreatePersonCallback {
    public void handle(Person result);
  }

  public static native Person createPerson(int children);
  public static native void createPersonAsync(int children, CreatePersonCallback callback);

  public interface CreateNodeCallback {
    public void handle(Node result);
  }

  public static native Node createNode(int depth);
  public static native void createNodeAsync(int depth, CreateNodeCallback callback);

  public interface CountCallback {
    public void handle(int result);
  }

  public static native int count(PersonBuilder person);
  public static native void countAsync(PersonBuilder person, CountCallback callback);

  public interface DepthCallback {
    public void handle(int result);
  }

  public static native int depth(NodeBuilder node);
  public static native void depthAsync(NodeBuilder node, DepthCallback callback);

  public interface FooCallback {
    public void handle();
  }

  public static native void foo();
  public static native void fooAsync(FooCallback callback);

  public interface BarCallback {
    public void handle(int result);
  }

  public static native int bar(EmptyBuilder empty);
  public static native void barAsync(EmptyBuilder empty, BarCallback callback);

  public interface PingCallback {
    public void handle(int result);
  }

  public static native int ping();
  public static native void pingAsync(PingCallback callback);
}
