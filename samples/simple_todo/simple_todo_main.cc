// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <pthread.h>
#include <stdlib.h>

#include "include/fletch_api.h"
#include "include/service_api.h"
#include "generated/cc/simple_todo.h"

static const int kDone = 1;
static pthread_mutex_t mutex;
static pthread_cond_t cond;
static int status = 0;

typedef enum {
  EC_OK = 0,
  EC_THREAD,
  EC_INPUT_ERR,
} ErrorCode;

static void ChangeStatusAndNotify(int new_status) {
  pthread_mutex_lock(&mutex);
  status = new_status;
  pthread_cond_signal(&cond);
  pthread_mutex_unlock(&mutex);
}

static void WaitForVmThread(int expected) {
  pthread_mutex_lock(&mutex);
  while (expected != status) pthread_cond_wait(&cond, &mutex);
  pthread_mutex_unlock(&mutex);
}

static void* StartFletch(void* arg) {
  char* snapshot_filepath_with_name = reinterpret_cast<char*>(arg);
  FletchSetup();
  FletchRunSnapshotFromFile(snapshot_filepath_with_name);
  FletchTearDown();
  ChangeStatusAndNotify(kDone);
  return NULL;
}

static void StartVmThread(char* snapshot_filename) {
  pthread_mutex_init(&mutex, NULL);
  pthread_cond_init(&cond, NULL);
  pthread_t tid = 0;
  int result = pthread_create(&tid, 0, StartFletch,
                             reinterpret_cast<void*>(snapshot_filename));
  if (result != 0) {
    printf("Error creating thread\n");
    exit(EC_THREAD);
  }
}

class TodoListView {
 public:
  void showMenu() {
    printf("\n   #### Todo Menu ####\n"
           "m\t-show this menu\n"
           "l\t-list todo items\n"
           "a\t-add todo item\n"
           "t\t-toggle todo item done/undone\n"
           "c\t-clear done items\n"
           "d\t-delete item\n"
           "q\t-quit application\n");
  }

  int readln(char* buffer, int buffer_length) {
    int i = 0;
    int ch = 0;

    if ((buffer == NULL) || (buffer_length == 0)) return 0;

    do {
      ch = getchar();
      if (ch != EOF && ch != '\n') {
        buffer[i] = ch;
      }

      if (ch == EOF) return -1;

      ++i;
    } while (ch != '\n' && i < buffer_length);
    buffer[i] = 0;
    return i;
  }

  // TODO(zarah): In a multithreaded setting this should be atomic or extend
  // the service with a List<Item> getItems to use here instead.
  void listTodoItems() {
    int32_t count = TodoService::getNoItems();
    int32_t i = 0;

    printf("-------------------- ToDo's --------------------\n");
    printf("Listing %2u items\n", count);
    for (i = 0; i < count; ++i) {
      TodoItem item = TodoService::getItem(i);
      const char* done = (item.getDone() ? "+" : " ");
      printf("%2u: %s [%1s] \n", item.getId(), item.getTitle(), done);
    }
    printf("------------------------------------------------\n");
  }

  void addTodoItem() {
    char title[60] = {0};
    int title_length = sizeof(title);
    printf("Add Todo Item:\n");
    printf("Title: ");
    title_length = readln(title, title_length);
    printf("\n");

    int size = 56 + BoxString::kSize + title_length;
    MessageBuilder builder(size);
    BoxStringBuilder box = builder.initRoot<BoxStringBuilder>();
    box.setS(title);
    TodoService::createItem(box);
  }

  void toggleTodoItem() {
    char idstr[5] = {0};
    printf("[t] Enter id: ");
    readln(idstr, sizeof(idstr));
    printf("%s\n", idstr);
    TodoService::toggle(atoi(idstr));
  }

  void clear_done_items() {
    TodoService::clearItems();
  }

  void deleteItem() {
    char idstr[5] = {0};
    printf("[d] Enter id: ");
    readln(idstr, sizeof(idstr));
    printf("%s\n", idstr);
    TodoService::deleteItem(atoi(idstr));
  }
};

static int InteractWithService() {
  TodoService::setup();
  ErrorCode ec = EC_OK;
  TodoListView view;
  view.showMenu();
  bool should_terminate = false;
  do {
    char in[2] = {0};
    if (view.readln(in, 2) < 0) {
      ec = EC_OK;
      should_terminate = true;
    } else {
      printf("\n");
      switch (in[0]) {
        case 'q':
          should_terminate = true;
          break;
        case 'm':
          view.showMenu();
          break;
        case 'l':
          view.listTodoItems();
          break;
        case 'a':
          view.addTodoItem();
          view.listTodoItems();
          break;
        case 't':
          view.toggleTodoItem();
          view.listTodoItems();
          break;
        case 'c':
          view.clear_done_items();
          view.listTodoItems();
          break;
        case 'd':
          view.deleteItem();
          view.listTodoItems();
          break;
        default:
          break;
      }
    }
  } while (!should_terminate);
  TodoService::tearDown();
  return ec;
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot file>\n", argv[0]);
    return EC_OK;
  }

  ServiceApiSetup();
  StartVmThread(argv[1]);
  int ec = InteractWithService();
  WaitForVmThread(kDone);
  return ec;
}
