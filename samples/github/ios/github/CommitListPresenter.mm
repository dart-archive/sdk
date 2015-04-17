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

- (bool)refresh {
  PatchSetData data = GithubPresenterService::refresh();
  bool result = [Node applyPatchSet:data atNode:&_root];
  assert(self.root.isCommitList);
  data.Delete();
  return result;
}

- (void)reset {
  self.root = nil;
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