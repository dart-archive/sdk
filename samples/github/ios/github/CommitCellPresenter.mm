// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitCellPresenter.h"

@implementation CommitCellPresenter

- (CommitCellPresenter*)tableView:tableView indexPath:indexPath present:node {
  CommitCellPresenter* cell = (CommitCellPresenter*)[tableView
      dequeueReusableCellWithIdentifier:@"CommitPrototypeCell"
                           forIndexPath:indexPath];
  cell.authorLabel.text = ((CommitNode*) node).author;
  cell.messageLabel.text = ((CommitNode*) node).message;
  return cell;
}

@end
