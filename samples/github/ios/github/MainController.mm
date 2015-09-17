// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "MainController.h"
#import "CommitListPresenter.h"

#import "ImmiSamples/DrawerPresenter.h"
#import "ImmiSamples/LoginPresenter.h"
#import "ImmiSamples/MenuPresenter.h"
#import "ImmiSamples/SlidingWindowPresenter.h"

#import "github_mock.h"

@interface AnyNodePresenter : NSObject <ViewPresenter, NodePresenter>
@property CommitListPresenter* commitListPresenter;
@property LoginPresenter* loginPresenter;
@property MenuPresenter* menuPresenter;
@property id<ViewPresenter> currentPresenter;
- (id)init:(UIStoryboard*)storyboard;
@end

@interface LeftPresenter : NSObject <ViewPresenter, NodePresenter>
@property MenuPresenter* presenter;
- (id)init:(UIStoryboard*)storyboard;
@end

@interface MainController () <NodePresenter, DrawerPresenter>
@property ImmiRoot* immiRoot;
@property DrawerPresenter* drawerPresenter;
@property AnyNodePresenter* centerPresenter;
@property AnyNodePresenter* leftPresenter;
@end

@implementation AnyNodePresenter

- (id)init:(UIStoryboard*)storyboard {
  self.commitListPresenter =
    [storyboard instantiateViewControllerWithIdentifier:@"CommitListPresenter"];
  self.loginPresenter =
    [storyboard instantiateViewControllerWithIdentifier:@"LoginPresenter"];
  self.menuPresenter =
    [storyboard instantiateViewControllerWithIdentifier:@"MenuPresenter"];
  return self;
}

- (void)presentNode:(Node*)node {
  if ([node is:SlidingWindowNode.class]) {
    self.currentPresenter = self.commitListPresenter;
    [self.commitListPresenter
       presentSlidingWindow:[node as:SlidingWindowNode.class]];
  } else if ([node is:LoginNode.class]) {
    self.currentPresenter = self.loginPresenter;
    [self.loginPresenter presentLogin:[node as:LoginNode.class]];
  } else if ([node is:MenuNode.class]) {
    self.currentPresenter = self.menuPresenter;
    [self.menuPresenter presentMenu:[node as:MenuNode.class]];
  } else {
    abort();
  }
}

- (void)patchNode:(NodePatch*)patch {
  if ([patch is:SlidingWindowPatch.class]) {
    SlidingWindowPatch* p = [patch as:SlidingWindowPatch.class];
    [p applyTo:self.commitListPresenter];
  } else if ([patch is:LoginPatch.class]) {
    LoginPatch* p = [patch as:LoginPatch.class];
    [p applyTo:self.loginPresenter];
  } else if ([patch is:MenuPatch.class]) {
    MenuPatch* p = [patch as:MenuPatch.class];
    [p applyTo:self.menuPresenter];
  } else {
    abort();
  }
}

- (UIViewController*)viewController {
  return [self.currentPresenter viewController];
}

@end

@implementation MainController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Ensure that the github mock server is running.
  // TODO(zerny): Dynamically configure the http port.
  GithubMockServer::start(8321);

  UIStoryboard* storyboard =
      [UIStoryboard storyboardWithName:@"Main" bundle:nil];

  self.centerPresenter = [[AnyNodePresenter alloc] init:storyboard];
  self.leftPresenter = [[AnyNodePresenter alloc] init:storyboard];
  self.rightPresenter = [[AnyNodePresenter alloc] init:storyboard];

  // Create a drawer presenter do to the interpretation work.
  self.drawerPresenter =
      [[DrawerPresenter alloc] initWithCenterPresenter:self.centerPresenter
                                         leftPresenter:self.leftPresenter
                                        rightPresenter:self.rightPresenter];

  // Create the IMMI service.
  ImmiService* immi = [[ImmiService alloc] init];

  // Register a root presenter for the DrawerPresenter root.
  self.immiRoot = [immi registerPresenter:self forName:@"DrawerPresenter"];

  // Render the initial graph.
  [self.immiRoot refresh];

  // Setup some drawer properties.
  self.shouldStretchDrawer = NO;

  self.openDrawerGestureModeMask = MMOpenDrawerGestureModePanningCenterView;

  self.closeDrawerGestureModeMask = MMCloseDrawerGestureModePanningDrawerView |
                                    MMCloseDrawerGestureModePanningCenterView |
                                    MMCloseDrawerGestureModeTapCenterView;

  // Monitor when the side panes close.
  [self setDrawerVisualStateBlock:^(MMDrawerController* mySelf,
                                    MMDrawerSide drawerSide,
                                    CGFloat percentVisible) {
    MainController* mainController = (MainController*)mySelf;
    if (percentVisible == 0.0 && mainController.openSide == drawerSide) {
      [mainController setVisibility:drawerSide visible:false];
    }
  }];
}

- (void)presentNode:(Node*)node {
  [self presentDrawer:[node as:DrawerNode.class]];
}

- (void)patchNode:(NodePatch*)patch {
  [self patchDrawer:[patch as:DrawerPatch.class]];
}

- (void)presentDrawer:(DrawerNode*)node {
  [self.drawerPresenter presentDrawer:node];
  [self performSelectorOnMainThread:@selector(presentOnMainThread:)
                         withObject:node
                      waitUntilDone:NO];
}

- (void)presentOnMainThread:(DrawerNode*)node {
  self.centerViewController =
      [self.drawerPresenter.centerPresenter viewController];
  [self.drawerPresenter addDrawerButtons:self.centerViewController];
  self.leftDrawerViewController =
      [self.drawerPresenter.leftPresenter viewController];
  self.rightDrawerViewController =
      [self.drawerPresenter.rightPresenter viewController];
}

- (void)patchDrawer:(DrawerPatch*)patch {
  [self.drawerPresenter patchDrawer:patch];
  [self performSelectorOnMainThread:@selector(patchOnMainThread:)
                         withObject:patch
                      waitUntilDone:NO];
}

- (void)patchOnMainThread:(DrawerPatch*)patch {
  if (patch.center.changed) {
    self.centerViewController =
        [self.drawerPresenter.centerPresenter viewController];
    if (patch.center.replaced) {
      [self.drawerPresenter addDrawerButtons:self.centerViewController];
    }
  }
  if (patch.left.changed) {
    self.leftDrawerViewController =
        [self.drawerPresenter.leftPresenter viewController];
  }
  if (patch.right.changed) {
    self.rightDrawerViewController =
        [self.drawerPresenter.rightPresenter viewController];
  }
  if (patch.leftVisible.changed && patch.leftVisible.current) {
    [self openPane:MMDrawerSideLeft];
  } else if (patch.rightVisible.changed && patch.rightVisible.current) {
    [self openPane:MMDrawerSideRight];
  } else if (patch.leftVisible.changed || patch.rightVisible.changed) {
    [self closeDrawerAnimated:YES completion:nil];
  }
}

- (void)openPane:(MMDrawerSide)side {
  if (self.openSide == side) return;
  [self openDrawerSide:side animated:YES completion:nil];
}

- (void)prepareToPresentDrawer:(MMDrawerSide)drawer animated:(BOOL)animated {
  [super prepareToPresentDrawer:drawer animated:animated];
  [self setVisibility:drawer visible:true];
}

- (void)setVisibility:(MMDrawerSide)side visible:(bool)visible {
  if (side == MMDrawerSideLeft) {
    self.drawerPresenter.leftVisible = visible;
  } else if (side == MMDrawerSideRight) {
    self.drawerPresenter.rightVisible = visible;
  }
}

@end
