// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <UIKit/UIKit.h>

static NSString* StatusHeaderCellId = @"StatusHeaderPrototypeCell";

@interface StatusHeaderCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end
