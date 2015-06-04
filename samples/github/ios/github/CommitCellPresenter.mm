// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitCellPresenter.h"

@interface CommitCellPresenter ()

@property (strong, nonatomic) IBOutlet NSLayoutConstraint*
    detailsViewHeightConstraint;

@end

@implementation CommitCellPresenter

- (UITableViewCell*)tableView:(UITableView*)tableView
                    indexPath:(NSIndexPath*)indexPath
                withSelection:(BOOL)withSelection
                      present:(Node*)node {
  CommitNode* commitNode = (CommitNode*)node;
  CommitCellPresenter* cell = (CommitCellPresenter*)
      [tableView dequeueReusableCellWithIdentifier:@"CommitPrototypeCell"
                                      forIndexPath:indexPath];
  cell.authorLabel.text = commitNode.author;
  cell.messageLabel.text = commitNode.message;
  cell.detailsLabel.text = commitNode.message;
  cell.withSelection = withSelection;
  return cell;
}

- (void)setWithSelection:(BOOL)withSelection {
  _withSelection = withSelection;

  if (withSelection) {
    self.detailsViewHeightConstraint.priority = 250.0;
  } else {
    self.detailsViewHeightConstraint.priority = 999.0;
  }
}

@end
