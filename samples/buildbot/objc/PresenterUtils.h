// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>

#include "buildbot_service.h"

@interface PresenterUtils : NSObject

+ (NSString*)decodeString:(const List<unichar>&)chars;
+ (void)encodeString:(NSString*)string into:(List<unichar>)chars;

@end

template<typename T>
class PresenterListUtils {
public:
  typedef id (*DecodeElementFunction)(const T&);

  static NSMutableArray* decodeList(const List<T>& list,
                                    DecodeElementFunction decodeElement) {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:list.length()];
    for (int i = 0; i < list.length(); ++i) {
      [array addObject:decodeElement(list[i])];
    }
    return array;
  }
};
