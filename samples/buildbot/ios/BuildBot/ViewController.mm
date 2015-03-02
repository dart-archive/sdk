// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ViewController.h"

#import "ConsoleNode.h"
#import "ConsolePresenter.h"

#include "buildbot_service.h"

@interface ViewController ()

@property ConsolePresenter* presenter;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Attach the console presenter with a 1-second refresh rate.
  self.presenter = [[ConsolePresenter alloc] init];
  CADisplayLink* consoleLink =
    [CADisplayLink
     displayLinkWithTarget:self
                  selector:@selector(refreshConsole:)];
  [consoleLink setFrameInterval:60];
  [consoleLink addToRunLoop:[NSRunLoop currentRunLoop]
                    forMode:NSDefaultRunLoopMode];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)refreshConsole:(CADisplayLink*)sender {
  [self.presenter refresh];

  // TODO(zerny): move this to an onChange listener.
  [self.status setText:[[self.presenter root] status]];
}

@end
