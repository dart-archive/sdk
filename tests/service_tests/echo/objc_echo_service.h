// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ager): This file should be auto-generated from something like.
//
// service EchoService {
//   Echo(int32) : int32;
// }

#include <Foundation/Foundation.h>

#include "include/service_api.h"

typedef void (^ServiceApiBlock)(ServiceApiValueType);

@interface EchoService : NSObject

+ (void)Setup;
+ (void)TearDown;
+ (ServiceApiValueType)Echo:(ServiceApiValueType)arg;
+ (void)EchoAsync:(ServiceApiValueType)arg
        WithCallback:(ServiceApiCallback)callback;
+ (void)EchoAsync:(ServiceApiValueType)arg
        WithBlock:(ServiceApiBlock)block;

@end
