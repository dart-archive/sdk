// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitCellPresenter.h"

@interface CommitCellPresenter ()

@property (strong, nonatomic) IBOutlet NSLayoutConstraint*
    detailsViewHeightConstraint;

@property LruCache* imageCache;

@end

@implementation CommitCellPresenter

- (id)init {
  self.imageCache = [[LruCache alloc] initWithMaxSize:100];
  return self;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
                    indexPath:(NSIndexPath*)indexPath
                      present:(Node*)node {

  CommitCellPresenter* cell;
  CommitNode* commitNode = (CommitNode*)node;

  if (commitNode.selected) {
    cell = (CommitCellPresenter*)
        [tableView dequeueReusableCellWithIdentifier:@"CommitDetailsCell"
                                        forIndexPath:indexPath];
  } else {
    cell = (CommitCellPresenter*)
        [tableView dequeueReusableCellWithIdentifier:@"BasicCommitCell"
                                        forIndexPath:indexPath];
  }

  // TODO(zarah): Handle when a cell is viewed but its data is not yet loaded.
  if (node == nil) return cell;

  [self configureCell:cell atIndexPath:indexPath withNode:commitNode];
  return cell;
}

- (void)configureCell:(CommitCellPresenter*)cell
          atIndexPath:(NSIndexPath *)indexPath
             withNode:(CommitNode*)node{
  NSString* decodedMessage = [self decodeJsonString:node.message];
  if (decodedMessage.length > 200) {
    decodedMessage = [NSString stringWithFormat:@"%@...",
                      [decodedMessage substringToIndex:200]];
  }
  cell.detailsLabel.text = decodedMessage;
  cell.messageLabel.text = decodedMessage;
  cell.authorLabel.text = node.author;
  cell.avatarImage.image = [UIImage imageNamed:@"dart-logo.png"];
  cell.index = indexPath;

  NSString* url = node.imageUrl;
  if (![url isEqual:@""]) {
    [self loadImageFromUrl:url forCell:cell atIndexPath:indexPath];
  }
}

- (void)loadImageFromUrl:(NSString*)url
                 forCell:(CommitCellPresenter*)cell
             atIndexPath:(NSIndexPath*)indexPath {

  NSAssert(NSThread.isMainThread,
           @"Not on main thread",
           NSThread.callStackSymbols);

  id cachedImage = [self.imageCache get:url];
  if (cachedImage != nil) {
    if ([cachedImage isKindOfClass:NSMutableDictionary.class]) {
      [cachedImage setObject:cell forKey:indexPath];
    } else {
      cell.avatarImage.image = [UIImage imageWithData:cachedImage];
    }
  } else {
    NSMutableDictionary* waitingCells = [[NSMutableDictionary alloc] init];
    [waitingCells setObject:cell forKey:indexPath];
    [self.imageCache put:url value:waitingCells];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      NSData* imageData =
      [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:url]];


      if (imageData == nil) return;

      dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary* cells = [self.imageCache get:url];
        [self.imageCache put:url value:imageData];

        [cells enumerateKeysAndObjectsUsingBlock:^(NSIndexPath* index,
                                                   CommitCellPresenter* cell,
                                                   BOOL* stop) {
          if ([cell.index isEqual:index]) {
            cell.avatarImage.image = [UIImage imageWithData:imageData];
          }
        }];
      });
    });
  }
}

- (NSString*) decodeJsonString:(NSString*)text {
  NSString* jsonString = [NSString stringWithFormat: @"\"%@\"", text];
  NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

  return [NSJSONSerialization JSONObjectWithData:data
                                         options:NSJSONReadingAllowFragments
                                           error:NULL];
}

@end