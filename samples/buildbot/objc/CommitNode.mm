// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitNode.h"

#import "PresenterUtils.h"

#include "buildbot_service.h"

// Constructor wrapper to help convert templated C++ List to NSArray.
static id createCommitNode(const CommitNodeData& data) {
  return [[CommitNode alloc] initWith:data];
}

@implementation CommitNode

- (id)init {
  @throw [NSException
          exceptionWithName:NSInternalInconsistencyException
          reason:@"-init is private"
          userInfo:nil];
  return nil;
}

- (id)initWith:(const CommitNodeData&)data {
  _revision = data.getRevision();
  _author = [PresenterUtils decodeString:data.getAuthorData()];
  _message = [PresenterUtils decodeString:data.getMessageData()];
  return self;
}

- (void)patchWith:(const CommitPatchData&)patch {
  if (patch.isReplace()) {
    (void)[self initWith:patch.getReplace()];
    return;
  }
  assert(patch.isUpdates());
  List<CommitUpdatePatchData> updates = patch.getUpdates();
  for (int i = 0; i < updates.length(); ++i) {
    CommitUpdatePatchData update = updates[i];
    if (update.isRevision()) {
      _revision = update.getRevision();
    } else if (update.isAuthor()) {
      _author = [PresenterUtils decodeString:update.getAuthorData()];
    } else if (update.isMessage()) {
      _message = [PresenterUtils decodeString:update.getMessageData()];
    } else {
      abort();
    }
  }
}

+ (void)applyPatch:(const CommitPatchData&)patch
            atNode:(CommitNode* __strong *)node {
  if (*node) {
    [*node patchWith:patch];
  } else {
    assert(patch.isReplace());
    *node = [[CommitNode alloc] initWith:patch.getReplace()];
  }
}

+ (void)applyListPatch:(const CommitListPatchData&)patchData
                atList:(NSMutableArray*)list {
  List<CommitListUpdatePatchData> updates = patchData.getUpdates();
  for (int i = 0; i < updates.length(); ++i) {
    CommitListUpdatePatchData update = updates[i];
    int index = update.getIndex();
    if (update.isInsert()) {
      NSArray* newCommits = [CommitNode arrayWithData:update.getInsert()];
      int count = newCommits.count;
      NSIndexSet* indexes =
          [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(index, count)];
      [list insertObjects:newCommits atIndexes:indexes];
    } else if (update.isPatch()) {
      List<CommitPatchData> patches = update.getPatch();
      for (int patchIndex = 0; patchIndex < patches.length(); ++patchIndex) {
        int elementIndex = index + patchIndex;
        [list[elementIndex] patchWith:patches[patchIndex]];
      }
    } else if (update.isRemove()) {
      int count = update.getRemove();
      NSIndexSet* indexes =
      [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(index, count)];
      [list removeObjectsAtIndexes:indexes];
    }
  }
}

+ (NSArray*)arrayWithData:(const List<CommitNodeData>&)data {
  return PresenterListUtils<CommitNodeData>::decodeList(data, createCommitNode);
}

@end

