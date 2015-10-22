// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.*;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

class SimpleTodo {

  public static void main(String args[]) {
    // Expecting a snapshot of the dart service code on the command line.
    if (args.length != 1) {
      System.out.println("Usage: java SimpleTodo <snapshot>");
      System.exit(1);
    }

    // Load libfletch.so.
    System.loadLibrary("fletch");

    // Setup Fletch.
    FletchApi.Setup();
    FletchServiceApi.Setup();
    FletchApi.AddDefaultSharedLibrary("libfletch.so");

    try {
      // Load snapshot and start dart code on a separate thread.
      FileInputStream snapshotStream = new FileInputStream(args[0]);
      int available = snapshotStream.available();
      byte[] snapshot = new byte[available];
      snapshotStream.read(snapshot);
      Thread dartThread = new Thread(new SnapshotRunner(snapshot));
      dartThread.start();
    } catch (FileNotFoundException e) {
      System.err.println("Failed loading snapshot: file not found.");
      System.exit(1);
    } catch (IOException e) {
      System.err.println("Failed loading snapshot: unknown error.");
      System.exit(1);
    }

    InteractWithService();
  }

  static void InteractWithService() {
    TodoService.Setup();

    TodoView view = new TodoView();
    view.showMenu();
    boolean should_terminate = false;
    do {
      String input = view.getInput();
      if (null == input) {
        should_terminate = true;
        break;
      }
      switch (input) {
        case "q":
          should_terminate = true;
          break;
        case "m":
          view.showMenu();
          break;
        case "l":
          view.listTodoItems();
          break;
        case "a":
          view.addTodoItem();
          view.listTodoItems();
          break;
        case "t":
          view.toggleTodoItem();
          view.listTodoItems();
          break;
        case "c":
          view.clearDoneItems();
          view.listTodoItems();
          break;
        case "d":
          view.deleteItem();
          view.listTodoItems();
          break;
        default:
          view.showMenu();
          break;
      }
    } while (!should_terminate);

    TodoService.TearDown();
  }
}
