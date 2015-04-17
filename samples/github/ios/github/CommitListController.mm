// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitListController.h"

#import "CommitCell.h"
#import "CommitListPresenter.h"

@interface CommitListController ()

@property CommitListPresenter* presenter;

@end

@implementation CommitListController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.presenter = [[CommitListPresenter alloc] init];

  // Setup regular refresh.
  CADisplayLink* consoleLink =
      [CADisplayLink displayLinkWithTarget:self
                                  selector:@selector(refresh:)];
  [consoleLink setFrameInterval:60];
  [consoleLink addToRunLoop:[NSRunLoop currentRunLoop]
                    forMode:NSDefaultRunLoopMode];

}

- (void)refresh:(CADisplayLink*)sender {
  if ([self.presenter refresh]) {
    [self.tableView reloadData];
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
  assert(section == 0);
  return self.presenter.commitCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  CommitCell* cell =
    (CommitCell*)[tableView
        dequeueReusableCellWithIdentifier:CommitCellId
                             forIndexPath:indexPath];
  CommitNode* commit = [self.presenter commitAtIndex:indexPath.row];
  cell.revisionLabel.text = [NSString stringWithFormat:@"%d", commit.revision];
  cell.authorLabel.text = commit.author;
  cell.messageLabel.text = commit.message;
  return cell;
}

@end
