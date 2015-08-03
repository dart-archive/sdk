// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitListPresenter.h"

#import "CommitCellPresenter.h"
#import "ImmiSamples/SlidingWindowPresenter.h"

@interface CommitListPresenter ()

@property UINavigationController* navigationController;
@property SlidingWindowPresenter* presenter;
@property id<CellPresenter> cellPresenter;

@end

@implementation CommitListPresenter

- (instancetype)initWithCoder:(NSCoder*)aDecoder {
  self = [super initWithCoder:aDecoder];
  self.navigationController =
      [[UINavigationController alloc] initWithRootViewController:self];
  return self;
}

- (UIViewController*)viewController {
  return self.navigationController;
}

- (void)presentSlidingWindow:(SlidingWindowNode*)node {
  // TODO(zerny): this setup should be done on allocation but can't because
  // SlidingWindowPresenter depends on the table view. Remove the dependency in
  // SlidingWindowPresenter and move allocation of the sub presenters to init.
  if (self.presenter == nil) {
    self.cellPresenter = [[CommitCellPresenter alloc] init];
    self.presenter =
        [[SlidingWindowPresenter alloc]
         initWithCellPresenter:self.cellPresenter
                     tableView:self.tableView];
    self.tableView.dataSource = self.presenter;
    self.tableView.delegate = self.presenter;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100.5;
  }
  [self.presenter presentSlidingWindow:node];
}

- (void)patchSlidingWindow:(SlidingWindowPatch*)patch {
  [self.presenter patchSlidingWindow:patch];
}

@end
