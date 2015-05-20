// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitListPresenter.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "immi_service.h"

@interface CommitListPresenter ()

@property ImmiRoot* immi_root;

@property UITableView* tableView;

// Internal properties for updating the sliding-window display range.
// These are not "presentation state" but are rather mostly-constant values
// representing the physical dimensions of the screen.

// Number of items in the sliding-window display.
// Must be > 2 * bufferAdvance + |visible items on screen|.
@property int bufferCount;

// Access to an item within 'slack' distance of the start or end of
// the sliding-window triggers a sliding-window shift.
// Must be > 1 (a zero value will result in no shifting).
@property int bufferSlack;

// Number of items to shift the buffer by when shifting.
// Must be >= bufferSlack.
@property int bufferAdvance;

@end

@implementation CommitListPresenter

- (id)init:(UITableView*)tableView {
  self.tableView = tableView;
  self.bufferSlack = 1;
  self.bufferAdvance = 4;
  // TODO(zerny): The buffer size should be dynamically computed. Here we make
  // it large enough for the display of an iPad Air.
  self.bufferCount = 30;
  return self;
}

- (void)immi_initWithRoot:(ImmiRoot*)root {
  self.immi_root = root;
}

- (CommitListNode*)root { return self.immi_root.rootNode; }

// To track what items are visible on screen we rely on the fact that only
// visible items are accessed by cellForRowAtIndexPath on the
// CommitListController. When accessing an index that is in the proximity of
// either the start or the end of the sliding window, we shift the window.
- (CommitNode*)commitAtIndex:(int)index {
  assert(self.root != nil);
  if (index < self.currentStart + self.bufferSlack) {
    [self shiftDown:index];
  } else if (index + self.bufferSlack >= self.currentEnd) {
    [self shiftUp:index];
  }
  return [self.root.commits objectAtIndex:[self bufferIndex:index]];
}

- (bool)refresh {
  if (self.immi_root == nil) return false;
  bool first = self.root == nil;
  bool result = [self.immi_root refresh];
  assert(self.root.isCommitList);
  // TODO(zerny): Find another way to setup the initial display.
  if (first) {
    assert(result);
    [self.root dispatchDisplayStart:0 end:self.bufferCount];
    return [self refresh];
  }
  if (result) {
    [self.tableView performSelectorOnMainThread:@selector(reloadData)
                                     withObject:nil
                                  waitUntilDone:NO];
  }
  return result;
}

// The minumum number of items we know to exist in the list.
- (int)commitCount {
  return self.root == nil ? 0 : self.root.minimumCount;
}

// The maximum number of items that can be in the list.
- (int)commitCountAbsolute {
  return self.root.count < 0 ? INT_MAX : self.root.count;
}

- (int)bufferIndex:(int)index {
  assert(self.root != nil);
  assert(index >= self.currentStart);
  assert(index < self.currentEnd);
  int i = self.root.bufferOffset + index - self.currentStart;
  return i % self.currentCount;
}

- (int)currentEnd {
  return self.root.startOffset + self.root.commits.count;
}

- (int)currentStart {
  return self.root.startOffset;
}

- (int)currentCount {
  return self.root.commits.count;
}

// TODO(zerny): Support an async adjustment so we don't block the main thread.
- (void)refreshDisplayStart:(int)start end:(int)end {
  [self.root dispatchDisplayStart:start end:end];
  [self refresh];
}

- (void)shiftDown:(int)index {
  int start = (index > self.bufferAdvance) ? index - self.bufferAdvance : 0;
  if (start == self.currentStart) return;
  [self refreshDisplayStart:start end:start + self.bufferCount];
}

- (void)shiftUp:(int)index {
  int end = index + self.bufferAdvance + 1;
  if (end > self.commitCountAbsolute) end = self.commitCountAbsolute;
  if (end == self.currentEnd) return;
  if (end > self.bufferCount) {
    [self refreshDisplayStart:end - self.bufferCount end:end];
  } else {
    [self refreshDisplayStart:0 end:self.bufferCount];
  }
}

@end
