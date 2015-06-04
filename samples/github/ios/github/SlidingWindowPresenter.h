// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "CellPresenter.h"

@interface SlidingWindowPresenter
    : NSObject <UITableViewDataSource,
                UITableViewDelegate,
                RootPresenter>

// TODO(zarah): Move access of tableView to controller.
- (id)initWithCellPresenter:(id<CellPresenter>)cellPresenter
                  tableView:(UITableView*)tableView;
- (bool)refresh;

@end
