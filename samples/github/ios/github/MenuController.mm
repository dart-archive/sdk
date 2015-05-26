// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "MenuController.h"

@interface MenuController ()

@property ImmiRoot* immi_root;

@end

@implementation MenuController

- (void)immi_setupRoot:(ImmiRoot*)root {
  self.immi_root = root;
  [root refresh];
}

- (MenuNode*)root {
  return (MenuNode*)self.immi_root.rootNode;
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
  [item dispatchSelect];
}

@end
