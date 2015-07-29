// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import "ImagePresenter.h"

@interface ImagePresenter ()
@property id<ImageCache> imageCache;
@end

@implementation ImagePresenter

- (void)setCache:(id<ImageCache>)cache {
  self.imageCache = cache;
}

- (void)setDefaultImage:(UIImage*)defaultImage {
  self.image = defaultImage;
}

- (void)presentImageFromData:(NSData*) imageData {
  self.image = [UIImage imageWithData:imageData];
}

- (void)patchImage:(ImagePatch*)patch {
  if (patch.url.changed) {
    [self performSelectorOnMainThread:@selector(loadImageFromUrl:)
                           withObject:patch.url.current
                        waitUntilDone:NO];
  }
}

- (void)presentImage:(ImageNode*)node {
  [self performSelectorOnMainThread:@selector(loadImageFromUrl:)
                         withObject:node.url
                      waitUntilDone:NO];
}

- (void)loadImageFromUrl:(NSString*)url {
  assert(NSThread.isMainThread);

  if (self.imageCache == nil) {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      NSData* imageData =
      [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:url]];
      [self presentImageFromData:imageData];
    });
  } else {
    id cachedImage = [self.imageCache get:url];
    if (cachedImage != nil) {
      if ([cachedImage isKindOfClass:NSMutableArray.class]) {
        [cachedImage addObject:self];
      } else {
        [self presentImageFromData:cachedImage];
      }
    } else {
      NSMutableArray* waitingImages = [[NSMutableArray alloc] init];
      [waitingImages addObject:self];
      [self.imageCache put:url value:waitingImages];

      dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSData* imageData =
          [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:url]];

        if (imageData == nil) return;

        dispatch_async(dispatch_get_main_queue(), ^{
          NSMutableArray* queue = [self.imageCache get:url];
          [self.imageCache put:url value:imageData];

          [queue enumerateObjectsUsingBlock:^(ImagePresenter* imagePresenter,
                                              NSUInteger idx,
                                              BOOL* stop) {
            [imagePresenter presentImageFromData:imageData];
          }];
        });
      });
    }
  }
}

@end
