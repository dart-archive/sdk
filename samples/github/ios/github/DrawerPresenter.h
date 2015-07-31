// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <UIKit/UIKit.h>

#import "Immi.h"
#import "ViewPresenter.h"

@interface DrawerPresenter : NSObject <DrawerPresenter>

typedef id<ViewPresenter, NodePresenter> DynamicPresenter;

@property DynamicPresenter centerPresenter;
@property DynamicPresenter leftPresenter;
@property DynamicPresenter rightPresenter;

@property bool leftVisible;
@property bool rightVisible;

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter
                leftPresenter:(DynamicPresenter)leftPresenter
               rightPresenter:(DynamicPresenter)rightPresenter
    NS_DESIGNATED_INITIALIZER;

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter;

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter
                leftPresenter:(DynamicPresenter)leftPresenter;

- (id)initWithCenterPresenter:(DynamicPresenter)centerPresenter
               rightPresenter:(DynamicPresenter)rightPresenter;

- (void)toggleLeft;
- (void)toggleRight;

- (void)addDrawerButtons:(UIViewController*)controller;

@end
