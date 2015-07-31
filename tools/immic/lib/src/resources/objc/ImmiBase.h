// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "immi_service.h"

@protocol Node <NSObject>
@end

@protocol Patch <NSObject>
@property (readonly) bool changed;
@end

@protocol NodePatch <Patch>
@property (readonly) bool replaced;
@property (readonly) bool updated;
@property (readonly) id <Node> previous;
@property (readonly) id <Node> current;
@end

@interface Node : NSObject <Node>
- (bool)is:(Class)klass;
- (id)as:(Class)klass;
@end

@class NodePatch;

@protocol NodePresenter <NSObject>
- (void)presentNode:(Node*)node;
- (void)patchNode:(NodePatch*)patch;
@end

@interface NodePatch : NSObject <NodePatch>
@property (readonly) bool changed;
@property (readonly) Node* previous;
@property (readonly) Node* current;
- (void)applyTo:(id <NodePresenter>)presenter;
- (bool)is:(Class)klass;
- (id)as:(Class)klass;
@end

@interface BoolPatch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) bool previous;
@property (readonly) bool current;
@end

@interface Uint8Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) uint8_t previous;
@property (readonly) uint8_t current;
@end

@interface Uint16Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) uint16_t previous;
@property (readonly) uint16_t current;
@end

@interface Uint32Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) uint32_t previous;
@property (readonly) uint32_t current;
@end

@interface Uint64Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) uint64_t previous;
@property (readonly) uint64_t current;
@end

@interface Int8Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) int8_t previous;
@property (readonly) int8_t current;
@end

@interface Int16Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) int16_t previous;
@property (readonly) int16_t current;
@end

@interface Int32Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) int32_t previous;
@property (readonly) int32_t current;
@end

@interface Int64Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) int64_t previous;
@property (readonly) int64_t current;
@end

@interface Float32Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) float previous;
@property (readonly) float current;
@end

@interface Float64Patch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) double previous;
@property (readonly) double current;
@end

@interface StringPatch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) NSString* previous;
@property (readonly) NSString* current;
@end

@interface ListRegionPatch : NSObject
@property (readonly) bool isRemove;
@property (readonly) bool isInsert;
@property (readonly) bool isUpdate;
@property (readonly) int index;
@end

@interface ListRegionRemovePatch : ListRegionPatch
@property (readonly) int count;
@end

@interface ListRegionInsertPatch : ListRegionPatch
@property (readonly) NSArray* nodes;
@end

@interface ListRegionUpdatePatch : ListRegionPatch
@property (readonly) NSArray* updates;
@end

@interface ListPatch : NSObject <Patch>
@property (readonly) bool changed;
@property (readonly) NSArray* regions;
@property (readonly) NSArray* previous;
@property (readonly) NSArray* current;
@end

typedef void (^ImmiDispatchBlock)();

@interface ImmiRoot : NSObject
- (void)refresh;
- (void)reset;
- (void)dispatch:(ImmiDispatchBlock)block;
@end

@interface ImmiService : NSObject
- (ImmiRoot*)registerPresenter:(id <NodePresenter>)presenter
                       forName:(NSString*)name;
- (void)registerStoryboard:(UIStoryboard*)storyboard;
- (ImmiRoot*)getRootByName:(NSString*)name;
- (id <NodePresenter>)getPresenterByName:(NSString*)name;
@end
