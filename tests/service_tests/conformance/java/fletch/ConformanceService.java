// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import fletch.AgeStats;
import fletch.AgeStatsBuilder;
import fletch.Person;
import fletch.PersonBuilder;
import fletch.Large;
import fletch.LargeBuilder;
import fletch.Small;
import fletch.SmallBuilder;
import fletch.PersonBox;
import fletch.PersonBoxBuilder;
import fletch.Node;
import fletch.NodeBuilder;
import fletch.Cons;
import fletch.ConsBuilder;

public class ConformanceService {
  public static native void Setup();
  public static native void TearDown();

  public static abstract class CreateAgeStatsCallback {
    public abstract void handle(AgeStats result);
  }

  private static native Object createAgeStats_raw(int averageAge, int sum);
  public static native void createAgeStatsAsync(int averageAge, int sum, CreateAgeStatsCallback callback);
  public static AgeStats createAgeStats(int averageAge, int sum) {
    Object rawData = createAgeStats_raw(averageAge, sum);
    if (rawData instanceof byte[]) {
      return new AgeStats((byte[])rawData, 8);
    }
    return new AgeStats((byte[][])rawData, 8);
  }

  public static abstract class CreatePersonCallback {
    public abstract void handle(Person result);
  }

  private static native Object createPerson_raw(int children);
  public static native void createPersonAsync(int children, CreatePersonCallback callback);
  public static Person createPerson(int children) {
    Object rawData = createPerson_raw(children);
    if (rawData instanceof byte[]) {
      return new Person((byte[])rawData, 8);
    }
    return new Person((byte[][])rawData, 8);
  }

  public static abstract class CreateNodeCallback {
    public abstract void handle(Node result);
  }

  private static native Object createNode_raw(int depth);
  public static native void createNodeAsync(int depth, CreateNodeCallback callback);
  public static Node createNode(int depth) {
    Object rawData = createNode_raw(depth);
    if (rawData instanceof byte[]) {
      return new Node((byte[])rawData, 8);
    }
    return new Node((byte[][])rawData, 8);
  }

  public static abstract class FooCallback {
    public abstract void handle();
  }

  public static native void foo();
  public static native void fooAsync(FooCallback callback);

  public static abstract class PingCallback {
    public abstract void handle(int result);
  }

  public static native int ping();
  public static native void pingAsync(PingCallback callback);
}
