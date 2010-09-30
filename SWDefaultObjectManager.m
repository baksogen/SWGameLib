////  SWDefaultSpawnManager.m//  SWGameLib//////  Copyright (c) 2010 Sangwoo Im////  Permission is hereby granted, free of charge, to any person obtaining a copy//  of this software and associated documentation files (the "Software"), to deal//  in the Software without restriction, including without limitation the rights//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell//  copies of the Software, and to permit persons to whom the Software is//  furnished to do so, subject to the following conditions:////  The above copyright notice and this permission notice shall be included in//  all copies or substantial portions of the Software.////  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN//  THE SOFTWARE.//  //  Created by Sangwoo Im on 4/13/10.//  Copyright 2010 Sangwoo Im. All rights reserved.//#import "SWDefaultObjectManager.h"#import "Util.h"#import "SWEvent.h"#import "CGPointExtension.h"#import "CCScheduler.h"#import "SWDebug.h"#import "SWPhysicsObject.h"#import "SWObjConstraint.h"#import "SWObjectTemplates.h"#import "NSMutableArray+SWObjectSorting.h"#define SWObjPosition           @"CGPoint"#define SWObjLayers             @"cpLayers"#define SWPointQueryReceiver    @"delegate"#define ITERATIONS  10@interface SWDefaultObjectManager()@property (nonatomic, retain) NSMutableArray   *_events;@property (nonatomic, retain) NSMutableArray   *_spawningObjects;@property (nonatomic, retain) NSMutableArray   *_despawningObjects;@property (nonatomic, retain) NSMutableArray   *_spawnedObjects;@property (nonatomic, retain) NSOperationQueue *_opPEQueue;@property (nonatomic, retain) NSOperationQueue *_opEUQueue;-(void)_addToScene:(SWPhysicsObject *)obj;-(void)_removeFromScene:(SWPhysicsObject *)obj;-(void)_updateChipmunk;-(void)_updateEvents;-(void)_spawnEntity:(SWPhysicsObject *)entity;-(void)_despawnEntity:(SWPhysicsObject *)entity;-(void)_update:(ccTime)elapsed;-(void)_initChipmunk;-(void)_pointQueryWithInfo:(NSDictionary *)info;-(void)_addEvent:(SWEvent *)event;-(void)_removeEvent:(SWEvent *)event;void eachShape(void *shapePtr, void *userData);// collision handlersint ignoreBeginFunc(cpArbiter *arb, struct cpSpace *space, void *data);int ignorePreSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data);void ignorePostSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data);void ignoreSeparateFunc(cpArbiter *arb, struct cpSpace *space, void *data);int simpleBeginFunc(cpArbiter *arb, struct cpSpace *space, void *data);int simplePreSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data);void simplePostSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data);void simpleSeparateFunc(cpArbiter *arb, struct cpSpace *space, void *data);int OOBeginFunc(cpArbiter *arb, struct cpSpace *space, void *data);int OOPreSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data);void OOPostSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data);void OOSeparateFunc(cpArbiter *arb, struct cpSpace *space, void *data);@end@implementation SWDefaultObjectManager@synthesize _spawningObjects;@synthesize _despawningObjects;@synthesize _spawnedObjects;@synthesize _opPEQueue;@synthesize _opEUQueue;@synthesize _events;@synthesize lightSource = _lightSource;@dynamic    opPEQueue;+(id)manager {    return [[[self alloc] init] autorelease];}-(id)init {    if ((self = [super init])) {        NSAutoreleasePool *pool;        pool = [NSAutoreleasePool new];                self._events            = [NSMutableArray array];        self._spawningObjects   = [NSMutableArray array];        self._despawningObjects = [NSMutableArray array];        self._spawnedObjects    = [NSMutableArray array];        self._opPEQueue         = [[NSOperationQueue new] autorelease];        self._opEUQueue         = [[NSOperationQueue new] autorelease];                [_opPEQueue setSuspended:YES];        [_opPEQueue setMaxConcurrentOperationCount:1];                [_opEUQueue setSuspended:YES];        [_opEUQueue setMaxConcurrentOperationCount:1];                [[CCScheduler sharedScheduler] scheduleSelector:@selector(_update:)                                               forTarget:self                                               interval:PE_UPDATE_TIME                                                 paused:YES];        _tagCounter  = 1;        _updateOp    = _eventOp = nil;        _lightSource = CGPointZero;                [self _initChipmunk];        [pool drain];    }    return self;}-(void)dealloc {    [[CCScheduler sharedScheduler] unscheduleSelector:@selector(_update:)                                            forTarget:self];    [_spawningObjects   release];    [_spawnedObjects    release];    [_despawningObjects release];    [_opPEQueue         release];    [_opEUQueue         release];    [_events            release];        cpSpaceFreeChildren(_cmSpace);    cpSpaceFree(_cmSpace);        [super dealloc];}-(void)onEnter {    cpSpaceSetDefaultCollisionHandler(_cmSpace,                                      &ignoreBeginFunc,                                      &ignorePreSolveFunc,                                      &ignorePostSolveFunc,                                      &ignoreSeparateFunc,                                      self);    [self resume:self];}-(void)onExit {    [self pause:self];        while (_updateOp) {}    while (_eventOp) {}        @synchronized(_spawnedObjects) {        for (SWPhysicsObject *obj in _spawnedObjects) {            [_despawningObjects addObject:obj];        }            [_spawnedObjects removeAllObjects];    }    for (SWPhysicsObject *obj in _despawningObjects) {        cpBody  *body;        cpShape *shape;                shape  = obj.shape;        body   = shape->body;                for (SWObjConstraint *c in [obj constraints]) {            cpSpaceRemoveConstraint(_cmSpace, c.constraint);        }                if (shape) {            if (cpBodyGetMoment(body) == INFINITY &&                cpBodyGetMass(body)   == INFINITY) {                cpSpaceRemoveStaticShape(_cmSpace, shape);            } else {                cpSpaceRemoveBody(_cmSpace, body);                cpSpaceRemoveShape(_cmSpace, shape);            }        }    }        [_spawningObjects   removeAllObjects];    [_despawningObjects removeAllObjects];}-(void)pause:(id)sender {    [[CCScheduler sharedScheduler] pauseTarget:self];    [_opPEQueue setSuspended:YES];    [_opEUQueue setSuspended:YES];}-(void)resume:(id)sender {    [[CCScheduler sharedScheduler] resumeTarget:self];    [_opPEQueue setSuspended:NO];    [_opEUQueue setSuspended:NO];    _lastPEUpdate = [[NSDate date] timeIntervalSince1970];}-(void)_initChipmunk {    cpInitChipmunk();    _cmSpace = cpSpaceNew();	_cmSpace->gravity    = ccp(0, 0);    _cmSpace->iterations = ITERATIONS;    }-(cpSpace *)physicalSpace {    return _cmSpace;}-(NSOperationQueue *)opPEQueue {    return _opPEQueue;}#pragma mark -#pragma mark Events-(void)addEvent:(SWEvent *)event {    [_opEUQueue addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_addEvent:) object:event] autorelease]];}-(void)removeEvent:(SWEvent *)event {    [_opEUQueue addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_removeEvent:) object:event] autorelease]];}-(void)_addEvent:(SWEvent *)event {    [_events addObject:event];}-(void)_removeEvent:(SWEvent *)event {    [_events removeObject:event];}-(void)_updateEvents {    for (SWEvent *event in _events) {        [event update];    }    _eventOp = nil;}#pragma mark -#pragma mark Object Creation/Removal/Update-(void)spawnEntity:(SWPhysicsObject *)entity {    if (entity.objectID == 0) {        if (entity.shape->group == 0) {            entity.shape->group = entity.objectID = _tagCounter;        }        if (_tagCounter+1 == NSUIntegerMax) {            _tagCounter = 1;        } else {            _tagCounter++;        }        [_opPEQueue addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_spawnEntity:) object:entity] autorelease]];     }}-(void)despawnEntity:(SWPhysicsObject *)entity {    if (entity.spawnManager == self) {        entity.spawnManager   = nil;        entity.sprite.visible = NO;        [_opPEQueue addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_despawnEntity:) object:entity] autorelease]];     }}-(void)_update:(ccTime)elapsed {    if (!_updateOp) { // no update operation is being run        _updateOp = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_updateChipmunk) object:nil] autorelease];        [_opPEQueue addOperation:_updateOp];     }        if (!_eventOp) { // no update operation is being run        _eventOp = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_updateEvents) object:nil] autorelease];        [_opEUQueue addOperation:_eventOp];     }}-(void)_spawnEntity:(SWPhysicsObject *)entity {    [_spawningObjects addObject:entity];}-(void)_despawnEntity:(SWPhysicsObject *)entity {    [_despawningObjects addObject:entity];}-(void)_updateChipmunk {    NSAutoreleasePool *pool;    cpBody            *body;    cpShape           *shape;    cpFloat           elapsed;    NSTimeInterval    newUpdateTime;        pool = [NSAutoreleasePool new];    for (SWPhysicsObject *entity in _spawningObjects) {        shape  = entity.shape;        body   = shape->body;                if (shape) {            if (cpBodyGetMoment(body) == INFINITY &&                cpBodyGetMass(body)   == INFINITY) {                shape->group = 0;                cpSpaceAddStaticShape(_cmSpace, shape);            } else {                cpSpaceAddBody(_cmSpace, body);                cpSpaceAddShape(_cmSpace, shape);            }            for (SWObjConstraint *c in [entity constraints]) {                SWAssert([c retainCount] == 1, @"There is more than one parent for a constraint!");                cpSpaceAddConstraint(_cmSpace, c.constraint);            }        }                [self performSelectorOnMainThread:@selector(_addToScene:) withObject:entity waitUntilDone:NO];        @synchronized(_spawnedObjects) {            [_spawnedObjects insertSortedObject:entity];        }    }    [_spawningObjects removeAllObjects];        for (SWPhysicsObject *entity in _despawningObjects) {        shape  = entity.shape;        body   = shape->body;                [self performSelectorOnMainThread:@selector(_removeFromScene:) withObject:entity waitUntilDone:NO];        @synchronized(_spawnedObjects) {            [_spawnedObjects removeSortedObject:entity];        }        if (shape) {            for (SWObjConstraint *c in [entity constraints]) {                cpSpaceRemoveConstraint(_cmSpace, c.constraint);            }            if (cpBodyGetMoment(body) == INFINITY &&                cpBodyGetMass(body)   == INFINITY) {                cpSpaceRemoveStaticShape(_cmSpace, shape);            } else {                cpSpaceRemoveBody(_cmSpace, body);                cpSpaceRemoveShape(_cmSpace, shape);            }        }    }    [_despawningObjects removeAllObjects];        newUpdateTime = [[NSDate date] timeIntervalSince1970];    elapsed       = newUpdateTime - _lastPEUpdate;    _lastPEUpdate = newUpdateTime;    cpSpaceHashEach(_cmSpace->activeShapes, &eachShape, nil);    cpSpaceStep(_cmSpace, elapsed);           [pool drain];    _updateOp = nil;}#pragma mark -#pragma mark Queries-(BOOL)isSpawningEntity:(SWPhysicsObject *)entity {    return [_spawningObjects containsObject:entity];}-(BOOL)isDespawningEntity:(SWPhysicsObject *)entity {    return [_despawningObjects containsObject:entity];}-(NSArray *)spawnedEntities {    @synchronized(_spawnedObjects) {        return _spawnedObjects;    }}-(NSUInteger)objectIDOfEntity:(SWPhysicsObject *)entity {    return entity.objectID;}-(SWPhysicsObject *)entityWithObjectID:(NSUInteger)idx {    @synchronized(_spawnedObjects) {        SWPhysicsObject *obj;        obj = (SWPhysicsObject *)[_spawnedObjects objectWithObjectID:idx];                return obj;    }}-(void)entityAtPosition:(CGPoint)pos inLayers :(cpLayers)layers withDelegate:(id <SWPointQueryDelegate>)delegate {    NSDictionary *info;        info = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGPoint:pos], SWObjPosition,            [NSNumber numberWithUnsignedInt:layers], SWObjLayers, delegate, SWPointQueryReceiver, nil];    [_opPEQueue addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_pointQueryWithInfo:) object:info] autorelease]];}-(void)_pointQueryWithInfo:(NSDictionary *)info {    cpShape *found;    id <SWPointQueryDelegate> delegate;        delegate = [info valueForKey:SWPointQueryReceiver];    found    = cpSpacePointQueryFirst(_cmSpace, [[info valueForKey:SWObjPosition] CGPointValue], [[info valueForKey:SWObjLayers] unsignedIntValue], 0);        if (found) {        [delegate objectManager:self foundObject:(SWPhysicsObject *)found->data atPoint:[info valueForKey:SWObjPosition]];    } else {        [delegate objectManager:self foundObject:nil atPoint:[info valueForKey:SWObjPosition]];    }}#pragma mark -#pragma mark Cocos2d add/remove-(void)_addToScene:(SWPhysicsObject *)obj {    if (obj.shadow) {        [obj.spriteParent addChild:obj.shadow z:obj.zOrder-1];    }    [obj.spriteParent addChild:obj.sprite z:obj.zOrder];}-(void)_removeFromScene:(SWPhysicsObject *)obj {    [obj.spriteParent removeChild:obj.sprite cleanup:YES];    if (obj.shadow) {        [obj.spriteParent removeChild:obj.shadow cleanup:YES];    }}#pragma mark -#pragma mark Collision Handlers-(void)registerNegligibleCollisionWithType:(cpCollisionType)t1 type:(cpCollisionType)t2 {    cpSpaceAddCollisionHandler(_cmSpace, t1, t2,                               &ignoreBeginFunc,                               &ignorePreSolveFunc,                               &ignorePostSolveFunc,                               &ignoreSeparateFunc,                               self);}-(void)registerSimpleCollisionWithType:(cpCollisionType)t1 type:(cpCollisionType)t2 {    cpSpaceAddCollisionHandler(_cmSpace, t1, t2,                               &simpleBeginFunc,                               &simplePreSolveFunc,                               &simplePostSolveFunc,                               &simpleSeparateFunc,                               self);}-(void)registerObjectCollisionWithType:(cpCollisionType)t1 type:(cpCollisionType)t2 {    cpSpaceAddCollisionHandler(_cmSpace, t1, t2,                               &OOBeginFunc,                               &OOPreSolveFunc,                               &OOPostSolveFunc,                               &OOSeparateFunc,                               self);}#pragma mark Ignored Collisionsint ignoreBeginFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    cpArbiterIgnore(arb);    return 0;}int ignorePreSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    return 0;}void ignorePostSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    }void ignoreSeparateFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    }#pragma mark Simple Collisionsint simpleBeginFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    return 1;}int simplePreSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    return 1;}void simplePostSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    }void simpleSeparateFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    }#pragma mark Object vs. Object Collisionsint OOBeginFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    cpShape         *a, *b;    SWPhysicsObject *obj1, *obj2;        cpArbiterGetShapes(arb, &a, &b);        obj1 = (SWPhysicsObject *)a->data;    obj2 = (SWPhysicsObject *)b->data;        if ([obj1 beginCollisionWithPoint:cpArbiterGetPoint(arb, 0) object:obj2]) {        return 1;    }        return 0;}int OOPreSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    cpShape         *a, *b;    SWPhysicsObject *obj1, *obj2;        cpArbiterGetShapes(arb, &a, &b);        obj1 = (SWPhysicsObject *)a->data;    obj2 = (SWPhysicsObject *)b->data;        if ([obj1 afterEffectsExist:obj2]) {        return 1;    }    return 0;}void OOPostSolveFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    cpShape         *a, *b;    SWPhysicsObject *obj1, *obj2;        cpArbiterGetShapes(arb, &a, &b);        obj1 = (SWPhysicsObject *)a->data;    obj2 = (SWPhysicsObject *)b->data;        [obj1 processAfterEffectsWithObject:obj2];}void OOSeparateFunc(cpArbiter *arb, struct cpSpace *space, void *data) {    cpShape         *a, *b;    SWPhysicsObject *obj1, *obj2;        cpArbiterGetShapes(arb, &a, &b);        obj1 = (SWPhysicsObject *)a->data;    obj2 = (SWPhysicsObject *)b->data;        [obj1 endCollisionWithObject:obj2];}#pragma mark -#pragma mark C functionsvoid eachShape(void *shapePtr, void *userData) {    cpShape  *shape;    SWPhysicsObject *entity;        shape  = (cpShape *)shapePtr;    entity = (SWPhysicsObject *)shape->data;    if (entity.spawnManager) {        [entity update];    }}@end