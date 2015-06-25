// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "SlidingWindowPresenter.h"

@interface SlidingWindowPresenter ()

@property id<CellPresenter> cellPresenter;
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

@property SlidingWindowNode* root;

@end

@implementation SlidingWindowPresenter

- (id)initWithCellPresenter:(id<CellPresenter>)presenter
                  tableView:(UITableView*)tableView {
  self.cellPresenter = presenter;
  self.tableView = tableView;
  self.bufferSlack = 1;
  self.bufferAdvance = 4;
  // TODO(zerny): The buffer size should be dynamically computed. Here we make
  // it large enough for the display of an iPad Air.
  self.bufferCount = 50;

  return self;
}

- (void)presentSlidingWindow:(SlidingWindowNode*)node {
  self.root = node;
  [self refreshDisplayStart:0 end:self.bufferCount];
}

- (void)patchSlidingWindow:(SlidingWindowPatch*)patch {
  self.root = [patch applyWith:self.root];
  [self reloadOnMainThread];
}

- (NSInteger)tableView:(UITableView*)tableView
    numberOfRowsInSection:(NSInteger)section {
  return self.root == nil ? 0 : self.root.minimumCount;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
        cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  Node* node = [self itemAtIndex:indexPath.row];
  return [self.cellPresenter tableView:tableView
                             indexPath:indexPath
                               present:node];
}

// To track what items are visible on screen we rely on the fact that only
// visible items are accessed by cellForRowAtIndexPath. When accessing an index
// that is in the proximity of either the start or the end of the sliding
// window, we shift the window.
- (id)itemAtIndex:(int)index {
  assert(self.root != nil);
  if (index < self.windowStart + self.bufferSlack) {
    [self shiftDown:index];
  } else if (index + self.bufferSlack >= self.windowEnd) {
    [self shiftUp:index];
  }
  int adjusted = [self windowIndex:index];
  // Return nil if the adjusted index is outside the sliding window.
  return (adjusted < 0) ? nil : [self.root.window objectAtIndex:adjusted];
}

- (void)shiftDown:(int)index {
  int start = (index > self.bufferAdvance) ? index - self.bufferAdvance : 0;
  if (start == self.windowStart) return;
  [self refreshDisplayStart:start end:start + self.bufferCount];
}

- (void)shiftUp:(int)index {
  int end = index + self.bufferAdvance + 1;
  if (end > self.maximumCount) end = self.maximumCount;
  if (end == self.windowEnd) return;
  if (end > self.bufferCount) {
    [self refreshDisplayStart:end - self.bufferCount end:end];
  } else {
    [self refreshDisplayStart:0 end:self.bufferCount];
  }
}

- (void)refreshDisplayStart:(int)start end:(int)end {
  self.root.display(start, end);
}

- (void)reloadOnMainThread {
  // TODO(zerny): Selectively reload the table based on patch data.
  // TODO(zerny): Should this be run in the NSEventTrackingRunLoopMode?
  [self.tableView performSelectorOnMainThread:@selector(reloadData)
                                   withObject:nil
                                waitUntilDone:NO];
}

- (int)windowIndex:(int)index {
  assert(self.root != nil);
  if (index < self.windowStart || self.windowEnd <= index) return -1;
  int i = self.root.windowOffset + index - self.windowStart;
  return i % self.windowCount;
}

// The maximum number of items that can be in the list.
- (int)maximumCount {
  return self.root.maximumCount < 0 ? INT_MAX : self.root.maximumCount;
}

- (int)windowCount {
  return self.root.window.count;
}

- (int)windowEnd {
  return self.root.startOffset + self.windowCount;
}

- (int)windowStart {
  return self.root.startOffset;
}

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  self.root.toggle(indexPath.row);
  [tableView reloadRowsAtIndexPaths:@[indexPath]
                   withRowAnimation:UITableViewRowAnimationNone];
}

@end
