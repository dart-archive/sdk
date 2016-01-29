// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "MenuPresenter.h"

@interface MenuPresenter ()

@property (weak) MenuNode* root;
@property UINavigationController* navigationController;

@end

@implementation MenuPresenter

- (id)initWithCoder:(NSCoder*)aDecoder {
  self = [super initWithCoder:aDecoder];
  self.navigationController =
      [[UINavigationController alloc] initWithRootViewController:self];
  return self;
}

- (void)presentMenu:(MenuNode*)node {
  self.root = node;
  [self performSelectorOnMainThread:@selector(presentOnMainThread:)
                         withObject:node
                      waitUntilDone:NO];
}

- (void)presentOnMainThread:(MenuNode*)node {
  self.navigationController.title = node.title;
  [self.tableView reloadData];
}

- (void)patchMenu:(MenuPatch*)patch {
  [self performSelectorOnMainThread:@selector(patchOnMainThread:)
                         withObject:patch
                      waitUntilDone:NO];
}

- (void)patchOnMainThread:(MenuPatch*)patch {
  if (patch.title.changed) {
    self.navigationController.title = patch.title.current;
  }
  if (patch.items.changed) {
    // TODO(zerny): selectively reload only changed cells.
    [self.tableView reloadData];
  }
}

- (UIViewController *)viewController {
  return self.navigationController;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView*)tableView
    numberOfRowsInSection:(NSInteger)section {
  assert(section == 0);
  return self.root.items.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
        cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  UITableViewCell* cell =
      [tableView dequeueReusableCellWithIdentifier:@"MenuItemPrototypeCell"
                                      forIndexPath:indexPath];
  MenuItemNode* item = self.root.items[indexPath.row];
  cell.textLabel.text = item.title;
  return cell;
}

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  MenuItemNode* item = self.root.items[indexPath.row];
  item.select();
}

@end
