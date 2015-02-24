// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "todomvc_shared.h"
#include "cc/struct.h"
#include "cc/todomvc_presenter.h"
#include "cc/todomvc_service.h"

#include <cstdio>
#include <cstring>
#include <vector>
#include <string>

static int trim(char* str) {
  if (!str) return 0;
  int first = 0;
  while (str[first] == ' ') ++first;

  int last = first;
  while (str[last] != '\0') ++last;

  while (last-- > 0 && (str[last] == ' ' || str[last] == '\n'));
  if (last <= 0) return 0;

  int size = 1 + last - first;
  for (int i = 0; i < size; ++i) str[i] = str[first + i];
  str[size] = '\0';

  return size;
}

static bool is(char* str1, const char* str2) {
  return strcmp(str1, str2) == 0;
}

class TodoListView : public TodoMVCPresenter {
 public:
  struct Item {
    std::string title;
    bool done;
  };

  void help() {
    printf("Commands: list, new, del, done, quit, help\n");
  }

  void list() {
    if (!todos.size()) {
      printf("You're all done!\n");
      return;
    }

    for (unsigned i = 0; i < todos.size(); ++i) {
      Item* item = &todos[i];
      printf(" %d. [%s]: %s\n",
             i,
             item->done ? "done" : "todo",
             item->title.c_str());
    }
  }

  void create() {
    static int max_str = 256;
    char buffer[max_str];
    int length = trim(fgets(buffer, max_str, stdin));
    if (!length) {
      printf("Please specify a todo text\n");
      return;
    }
    createItem(buffer);
  }

  void destroy() {
    int id = readId();
    if (id < 0) {
      printf("Invalid todo index\n");
      return;
    }
    deleteItem(id);
  }

  void done() {
    int id = readId();
    if (id < 0) {
      printf("Invalid todo index\n");
      return;
    }
    completeItem(id);
  }

  void clear() {
    clearItems();
  }

 private:
  int readId() {
    int id = 0;
    int match = fscanf(stdin, "%d", &id);
    return (match == 1) ? id : -1;
  }

  // State when applying a patch. We assume a right-hanging encoding of a list.
  enum Context { IN_LIST, IN_ITEM, IN_TITLE, IN_DONE };
  Context context;
  int index;

  void enterPatch() {
    context = IN_LIST;
    index = 0;
  }

  void enterConsFst() {
    context = (context == IN_ITEM) ? IN_TITLE : IN_ITEM;
  }

  void enterConsSnd() {
    if (context == IN_ITEM) context = IN_DONE;
    else index++;
  }

  void updateNode(const Node& node) {
    switch (context) {
      case IN_TITLE:
        todos[index].title = str(node.getStr());
        break;
      case IN_DONE:
        todos[index].done = node.getBool();
        break;
      case IN_ITEM:
        todos[index] = newItem(node);
        break;
      case IN_LIST:
        todos.resize(index);
        addItems(node);
        break;
      default:
        abort();
    }
  }

  void addItems(const Node& content) {
    if (content.isNil()) return;
    Cons cons = content.getCons();
    addItem(cons.getFst());
    addItems(cons.getSnd());
  }

  void addItem(const Node& content) {
    todos.push_back(newItem(content));
  }

  Item newItem(const Node& content) {
    Cons cons = content.getCons();
    Str title = cons.getFst().getStr();
    bool done = cons.getSnd().getBool();
    return Item { str(title), done };
  }

  std::string str(const Str& s) {
    List<uint8_t> chars = s.getChars();
    std::string out;
    out.reserve(chars.length());
    for (int i = 0; i < chars.length(); ++i) {
      out.push_back(chars[i]);
    }
    return out;
  }

  std::vector<Item> todos;
};

static void InteractWithService() {
  TodoMVCService::setup();
  bool running = true;
  TodoListView view;
  while (running) {
    printf("todo> ");
    char buffer[256];
    int parsed_command = scanf("%255s", buffer);
    if (parsed_command != 1 || is(buffer, "quit")) {
      running = false;
      break;
    }

    if (strcmp(buffer, "list") == 0) {
      view.sync();
      view.list();
    } else if (strcmp(buffer, "new") == 0) {
      view.create();
    } else if (strcmp(buffer, "del") == 0) {
      view.destroy();
    } else if (strcmp(buffer, "done") == 0) {
      view.done();
    } else if (strcmp(buffer, "clear") == 0) {
      view.clear();
    } else if (strcmp(buffer, "help") == 0) {
      view.help();
    } else {
      printf("Invalid command %s\n", buffer);
      view.help();
    }
  }

  printf("Exiting\n");
  TodoMVCService::tearDown();
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot>\n", argv[0]);
    return 1;
  }
  SetupTodoMVC(argc, argv);
  InteractWithService();
  TearDownTodoMVC();
  return 0;
}
