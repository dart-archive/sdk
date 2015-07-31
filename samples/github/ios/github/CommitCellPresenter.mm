// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitCellPresenter.h"

static UIImage* dartLogo = [UIImage imageNamed:@"dart-logo.png"];

@interface ImageCache : LruCache <ImageCache>
@end

@implementation ImageCache
@end

@interface CommitCellPresenter ()
@property ImageCache* imageCache;
@end

@implementation CommitCellPresenter

+ (UIImage*) dartLogo {
  return dartLogo;
}

- (id)init {
  self = [super init];
  self.imageCache = [[ImageCache alloc] initWithMaxSize:100];
  return self;
}

- (CGFloat) minimumCellHeight {
  return 100.5;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
                    indexPath:(NSIndexPath*)indexPath
                      present:(Node*)node {

  CommitCellPresenter* cell;
  CommitNode* commitNode = [node as:CommitNode.class];

  if (commitNode == nil) {
    cell = (CommitCellPresenter*)
    [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"
                                    forIndexPath:indexPath];
    [cell.spinner startAnimating];
    return cell;
  } else if (commitNode.selected) {
    cell = (CommitCellPresenter*)
        [tableView dequeueReusableCellWithIdentifier:@"CommitDetailsCell"
                                        forIndexPath:indexPath];
  } else {
    cell = (CommitCellPresenter*)
        [tableView dequeueReusableCellWithIdentifier:@"BasicCommitCell"
                                        forIndexPath:indexPath];
  }

  [self configureCell:cell atIndexPath:indexPath withNode:commitNode];
  return cell;
}

- (void)configureCell:(CommitCellPresenter*)cell
          atIndexPath:(NSIndexPath *)indexPath
             withNode:(CommitNode*)node {
  NSString* decodedMessage = node.message;
  if (decodedMessage.length > 200) {
    decodedMessage = [NSString stringWithFormat:@"%@...",
                      [decodedMessage substringToIndex:200]];
  }
  cell.detailsLabel.numberOfLines = 0;
  cell.detailsLabel.text = decodedMessage;
  cell.messageLabel.text = decodedMessage;
  cell.authorLabel.text = node.author;
  cell.index = indexPath;

  [cell.avatarImage setCache:self.imageCache];
  [cell.avatarImage setDefaultImage:dartLogo];
  [cell.avatarImage presentImage:node.image];
}

@end