// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include <Foundation/Foundation.h>

#include "include/service_api.h"

typedef void (^ServiceApiBlock)(ServiceApiValueType);

@interface EchoService : NSObject

+ (void)Setup;
+ (void)TearDown;

+ (ServiceApiValueType)Echo:(ServiceApiValueType)arg;
+ (void)EchoAsync:(ServiceApiValueType)arg WithCallback:(ServiceApiCallback)cb;
+ (void)EchoAsync:(ServiceApiValueType)arg WithBlock:(ServiceApiBlock)block;

@end
