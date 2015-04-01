// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ConsolePresenter.h"
#import "ConsoleNode.h"

#include "buildbot_service.h"

static const bool PROFILE_REFRESH = false;
static const int SLACK_COUNT = 5;

@interface ConsolePresenter ()

@property int minIndex;
@property int maxIndex;
@property int visibleCount;

@property int refreshCount;
@property double refreshTime;
@property double patchTime;

@end

@implementation ConsolePresenter

- (id)init {
  self.minIndex = INT_MAX;
  self.maxIndex = INT_MIN;
  self.visibleCount = 0;
  self.refreshCount = 0;
  self.refreshTime = 0.0;
  self.patchTime = 0.0;
  return self;
}

- (void)refresh {
  ++self.refreshCount;
  [self updateVisibleRange];

  NSDate* refreshStart = [NSDate date];
  BuildBotPatchData patch = BuildBotService::refresh();
  self.refreshTime -= [refreshStart timeIntervalSinceNow];

  NSDate* patchStart = [NSDate date];
  if (patch.isConsolePatch()) {
    [ConsoleNode applyPatch:patch.getConsolePatch() atNode:&_root];
  } else {
    assert(patch.isNoPatch());
  }
  patch.Delete();
  self.patchTime -= [patchStart timeIntervalSinceNow];

  if (PROFILE_REFRESH) {
    double totalTime = -1000 * [refreshStart timeIntervalSinceNow];
    if (self.commitCount > 0 && totalTime > 17.0) {
      NSLog(@"Missed 17 ms refresh (spent %d ms)", static_cast<int>(totalTime));
    }
  }
}

- (void)updateVisibleRange {
  if (self.minIndex >= self.maxIndex) return;
  int index = self.minIndex;
  int count = self.maxIndex - self.minIndex;
  BuildBotService::setConsoleMinimumIndex(index);
  if (count + SLACK_COUNT < self.visibleCount ||
      count - SLACK_COUNT > self.visibleCount) {
    self.visibleCount = count;
    BuildBotService::setConsoleCount(count);
  }
  self.minIndex = INT_MAX;
  self.maxIndex = INT_MIN;
}

- (void)printStats {
  if (!PROFILE_REFRESH) return;
  double refresh = self.refreshTime/self.refreshCount;
  double patch = self.patchTime/self.refreshCount;
  NSLog(@"avg(%f), refresh(%f), patch(%f)", refresh+patch, refresh, patch);
}

- (int)commitCount {
  if (self.root == nil) return 0;
  if (self.root.commits.count == 0) return 0;
  // TODO(zerny): What is the idomatic way of infinit scrolling for iOS apps?
  // This hack does result in allocating internal structures for the view.
  return 10000;
}

- (CommitNode*)commitAtIndex:(int)index {
  if (self.root == nil) abort();

  if (index < self.minIndex) self.minIndex = index;
  if (index > self.maxIndex) self.maxIndex = index;

  int offset = self.root.commitsOffset;
  int count = self.root.commits.count;
  int adjustedOffset = index - offset;

  bool needsRefresh = false;

  if (index < offset) {
    needsRefresh = true;
    BuildBotService::setConsoleMinimumIndex(index);
  } else if (count <= adjustedOffset) {
    needsRefresh = true;
    BuildBotService::setConsoleMaximumIndex(index);
  }

  if (needsRefresh) {
    [self refresh];
    count = self.root.commits.count;
    offset = self.root.commitsOffset;
    adjustedOffset = index - offset;
  }

  if (adjustedOffset < 0 || adjustedOffset >= count)
    abort();

  return self.root.commits[adjustedOffset];
}

@end
