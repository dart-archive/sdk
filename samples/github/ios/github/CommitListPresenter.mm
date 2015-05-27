// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitListPresenter.h"
#import "CommitCellPresenter.h"
#import "SlidingWindowPresenter.h"

@interface CommitListPresenter ()

@property SlidingWindowPresenter* presenter;
@property id <CellPresenter> cellPresenter;

@end

@implementation CommitListPresenter

- (void)immi_setupRoot:(ImmiRoot*)root {
  self.cellPresenter = [[CommitCellPresenter alloc] init];
  self.presenter = [[SlidingWindowPresenter alloc]
                    initWithCellPresenter:self.cellPresenter
                    tableView:self.tableView];

  [self.presenter immi_setupRoot:root];
  
  self.tableView.dataSource = self.presenter;
  
  CADisplayLink* consoleLink =
  [CADisplayLink displayLinkWithTarget:self.presenter
                              selector:@selector(refresh)];
  [consoleLink setFrameInterval:60];
  [consoleLink addToRunLoop:[NSRunLoop currentRunLoop]
                    forMode:NSDefaultRunLoopMode];
}

@end
