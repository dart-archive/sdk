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
    NSLog(@"Got a patch...");
  }
  if (patches.length() == 0) NSLog(@"Empty patch set");
}

- (void)reset {
  GithubPresenterService::reset();
}

@end