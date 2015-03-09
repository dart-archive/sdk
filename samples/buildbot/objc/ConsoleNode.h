// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>

#include "buildbot_service.h"

@interface ConsoleNode : NSObject

@property (readonly) NSString* title;
@property (readonly) NSString* status;
@property (readonly) NSArray* commits;

- (id)initWith:(const ConsoleNodeData&)data;

+ (void)applyPatches:(const ConsolePatchSet&)patchSet
              atRoot:(ConsoleNode* __strong *)root;

@end
