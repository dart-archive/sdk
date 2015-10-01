// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "SlidingWindowPresenter.h"

@interface SlidingWindowPresenter ()

@property id<CellPresenter> cellPresenter;
@property UITableView* tableView;

// Is the TableView of this sliding window currently scrolling.
@property bool scrolling;

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
  self.scrolling = false;
  self.cellPresenter = presenter;
  self.tableView = tableView;
  [self setBufferParametersBasedOnViewSize];
  return self;
}

- (void)setBufferParametersBasedOnViewSize {
  CGFloat rowHeight = self.cellPresenter.minimumCellHeight;
  CGFloat tableHeight = self.tableView.bounds.size.height;
  int cellCount = (int) (tableHeight / rowHeight);

  self.bufferSlack = 1;
  self.bufferAdvance = cellCount;
  self.bufferCount = 3 * self.bufferAdvance + cellCount;
}

- (void)presentSlidingWindow:(SlidingWindowNode*)node {
  [self checkDisplayWindow:node];
  dispatch_async(dispatch_get_main_queue(), ^{
      [self presentOnMainThread:node];
  });
}

- (void)patchSlidingWindow:(SlidingWindowPatch*)patch {
  assert(patch.updated);
  [self checkDisplayWindow:patch.current];
  dispatch_async(dispatch_get_main_queue(), ^{
      [self patchOnMainThread:patch];
  });
}

- (void)checkDisplayWindow:(SlidingWindowNode*)node {
  if (node.window.count == 0) {
    node.display(0, self.bufferCount);
  }
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

// Adjust the scroll position if the visible rows are outside the window buffer.
// Returns true if it is or if scroll position was adjusted.
- (bool)adjustScrollPosition {
  // TODO(zerny): Identify "scroll to top" as scrolling and enable this again.
  return false;
  // TODO(zerny): Properly track the scroll position.
  // If the current view is outside the visible view adjust the visible view.
  if (!self.scrolling && self.tableView.indexPathsForVisibleRows.count > 0) {
    int start = self.windowStart;
    int end = self.windowEnd;
    int row = [[self.tableView.indexPathsForVisibleRows objectAtIndex:0] row];
    if (row < start || end <= row) {
      // Adjust the start by buffer slack so we don't trigger a window shift.
      if (start != 0) start += self.bufferSlack + 1;
      NSIndexPath* path = [NSIndexPath indexPathForRow:start inSection:0];
      [self.tableView reloadData];
      if (start < end) {
        [self.tableView scrollToRowAtIndexPath:path
                              atScrollPosition:UITableViewScrollPositionTop
                                      animated:NO];
      }
      return true;
    }
  }
  return false;
}

- (void)presentOnMainThread:(SlidingWindowNode*)node {
  self.root = node;
  if ([self adjustScrollPosition]) return;
  [self.tableView reloadData];
}

- (void)patchOnMainThread:(SlidingWindowPatch*)patch {
  self.root = patch.current;
  if ([self adjustScrollPosition]) return;

  int previousCount = patch.previous.minimumCount;
  int currentCount = patch.current.minimumCount;
  assert(previousCount == [self.tableView numberOfRowsInSection:0]);

  // The stable range is positions in the view both before and after the patch.
  int stableCount = MIN(previousCount, currentCount);

  // Independently track if insert or removes have been made.
  bool containsInserts = false;
  bool containsRemoves = false;

  // Find an update ranges:
  NSMutableArray* updatePaths = [[NSMutableArray alloc] init];
  for (int i = 0; i < patch.window.regions.count; ++i) {
    ListRegionPatch* region = patch.window.regions[i];
    if (!region.isUpdate) {
      containsInserts = containsInserts || region.isInsert;
      containsRemoves = containsRemoves || region.isRemove;
      continue;
    }
    ListRegionUpdatePatch* update = (id)region;
    for (int j = 0; j < update.updates.count; ++j) {
      int position = [self windowIndexToTableIndex:update.index + j];
      if (position >= stableCount) continue;
      [updatePaths addObject:[NSIndexPath indexPathForRow:position inSection:0]];
    }
  }

  // This patch routine assumes that the diff algorithm will not produce
  // both an insertion and a deletion region in the same patch.
  assert(!containsInserts || !containsRemoves);

  // Find either the insert or the remove positions:
  NSMutableArray* insertPaths;
  NSMutableArray* removePaths;
  if (stableCount < currentCount) {
    insertPaths = [[NSMutableArray alloc] init];
    for (int i = stableCount; i < currentCount; ++i) {
      [insertPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
  } else if (stableCount < previousCount) {
    removePaths = [[NSMutableArray alloc] init];
    for (int i = stableCount; i < previousCount; ++i) {
      [removePaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
  }

  // Batch notify the table view of the changes.
  [self.tableView beginUpdates];
  [self.tableView reloadRowsAtIndexPaths:updatePaths
                        withRowAnimation:UITableViewRowAnimationNone];
  if (insertPaths != nil) {
    [self.tableView insertRowsAtIndexPaths:insertPaths
                          withRowAnimation:UITableViewRowAnimationNone];
  }
  if (removePaths != nil) {
    [self.tableView deleteRowsAtIndexPaths:removePaths
                          withRowAnimation:UITableViewRowAnimationNone];
  }
  [self.tableView endUpdates];

  assert(currentCount == [self.tableView numberOfRowsInSection:0]);
}

- (int)windowIndexToTableIndex:(int)index {
  int indexDelta = index - self.root.windowOffset;
  if (indexDelta < 0) indexDelta += self.root.window.count;
  return [self windowStart] + indexDelta;
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
}

- (CGFloat)tableView:(UITableView*)tableView
    heightForRowAtIndexPath:(NSIndexPath*)indexPath {
  return [self.cellPresenter tableView:tableView
               heightForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView*)tableView
    estimatedHeightForRowAtIndexPath:(NSIndexPath*)indexPath {
  return [self.cellPresenter tableView:tableView
      estimatedHeightForRowAtIndexPath:indexPath];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  self.scrolling = true;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
  self.scrolling = false;
}

@end
