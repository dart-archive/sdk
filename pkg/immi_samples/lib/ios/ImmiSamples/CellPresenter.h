// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "Immi.h"

@protocol CellPresenter

@property (readonly) CGFloat minimumCellHeight;

- (UITableViewCell*)tableView:(UITableView*)tableView
                    indexPath:(NSIndexPath*)indexPath
                      present:(Node*)node;

- (CGFloat)tableView:(UITableView*)tableView
    heightForRowAtIndexPath:(NSIndexPath*)indexPath;

- (CGFloat)tableView:(UITableView*)tableView
    estimatedHeightForRowAtIndexPath:(NSIndexPath*)indexPath;
@end
