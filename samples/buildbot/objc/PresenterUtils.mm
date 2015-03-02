// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "PresenterUtils.h"

@implementation PresenterUtils

+ (NSString*)decodeStrData:(const StrData&)str {
  List<uint8_t> chars = str.getChars();
  unsigned length = chars.length();
  return [[NSString alloc]
           initWithBytes:chars.data()
                  length:length encoding:NSASCIIStringEncoding];
}

@end
