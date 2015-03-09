// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>

#include "buildbot_service.h"

@interface CommitNode : NSObject

@property (readonly) int revision;
@property (readonly) NSString* author;
@property (readonly) NSString* message;

- (id)initWith:(const CommitNodeData&)data;

+ (NSArray*)arrayWithData:(const List<CommitNodeData>&)data;

+ (void)applyListPatch:(const ListCommitNodePatchData&)patch
                atList:(NSArray* __strong *)list;

@end
