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
  _author = [PresenterUtils decodeStrData:data.getAuthor()];
  _message = [PresenterUtils decodeStrData:data.getMessage()];
  return self;
}

+ (NSArray*)arrayWithData:(const List<CommitNodeData>&)data {
  return PresenterListUtils<CommitNodeData>::decodeList(data, createCommitNode);
}

+ (void)applyListPatch:(const ListCommitNodePatchData&)patch
                atList:(NSArray* __strong *)list {
  if (patch.isReplace()) {
    *list = [CommitNode arrayWithData:patch.getReplace()];
  } else {
    assert(*list != nil);
  }
}

// TODO(zerny): implement proper patching.

@end

