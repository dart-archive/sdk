// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "AppDelegate.h"

#include "include/dartino_api.h"
#include "include/service_api.h"

#include "github_mock.h"
#include "immi_service.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

static dispatch_queue_t queue;

static bool attachDebugger = false;
static int debugPortNumber = 8123;

+ (void)loadAndRunDartSnapshot {
  if (attachDebugger) {
    NSLog(@"Waiting for debugger connection.");
    DartinoWaitForDebuggerConnection(debugPortNumber);
    NSLog(@"Debugger connected.");
  } else {
    DartinoProgram programs[2];
    programs[0] = [AppDelegate loadSnapshot:@"github"];
    programs[1] = [AppDelegate loadSnapshot:@"github_mock_service"];
    DartinoRunMultipleMain(2, programs);
    DartinoDeleteProgram(programs[0]);
    DartinoDeleteProgram(programs[1]);
  }
}

+ (DartinoProgram)loadSnapshot:(NSString*)name {
  // Get the path for the snapshot in the main application bundle.
  NSBundle* mainBundle = [NSBundle mainBundle];
  NSString* snapshot = [mainBundle pathForResource:name ofType:@"snapshot"];
  // Read the snapshot and pass it to dartino.
  NSData* data = [[NSData alloc] initWithContentsOfFile:snapshot];
  unsigned char* bytes =
      reinterpret_cast<unsigned char*>(const_cast<void*>(data.bytes));
  return DartinoLoadSnapshot(bytes, data.length);
}

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  // Setup Dartino and the Dartino service API.
  DartinoSetup();
  ServiceApiSetup();
  // Create dispatch queue to run the Dartino VM on a separate thread.
  queue = dispatch_queue_create("com.google.dartino.dartQueue",
                                DISPATCH_QUEUE_SERIAL);
  // Post task to load and run snapshot on a different thread.
  dispatch_async(queue, ^() {
    [AppDelegate loadAndRunDartSnapshot];
  });
  // Setup the services.
  GithubMockServer::setup();
  ImmiServiceLayer::setup();
  return YES;
}

- (void)applicationWillResignActive:(UIApplication*)application {
  // Sent when the application is about to move from active to inactive
  // state. This can occur for certain types of temporary interruptions (such as
  // an incoming phone call or SMS message) or when the user quits the
  // application and it begins the transition to the background state.  Use this
  // method to pause ongoing tasks, disable timers, and throttle down OpenGL ES
  // frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
  // Use this method to release shared resources, save user data, invalidate
  // timers, and store enough application state information to restore your
  // application to its current state in case it is terminated later.  If your
  // application supports background execution, this method is called instead of
  // applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
  // Called as part of the transition from the background to the inactive state;
  // here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
  // Restart any tasks that were paused (or not yet started) while the
  // application was inactive. If the application was previously in the
  // background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication*)application {
  // Called when the application is about to terminate. Save data if
  // appropriate. See also applicationDidEnterBackground:.
  GithubMockServer::stop();

  // Tear down the service API structures and Dartino.
  ImmiServiceLayer::tearDown();
  GithubMockServer::tearDown();
  ServiceApiTearDown();
  DartinoTearDown();
}

@end
