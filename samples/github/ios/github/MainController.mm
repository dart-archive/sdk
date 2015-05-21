// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "MainController.h"
#import "github.h"

@interface MainController ()

@property UINavigationController* commitListController;
@property UINavigationController* menuController;

@end

@implementation MainController

- (void)viewDidLoad {
  [super viewDidLoad];

  ImmiService* immi = [[ImmiService alloc] init];

  UIStoryboard *storyboard =
      [UIStoryboard storyboardWithName:@"Main" bundle:nil];

  [immi registerStoryboard:storyboard];

  self.commitListController =
      (UINavigationController*)[immi getPresenterByName:@"CommitListPresenter"];

  self.menuController =
      [storyboard instantiateViewControllerWithIdentifier:@"MenuID"];

  self.centerViewController = self.commitListController;
  self.leftDrawerViewController = self.menuController;

  self.shouldStretchDrawer = NO;
  self.openDrawerGestureModeMask = MMOpenDrawerGestureModePanningCenterView;
  self.closeDrawerGestureModeMask = MMCloseDrawerGestureModePanningDrawerView
                                  | MMCloseDrawerGestureModeTapCenterView;
}

@end
