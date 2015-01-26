// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "echo_shared.h"
#include "objc/echo_service.h"

static void Callback(ServiceApiValueType result, void* data) {
  NSLog([NSString stringWithFormat:@"ObjC: async result %d\n", result]);
}

static void InteractWithService() {
  [EchoService Setup];
  NSInteger result = [EchoService Echo:1];
  NSLog([NSString stringWithFormat:@"ObjC: result %d\n", result]);
  result = [EchoService Echo:2];
  NSLog([NSString stringWithFormat:@"ObjC: result %d\n", result]);
  NSLog(@"ObjC: async call with argument 3\n");
  [EchoService EchoAsync:3 WithCallback:Callback];
  NSLog(@"ObjC: async call with argument 4\n");
  [EchoService EchoAsync:4 WithBlock:^(ServiceApiValueType res) {
    NSLog([NSString stringWithFormat:@"ObjC: async block result %d\n", res]);
  }];
  result = [EchoService Echo:5];
  NSLog([NSString stringWithFormat:@"ObjC: result %d\n", result]);
  [EchoService TearDown];
}

int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc < 2) {
      printf("Usage: %s <snapshot>\n", argv[0]);
      return 1;
    }
    SetupEchoTest(argc, argv);
    InteractWithService();
    TearDownEchoTest();
  }
  return 0;
}
