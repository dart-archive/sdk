// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>

#include "buildbot_service.h"

@interface PresenterUtils : NSObject

+ (NSString*)decodeStrData:(const StrData&)str;

@end
