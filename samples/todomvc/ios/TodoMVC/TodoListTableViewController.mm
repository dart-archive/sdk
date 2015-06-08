// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "TodoListTableViewController.h"
#import "AddTodoItemViewController.h"
#import "TodoItem.h"

#include "todomvc_service.h"
#include "todomvc_presenter.h"

// Host-side implementation of the todo-list presenter.
// This class is responsible for mapping Dart-side changes to the presenter
// model of the host implementation, in this case, a table-view presenting a
// list of TodoItem objects.
class TodoMVCPresenterImpl : public TodoMVCPresenter {
public:
  TodoMVCPresenterImpl(TodoListTableViewController* controller)
    : controller_(controller) {
    items_ = [[NSMutableArray alloc] init];
  }

  NSArray* items() { return items_; }

  void createItem(NSString* title) {
    int length = title.length;
    int size = 56 + BoxedStringBuilder::kSize + length;
    MessageBuilder builder(size);
    BoxedStringBuilder box = builder.initRoot<BoxedStringBuilder>();
    List<unichar> chars = box.initStrData(length);
    encodeString(title, chars);
    TodoMVCService::createItemAsync(box, VoidCallback, NULL);
  }

  void toggleItem(int id) {
    TodoItem* item = [items_ objectAtIndex:id];
    if (item.completed) {
      [item dispatchUncompleteEvent];
    } else {
      [item dispatchCompleteEvent];
    }
  }

protected:
  // Patch apply callbacks.
  virtual void enterPatch() {
    context_ = IN_LIST;
    index_ = 0;
  }

  virtual void enterConsFst() {
    context_ = (context_ == IN_LIST) ? IN_ITEM : IN_TITLE;
  }

  virtual void enterConsSnd() {
    if (context_ == IN_LIST) {
      ++index_;
    } else {
      context_ = IN_STATUS;
    }
  }

  virtual void enterConsDeleteEvent() {
    assert(context_ == IN_ITEM);
    context_ = IN_DELETE_EVENT;
  }

  virtual void enterConsCompleteEvent() {
    assert(context_ == IN_ITEM);
    context_ = IN_COMPLETE_EVENT;
  }

  virtual void enterConsUncompleteEvent() {
    assert(context_ == IN_ITEM);
    context_ = IN_UNCOMPLETE_EVENT;
  }

  virtual void updateNode(const Node& node) {
    TodoItem *item;
    switch (context_) {
      case IN_TITLE:
        item = [items_ objectAtIndex:index_];
        item.itemName = decodeString(node.getStrData());
        break;
      case IN_STATUS:
        item = [items_ objectAtIndex:index_];
        item.completed = node.getTruth();
        break;
      case IN_DELETE_EVENT:
        item = [items_ objectAtIndex:index_];
        item.deleteEvent = node.getNum();
        break;
      case IN_COMPLETE_EVENT:
        item = [items_ objectAtIndex:index_];
        item.completeEvent = node.getNum();
        break;
      case IN_UNCOMPLETE_EVENT:
        item = [items_ objectAtIndex:index_];
        item.uncompleteEvent = node.getNum();
        break;
      case IN_ITEM:
        item = newItem(node);
        [items_ insertObject:item atIndex:index_];
        break;
      case IN_LIST:
        resizeTo(index_);
        addItems(node);
        break;
      default:
        abort();
    }
    // TODO: Selectively reload only the affected rows.
    [controller_.tableView reloadData];
  }

private:
  void resizeTo(unsigned long newLength) {
    unsigned long length = [items_ count];
    if (newLength < length) {
      [items_ removeObjectsInRange:NSMakeRange(newLength, length - newLength)];
    }
  }

  void encodeString(NSString* string, List<unichar> chars) {
    assert(string.length == chars.length());
    [string getCharacters:chars.data()
                    range:NSMakeRange(0, string.length)];
  }
 
  NSString* decodeString(List<unichar> chars) {
    return [[NSString alloc] initWithCharacters:chars.data()
                                         length:chars.length()];
  }

  TodoItem* newItem(const Node& node) {
    TodoItem *item = [[TodoItem alloc] init];
    Cons cons = node.getCons();
    item.itemName = decodeString(cons.getFst().getStrData());
    item.completed = cons.getSnd().getTruth();
    item.deleteEvent = cons.getDeleteEvent();
    item.completeEvent = cons.getCompleteEvent();
    item.uncompleteEvent = cons.getUncompleteEvent();
    return item;
  }

  void addItem(const Node& node) {
    TodoItem *item = newItem(node);
    [items_ addObject:item];
  }

  void addItems(const Node& node) {
    if (node.isNil()) return;
    Cons cons = node.getCons();
    addItem(cons.getFst());
    addItems(cons.getSnd());
  }

  enum Context {
    IN_LIST,
    IN_ITEM,
    IN_TITLE,
    IN_STATUS,
    IN_DELETE_EVENT,
    IN_COMPLETE_EVENT,
    IN_UNCOMPLETE_EVENT
  };
  Context context_;
  int index_;
  NSMutableArray* items_;
  TodoListTableViewController* controller_;
};

@interface TodoListTableViewController ()

@property TodoMVCPresenterImpl *impl;
@property int ticks;
@property NSDate* start;

@end

@implementation TodoListTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Instantiate host-side implementation of the presenter.
  self.impl = new TodoMVCPresenterImpl(self);

  // Do the initial synchronization before linking to the refresh rate.
  NSDate* date = [NSDate date];
  self.impl->sync();
  double time = -[date timeIntervalSinceNow];
  NSLog(@"Initial sync: %f s", time);

  self.ticks = 0;
  self.start = [NSDate date];
  // Link display refresh to synchronization of the presenter.
  CADisplayLink* link = [CADisplayLink
                         displayLinkWithTarget:self
                                      selector:@selector(refreshDisplay:)];
  [link setFrameInterval:1];
  [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)refreshDisplay:(CADisplayLink *)sender {
  if (++self.ticks % 60 == 0) {
    double time = -[self.start timeIntervalSinceNow];
    if (time > 1.1) {
      NSLog(@"60fps miss: %f s", time);
    }
    self.start = [NSDate date];
  }
  self.impl->sync();
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)unwindToList:(UIStoryboardSegue *)segue {
  AddTodoItemViewController *source = [segue sourceViewController];
  TodoItem *item = source.todoItem;
  if (item == nil) return;
  self.impl->createItem(item.itemName);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return [self.impl->items() count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"ListPrototypeCell"
                                      forIndexPath:indexPath];
  TodoItem *todoItem = [self.impl->items() objectAtIndex:indexPath.row];
  cell.textLabel.text = todoItem.itemName;
  cell.accessoryType = todoItem.completed
    ? UITableViewCellAccessoryCheckmark
    : UITableViewCellAccessoryNone;
  return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  self.impl->toggleItem(indexPath.row);
}

@end
