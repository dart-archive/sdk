// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ConsoleNode.h"

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
  _title = [PresenterUtils decodeStrData:data.getTitle()];
  _status = [PresenterUtils decodeStrData:data.getStatus()];
  return self;
}

+ (void)applyPatches:(const ConsolePatchSet&)patchSet
              atRoot:(ConsoleNode* __strong *)root {
  List<ConsoleNodePatchData> patches = patchSet.getPatches();
  for (int i = 0; i < patches.length(); ++i) {
    [ConsoleNode applyPatch:patches[i] atNode:root];
  }
}

+ (void)applyPatch:(const ConsoleNodePatchData&)patch
            atNode:(ConsoleNode* __strong *)node {
  if (patch.isReplace()) {
    *node = [[ConsoleNode alloc] initWith: patch.getReplace()];
  } else {
    assert(*node);
    if (patch.isTitle()) {
      (*node)->_title = [PresenterUtils decodeStrData:patch.getTitle()];
    } else if (patch.isStatus()) {
      (*node)->_status = [PresenterUtils decodeStrData:patch.getStatus()];
    } else {
      abort();
    }
  }
}

@end
