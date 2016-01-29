// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "todomvc_presenter.h"

#import <Foundation/Foundation.h>

@interface TodoItem : NSObject

@property NSString *itemName;
@property BOOL completed;
@property event deleteEvent;
@property event completeEvent;
@property event uncompleteEvent;

@property (readonly) NSDate *creationDate;

- (void)dispatchDeleteEvent;
- (void)dispatchCompleteEvent;
- (void)dispatchUncompleteEvent;

@end
