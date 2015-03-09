// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitsTableViewController.h"

#import "CommitCell.h"
#import "CommitNode.h"
#import "ConsoleNode.h"
#import "ConsolePresenter.h"
#import "StatusHeaderCell.h"

#include "buildbot_service.h"

@interface CommitsTableViewController ()

@property ConsolePresenter* presenter;
@property int frames;
@property CFTimeInterval frameTimestamp;

@end

@implementation CommitsTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Attach the console presenter with a 1-second refresh rate.
  self.presenter = [[ConsolePresenter alloc] init];
  self.frames = 0;
  self.frameTimestamp = 0;
  CADisplayLink* consoleLink =
    [CADisplayLink
     displayLinkWithTarget:self
                  selector:@selector(refreshConsole:)];
  [consoleLink setFrameInterval:1];
  [consoleLink addToRunLoop:[NSRunLoop currentRunLoop]
                    forMode:NSDefaultRunLoopMode];
}

- (void)refreshConsole:(CADisplayLink*)sender {
  [self.presenter refresh];
  // Log 60 fps misses.
  if (self.frameTimestamp == 0) self.frameTimestamp = sender.timestamp;
  if (++self.frames == 60 / sender.frameInterval) {
    double intervalTime = sender.timestamp - self.frameTimestamp;
    if (intervalTime > 1.1) {
      NSLog(@"Missed 60 fps with interval time %f", intervalTime);
    }
    self.frames = 0;
    self.frameTimestamp = sender.timestamp;
  }
  // TODO(zerny): move this to an onChange listener.
  self.statusLabel.text = self.presenter.root.status;
  [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  if ([self.presenter root] == nil) return 0;
  return [[[self.presenter root] commits] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  CommitCell* cell = (CommitCell*)[tableView
      dequeueReusableCellWithIdentifier:CommitCellId
                           forIndexPath:indexPath];
  CommitNode* commit =
    [self.presenter.root.commits objectAtIndex:indexPath.row];
  cell.revisionLabel.text = [NSString stringWithFormat:@"%d", commit.revision];
  cell.authorLabel.text = commit.author;
  cell.messageLabel.text = commit.message;
  return cell;
}

-(CGFloat)tableView:(UITableView *)tableView
    heightForHeaderInSection:(NSInteger)section {
  return 50.0;
}

-(UIView*)tableView:(UITableView *)tableView
    viewForHeaderInSection:(NSInteger)section {
  StatusHeaderCell* cell =
    [tableView dequeueReusableCellWithIdentifier:StatusHeaderCellId];
  cell.statusLabel.text = self.presenter.root.status;
  [cell.statusLabel sizeToFit];
  return cell;
}

@end
