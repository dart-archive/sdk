// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "LoginPresenter.h"

@interface LoginPresenter()
@property UINavigationController* navigationController;
@property Node* loginState;
@end

@implementation LoginPresenter

- (void)viewDidLoad {
  self.password.delegate = self;
  [self.logoutButton setEnabled:NO];
}

-(id)initWithCoder:(NSCoder*)aDecoder {
  self = [super initWithCoder:aDecoder];
  self.navigationController =
    [[UINavigationController alloc] initWithRootViewController:self];
  return self;
}

- (void)presentLogin:(LoginNode*)node {
  [self updateLoginState:node.state];
}

- (void)patchLogin:(LoginPatch*)patch {
  [self updateLoginState:patch.current.state];
}

- (void)updateLoginState:(Node*)state {
  self.loginState = state;
  if ([state is:LoginRequestStateNode.class]) {

    LoginRequestStateNode* loginRequestNode =
      [state as:LoginRequestStateNode.class];
    HttpsRequestNode* requestNode = loginRequestNode.request;

    NSString* authToken = requestNode.authorization;
    NSURL* url = [NSURL URLWithString:requestNode.url];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:authToken forHTTPHeaderField:@"Authorization"];
    NSURLSession* session = [NSURLSession sharedSession];
    NSURLSessionDataTask* postDataTask =
    [session dataTaskWithRequest:request
               completionHandler:^(NSData* data,
                                   NSURLResponse* response,
                                   NSError* error) {
                 NSString* json =
                   [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding];
                 requestNode.handleResponse(json);
               }];
    [postDataTask resume];
  } else if  ([state is:LoggedInStateNode.class]) {
    LoggedInStateNode* loggedInStateNode = [state as:LoggedInStateNode.class];

    dispatch_async(dispatch_get_main_queue(),^() {
      [self.logoutButton setEnabled:YES];
      [self.loginButton setEnabled:NO];
      [self.username setEnabled:NO];
      [self.password setEnabled:NO];
      [self.user setText:loggedInStateNode.user];
      [self.response setText:@""];
    });
  } else if ([state is:LoggedOutStateNode.class]) {
    dispatch_async(dispatch_get_main_queue(),^() {
      LoggedOutStateNode* loggedOutNode = [state as:LoggedOutStateNode.class];

      [self.logoutButton setEnabled:NO];
      [self.loginButton setEnabled:YES];
      [self.username setEnabled:YES];
      [self.password setEnabled:YES];
      [self.response setText:loggedOutNode.message];
      [self.user setText:@""];
    });
  }
}

- (IBAction)handleLogin:(id)sender {
  if ([self.loginState is:LoggedOutStateNode.class]) {
    LoggedOutStateNode* node = [self.loginState as:LoggedOutStateNode.class];
    node.login(self.username.text, self.password.text);

    [self.username setText: @""];
    [self.password setText: @""];
  }
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
  [self handleLogin:textField];
  return YES;
}

- (IBAction)handleLogout:(id)sender {
   if ([self.loginState is:LoggedInStateNode.class]) {
     LoggedInStateNode* loggedIn = [self.loginState as:LoggedInStateNode.class];
     loggedIn.logout();
  }
}

- (UIViewController*)viewController {
  return self.navigationController;
}

@end
