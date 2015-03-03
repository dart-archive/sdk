// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ConsolePresenter.h"
#import "ConsoleNode.h"

#include "buildbot_service.h"

@implementation ConsolePresenter

- (void)refresh {
  PresenterPatchSet patchSet = BuildBotService::refresh();
  [ConsoleNode applyPatches:patchSet.getConsolePatchSet() atRoot:&_root];
  patchSet.Delete();
}

@end
