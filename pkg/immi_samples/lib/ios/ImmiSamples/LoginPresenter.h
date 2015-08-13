// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
// Copyright (c) 2015 Google Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ViewPresenter.h"
#import "Immi.h"

@interface LoginPresenter : UIViewController <ViewPresenter,
                                              LoginPresenter,
                                              UITextFieldDelegate>
@property (weak,nonatomic) IBOutlet UITextField* username;
@property (weak,nonatomic) IBOutlet UITextField* password;
@property (weak,nonatomic) IBOutlet UILabel* response;
@property (weak,nonatomic) IBOutlet UILabel* user;
@property (weak,nonatomic) IBOutlet UIButton* loginButton;
@property (weak,nonatomic) IBOutlet UIButton* logoutButton;

@property (readonly) UIViewController* viewController;
@end
