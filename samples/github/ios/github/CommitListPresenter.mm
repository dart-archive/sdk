// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "CommitListPresenter.h"

#import <Foundation/Foundation.h>

@interface CommitListPresenter ()

@end

@implementation CommitListPresenter

- (id)init {
  self.root = nil;
  return self;
}

- (void)refresh {
  PatchSetData data = GithubPresenterService::refresh();
  List<PatchData> patches = data.getPatches();
  for (int i = 0; i < patches.length(); ++i) {
    PatchData patch = patches[i];
    List<uint8_t> path = patch.getPath();
    if (path.length() == 0) {
      assert(patch.getContent().getNode().isCommitList());
      self.root = [[CommitListNode alloc] initWith:patch.getContent().getNode().getCommitList()];
    } else {
      // TODO(zerny): support a non-root patch.
      abort();
    }
  }
}

- (void)reset {
  GithubPresenterService::reset();
}

- (int)commitCount {
  return self.root == nil ? 0 : self.root.commits.count;
}

- (CommitNode*)commitAtIndex:(int)index {
  assert(self.root != nil);
  return [self.root.commits objectAtIndex:index];
}

@end