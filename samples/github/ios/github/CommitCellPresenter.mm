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
                      present:(Node*)node {
  CommitNode* commitNode = (CommitNode*)node;
  CommitCellPresenter* cell = (CommitCellPresenter*)
      [tableView dequeueReusableCellWithIdentifier:@"CommitPrototypeCell"
                                      forIndexPath:indexPath];
  cell.authorLabel.text = commitNode.author;
  cell.messageLabel.text = commitNode.message;
  cell.detailsLabel.text = commitNode.message;

  cell.detailsViewHeightConstraint.priority =
      commitNode.selected ? 250.0 : 999.0;

  return cell;
}

@end
