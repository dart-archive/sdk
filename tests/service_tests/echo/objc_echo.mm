// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "echo_shared.h"
#include "objc/echo_service.h"

static void EchoCallback(int result) {
  NSLog([NSString stringWithFormat: @"ObjC: async result %d\n", result]);
}

static void SumCallback(int result) {
  NSLog([NSString stringWithFormat: @"ObjC: sum async result %d\n", result]);
}

static void InteractWithService() {
  [EchoService Setup];
  NSInteger result = [EchoService Echo: 1];
  NSLog([NSString stringWithFormat: @"ObjC: result %d\n", result]);
  result = [EchoService Echo: 2];
  NSLog([NSString stringWithFormat: @"ObjC: result %d\n", result]);
  NSLog(@"ObjC: async call with argument 3\n");
  [EchoService EchoAsync: 3 withCallback: EchoCallback];
  NSLog(@"ObjC: async call with argument 4\n");
  [EchoService EchoAsync: 4 withBlock: ^(int res) {
    NSLog([NSString stringWithFormat: @"ObjC: async block result %d\n", res]);
  }];
  result = [EchoService Echo: 5];
  NSLog([NSString stringWithFormat: @"ObjC: result %d\n", result]);
  result = [EchoService Sum: 3 with: 4];
  NSLog([NSString stringWithFormat: @"ObjC: result of sum(3, 4) is %d\n",
                  result]);
  [EchoService SumAsync: 3 with: 4 withCallback: SumCallback];
  [EchoService SumAsync: 3 with: 4 withBlock: ^(int res) {
    NSLog([NSString stringWithFormat: @"ObjC: async sum block result %d\n",
                    res]);
  }];
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
