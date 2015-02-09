// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "echo_shared.h"
#include "objc/echo_service.h"

static void EchoCallback(int result) {
  NSLog([NSString stringWithFormat: @"ObjC: async result %d\n", result]);
}

static void InteractWithService() {
  [EchoService Setup];
  NSInteger result = [EchoService echo: 1];
  NSLog([NSString stringWithFormat: @"ObjC: result %d\n", result]);
  result = [EchoService echo: 2];
  NSLog([NSString stringWithFormat: @"ObjC: result %d\n", result]);
  NSLog(@"ObjC: async call with argument 3\n");
  [EchoService echoAsync: 3 withCallback: EchoCallback];
  NSLog(@"ObjC: async call with argument 4\n");
  [EchoService echoAsync: 4 withBlock: ^(int res) {
    NSLog([NSString stringWithFormat: @"ObjC: async block result %d\n", res]);
  }];
  result = [EchoService echo: 5];
  NSLog([NSString stringWithFormat: @"ObjC: result %d\n", result]);
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
