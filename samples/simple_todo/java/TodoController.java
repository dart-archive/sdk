// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import dartino.*;

class TodoController {
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
