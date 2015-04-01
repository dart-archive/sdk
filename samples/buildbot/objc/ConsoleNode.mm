// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ConsoleNode.h"

#import "CommitNode.h"
#import "PresenterUtils.h"

#include "buildbot_service.h"

@implementation ConsoleNode

- (id)init {
  @throw [NSException
          exceptionWithName:NSInternalInconsistencyException
          reason:@"-init is private"
          userInfo:nil];
  return nil;
}

- (id)initWith:(const ConsoleNodeData&)data {
  _title = [PresenterUtils decodeString:data.getTitleData()];
  _status = [PresenterUtils decodeString:data.getStatusData()];
  _commits = [CommitNode arrayWithData:data.getCommits()];
  return self;
}

- (void)patchWith:(const ConsolePatchData &)patch {
  if (patch.isReplace()) {
    (void)[self initWith:patch.getReplace()];
    return;
  }
  assert(patch.isUpdates());
  List<ConsoleUpdatePatchData> updates = patch.getUpdates();
  for (int i = 0; i < updates.length(); ++i) {
    ConsoleUpdatePatchData update = updates[i];
    if (update.isTitle()) {
      _title = [PresenterUtils decodeString:update.getTitleData()];
    } else if (update.isStatus()) {
      _status = [PresenterUtils decodeString:update.getStatusData()];
    } else if (update.isCommits()) {
      [CommitNode applyListPatch:update.getCommits() atList:_commits];
    } else {
      abort();
    }
  }
}

+ (void)applyPatch:(const ConsolePatchData&)patch
            atNode:(ConsoleNode* __strong *)node {
  if (*node) {
    [*node patchWith:patch];
  } else {
    assert(patch.isReplace());
    *node = [[ConsoleNode alloc] initWith: patch.getReplace()];
  }
}

@end
