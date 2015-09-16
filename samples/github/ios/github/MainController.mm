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

@interface CenterPresenter : NSObject <ViewPresenter, NodePresenter>
@property CommitListPresenter* presenter;
- (id)init:(UIStoryboard*)storyboard;
@end

@interface LeftPresenter : NSObject <ViewPresenter, NodePresenter>
@property MenuPresenter* presenter;
- (id)init:(UIStoryboard*)storyboard;
@end

@interface RightPresenter : NSObject <ViewPresenter, NodePresenter>
@property LoginPresenter* presenter;
- (id)init:(UIStoryboard*)storyboard;
@end

@interface MainController () <NodePresenter, DrawerPresenter>
@property ImmiRoot* immiRoot;
@property DrawerPresenter* drawerPresenter;
@property CenterPresenter* centerPresenter;
@property LeftPresenter* leftPresenter;
@property RightPresenter* rightPresenter;
@end

@implementation CenterPresenter

- (id)init:(UIStoryboard*)storyboard {
  self.presenter = [storyboard
      instantiateViewControllerWithIdentifier:@"CommitListPresenter"];
  return self;
}

- (void)presentNode:(Node*)node {
  [self.presenter presentSlidingWindow:[node as:SlidingWindowNode.class]];
}

- (void)patchNode:(NodePatch*)patch {
  [self.presenter patchSlidingWindow:[patch as:SlidingWindowPatch.class]];
}

- (UIViewController*)viewController {
  return [self.presenter viewController];
}

@end

@implementation LeftPresenter

- (id)init:(UIStoryboard*)storyboard {
  self.presenter =
      [storyboard instantiateViewControllerWithIdentifier:@"MenuPresenter"];
  return self;
}

- (void)presentNode:(Node*)node {
  [self.presenter presentMenu:[node as:MenuNode.class]];
}

- (void)patchNode:(NodePatch*)patch {
  [self.presenter patchMenu:[patch as:MenuPatch.class]];
}

- (UIViewController*)viewController {
  return [self.presenter viewController];
}
@end

@implementation RightPresenter

- (id)init:(UIStoryboard*)storyboard {
  self.presenter =
    [storyboard instantiateViewControllerWithIdentifier:@"LoginPresenter"];
  return self;
}

- (void)presentNode:(Node*)node {
  [self.presenter presentLogin:[node as:LoginNode.class]];
}

- (void)patchNode:(NodePatch*)patch {
  [self.presenter patchLogin:[patch as:LoginPatch.class]];
}

- (UIViewController*)viewController {
  return [self.presenter viewController];
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

  self.centerPresenter = [[CenterPresenter alloc] init:storyboard];
  self.leftPresenter = [[LeftPresenter alloc] init:storyboard];
  self.rightPresenter = [[RightPresenter alloc] init:storyboard];

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
