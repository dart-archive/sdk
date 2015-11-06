// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.*;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import java.lang.NumberFormatException;

class TodoView {
  public TodoView() { }

  public void showMenu() {
    String menu =
        "\n" +
        "   #### Todo Menu ####\n" +
        "m\t-show this menu\n" +
        "l\t-list todo items\n" +
        "a\t-add todo item\n" +
        "t\t-toggle todo item done/undone\n" +
        "c\t-clear done items\n" +
        "d\t-delete item\n" +
        "q\t-quit application";
    System.out.println(menu);
  }

  private String readLine() {
    try {
      BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
      String input = br.readLine();
      return input;
    } catch (IOException exception) {
      exception.printStackTrace();
    }
    return null;
  }

  public String getInput() {
    return readLine();
  }

  // TODO(zarah): In a multithreaded setting this should be atomic or extend
  // the service with a List<Item> getItems to use here instead.
  public void listTodoItems() {
    int count = TodoService.getNoItems();
    System.out.println("-------------------- ToDo's --------------------");
    System.out.printf("Listing %2d items\n", count);
    for (int i = 0; i < count; ++i) {
      TodoItem item = TodoService.getItem(i);
      String done = item.getDone() ? "+" : " ";
      System.out.printf("%2d: %s [%s] \n", item.getId(), item.getTitle(), done);
    }
    System.out.println("------------------------------------------------");
  }

  public void addTodoItem() {
    System.out.println("Add Todo Item:");
    System.out.print("Title: ");
    String title = readLine();
    System.out.println();

    int size = 56 + BoxStringBuilder.kSize + title.length();
    MessageBuilder messageBuilder = new MessageBuilder(size);
    BoxStringBuilder stringBuilder = new BoxStringBuilder();
    messageBuilder.initRoot(stringBuilder, BoxStringBuilder.kSize);
    stringBuilder.setS(title);
    TodoService.createItem(stringBuilder);
  }

  public void toggleTodoItem() {
    System.out.print("[t] Enter id: ");
    String idString = readLine();
    try {
      int id = Integer.parseInt(idString);
      TodoService.toggle(id);
    } catch (NumberFormatException exception) {
      // Ignore bad input.
    }
  }

  public void clearDoneItems() {
    TodoService.clearItems();
  }

  public void deleteItem() {
    System.out.print("[d] Enter id: ");
    String idString = readLine();
    try {
      int id = Integer.parseInt(idString);
      TodoService.deleteItem(id);
    } catch (NumberFormatException exception) {
      // Ignore bad input.
    }
  }
}
