// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ImmiSamples/CellPresenter.h"
#import "ImmiSamples/ImagePresenter.h"

@interface CommitCellPresenter : UITableViewCell <CellPresenter>

@property (weak, nonatomic) IBOutlet UILabel* revisionLabel;
@property (weak, nonatomic) IBOutlet UILabel* authorLabel;
@property (weak, nonatomic) IBOutlet UILabel* messageLabel;
@property (weak, nonatomic) IBOutlet UILabel* detailsLabel;
@property (weak, nonatomic) IBOutlet ImagePresenter* avatarImage;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView* spinner;

@property NSIndexPath* index;

@end
