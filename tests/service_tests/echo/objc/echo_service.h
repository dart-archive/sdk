// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include <Foundation/Foundation.h>

@interface EchoService : NSObject

+ (void)Setup;
+ (void)TearDown;

+ (int32_t)echo:(int32_t)n;
+ (void)echoAsync:(int32_t)n withCallback:(void (*)(int))callback;
+ (void)echoAsync:(int32_t)n withBlock:(void (^)(int))callback;
+ (int32_t)sum:(int16_t)x with:(int32_t)y;
+ (void)sumAsync:(int16_t)x with:(int32_t)y withCallback:(void (*)(int))callback;
+ (void)sumAsync:(int16_t)x with:(int32_t)y withBlock:(void (^)(int))callback;

@end
