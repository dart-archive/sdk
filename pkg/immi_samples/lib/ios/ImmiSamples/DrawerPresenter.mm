// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "DrawerPresenter.h"

@interface PanePresenter : NSObject <ViewPresenter, NodePresenter>

@property DynamicPresenter presenter;
@property bool empty;
@property UIViewController* emptyViewController;

- (id)initWithPresenter:(DynamicPresenter)presenter NS_DESIGNATED_INITIALIZER;

@end

@interface DrawerPresenter ()

@property DrawerNode* root;

@end

@implementation DrawerPresenter {
  PanePresenter* _leftPresenter;
  PanePresenter* _rightPresenter;
}

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter
                leftPresenter:(DynamicPresenter)leftPresenter
               rightPresenter:(DynamicPresenter)rightPresenter {
  _centerPresenter = centerPresenter;
  _leftPresenter = [[PanePresenter alloc] initWithPresenter:leftPresenter];
  _rightPresenter = [[PanePresenter alloc] initWithPresenter:rightPresenter];
  return self;
}

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter {
  return [self initWithCenterPresenter:centerPresenter
                         leftPresenter:nil
                        rightPresenter:nil];
}

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter
                leftPresenter:(DynamicPresenter)leftPresenter {
  return [self initWithCenterPresenter:centerPresenter
                         leftPresenter:leftPresenter
                        rightPresenter:nil];
}

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter
               rightPresenter:(DynamicPresenter)rightPresenter {
  return [self initWithCenterPresenter:centerPresenter
                         leftPresenter:nil
                        rightPresenter:rightPresenter];
}

- (void)presentDrawer:(DrawerNode*)node {
  self.root = node;
  [_centerPresenter presentNode:node.center];
  [_leftPresenter presentNode:node.left];
  [_rightPresenter presentNode:node.right];
}

- (void)patchDrawer:(DrawerPatch*)patch {
  self.root = patch.current;
  [patch.center applyTo:_centerPresenter];
  [patch.left applyTo:_leftPresenter];
  [patch.right applyTo:_rightPresenter];
}

- (DynamicPresenter)leftPresenter {
  return _leftPresenter;
}
- (void)setLeftPresenter:(DynamicPresenter)leftPresenter {
  _leftPresenter.presenter = leftPresenter;
}

- (DynamicPresenter)rightPresenter {
  return _rightPresenter;
}
- (void)setRightPresenter:(DynamicPresenter)rightPresenter {
  _rightPresenter.presenter = rightPresenter;
}

- (bool)leftVisible {
  return self.root.leftVisible;
}
- (void)setLeftVisible:(bool)leftVisible {
  if (self.leftVisible != leftVisible) [self toggleLeft];
}

- (bool)rightVisible {
  return self.root.rightVisible;
}
- (void)setRightVisible:(bool)rightVisible {
  if (self.rightVisible != rightVisible) [self toggleRight];
}

- (void)toggleLeft {
  self.root.toggleLeft();
}

- (void)toggleRight {
  self.root.toggleRight();
}

// TODO(zerny): This is not the right place or way to add buttons.
- (void)addDrawerButtons:(UIViewController*)controller {
  if (![controller isKindOfClass:UINavigationController.class]) return;
  UINavigationController* nav = (UINavigationController*)controller;
  if (_leftPresenter.presenter != nil) {
    UIBarButtonItem* leftToggle =
        [[UIBarButtonItem alloc] initWithTitle:@"Show"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(toggleLeft)];
    nav.topViewController.navigationItem.leftBarButtonItem = leftToggle;
  }
  if (_rightPresenter.presenter != nil) {
    UIBarButtonItem* rightToggle =
        [[UIBarButtonItem alloc] initWithTitle:@"Show"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(toggleRight)];
    nav.topViewController.navigationItem.rightBarButtonItem = rightToggle;
  }
}

@end

@implementation PanePresenter

- (id)initWithPresenter:(DynamicPresenter)presenter {
  self = [super init];
  self.empty = true;
  self.presenter = presenter;
  self.emptyViewController = [[UIViewController alloc] init];
  return self;
}

- (void)presentNode:(Node*)node {
  self.empty = [node is:EmptyPaneNode.class];
  if (!self.empty) [self.presenter presentNode:node];
}

- (void)patchNode:(NodePatch*)patch {
  assert(!self.empty);
  [self.presenter patchNode:patch];
}

- (UIViewController*)viewController {
  if (self.presenter == nil) return nil;
  return self.empty ? self.emptyViewController
                    : [self.presenter viewController];
}

@end
