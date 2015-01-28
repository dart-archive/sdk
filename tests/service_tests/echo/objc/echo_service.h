// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include <Foundation/Foundation.h>

@interface EchoService : NSObject

+ (void)Setup;
+ (void)TearDown;

+ (int)Echo:(int)n;
+ (void)EchoAsync:(int)n WithCallback:(void (*)(int))callback;
+ (void)EchoAsync:(int)n WithBlock:(void (^)(int))callback;

@end
