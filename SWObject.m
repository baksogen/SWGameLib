////  SWObject.m//  SWGameLib//////  Copyright (c) 2010 Sangwoo Im////  Permission is hereby granted, free of charge, to any person obtaining a copy//  of this software and associated documentation files (the "Software"), to deal//  in the Software without restriction, including without limitation the rights//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell//  copies of the Software, and to permit persons to whom the Software is//  furnished to do so, subject to the following conditions:////  The above copyright notice and this permission notice shall be included in//  all copies or substantial portions of the Software.////  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN//  THE SOFTWARE.//  //  Created by Sangwoo Im on 4/13/10.//  Copyright 2010 Sangwoo Im. All rights reserved.//#import "SWObject.h"#import "SWGameLib.h"#import "CCAction.h"#import "CCActionInterval.h"#import "ccMacros.h"#import "SimpleAudioEngine.h"@interface SWObject()@property (nonatomic, retain) NSDictionary        *_userData;@property (nonatomic, retain) NSDictionary        *_animInfo;@property (nonatomic, retain) NSDictionary        *_sfxInfo;@property (nonatomic, retain) NSMutableDictionary *_animActions;@end@implementation SWObject@dynamic position;@dynamic rotation;@dynamic animActions;@synthesize objectID      = _objectID;@synthesize sprite        = _sprite;@synthesize spriteParent  = _spriteParent;@synthesize zOrder        = _zOrder;@synthesize playerIdx     = _playerIdx;@synthesize _userData;@synthesize _animInfo;@synthesize _sfxInfo;@synthesize _animActions;#pragma mark -#pragma mark init-(id)init {    if ((self = [super init])) {        _userData = [NSMutableDictionary new];    }    return self;}+(id)objectWithTemplate:(NSDictionary *)info {    return [[[[self class] alloc] initWithTemplate:info] autorelease];}-(id)initWithTemplate:(NSDictionary *)info {    if ((self = [super init])) {        NSAutoreleasePool *pool;        CCNode            *ccSheet;        CCNode            *ccSprite;                _objectID = 0;        _zOrder   = 0;        pool      = [NSAutoreleasePool new];         _userData = [[info valueForKey:kSWOData] retain];                if (info) {            _key      = [[info valueForKey:kSWOTemplateKey] retain];            ccSheet   = [info valueForKey:kSWOSpriteParent];            ccSprite  = [CCSprite spriteWithSpriteFrameName:[info valueForKey:kSWOSprite]];                        self._sfxInfo      = [info valueForKey:kSWOSoundEffects];            self._animInfo     = [info valueForKey:kSWOAnimations];            ccSprite.userData  = self;            self.sprite        = ccSprite;            self.spriteParent  = ccSheet;            _animActions       = [[NSMutableDictionary alloc] init];        }        [pool drain];    }    return self;}-(void)spawn {    [_spriteParent addChild:_sprite z:_zOrder];}-(void)despawn {    [_spriteParent removeChild:_sprite cleanup:YES];}-(id)dataValueForKey:(NSString *)key {    return [_userData valueForKey:key];}-(NSComparisonResult)compare:(SWObject *)obj {    if (_objectID > obj.objectID) {        return NSOrderedDescending;    } else if (_objectID < obj.objectID) {        return NSOrderedAscending;    }    return NSOrderedSame;}#pragma mark -#pragma mark properties-(NSString *)templateKey {    return _key;}-(CGPoint)position {    return _sprite.position;}-(CGFloat)rotation {    return CC_DEGREES_TO_RADIANS(_sprite.rotation);}-(void)setPosition:(CGPoint)pos {    _sprite.position = pos;}-(void)setRotation:(CGFloat)rot {    _sprite.rotation = CC_RADIANS_TO_DEGREES(rot);}-(NSDictionary *)animActions {    return _animActions;}#pragma mark -#pragma mark Animations and Sound Effects-(void)playAnimation:(NSString *)key {    CCAction *action;    [self stopAnimation:key];    if (!(action = [_animActions valueForKey:key]) ||        ![action isKindOfClass:[CCAnimate class]]) {        action = [CCAnimate actionWithAnimation:[_animInfo valueForKey:key]];        [_animActions setValue:action forKey:key];    }    [_sprite runAction:action];}-(void)playAnimation:(NSString *)key repeat:(NSInteger)repeat {    CCAction *action;    [self stopAnimation:key];    if (repeat > 0) {        if (!(action = [_animActions valueForKey:key]) ||            ![action isKindOfClass:[CCRepeat class]]) {            action = [CCRepeat actionWithAction:[CCAnimate actionWithAnimation:[_animInfo valueForKey:key]]                                          times:repeat];            [_animActions setValue:action forKey:key];        }    } else {        if (!(action = [_animActions valueForKey:key]) ||            ![action isKindOfClass:[CCRepeatForever class]]) {            action = [CCRepeatForever actionWithAction:[CCAnimate actionWithAnimation:[_animInfo valueForKey:key]]];            [_animActions setValue:action forKey:key];        }    }    [_sprite runAction:action];}-(void)stopAnimation:(NSString *)key {    CCAction *action;    if ((action = [_animActions valueForKey:key])) {        [_sprite stopAction:action];    }}-(void)playSFX:(NSString *)key {    NSString *name;    if ((name = [_sfxInfo valueForKey:key])) {        [[SimpleAudioEngine sharedEngine] playEffect:name];    } else {        SWLog(@"SFX cannot be found in object template: %@", key);    }}#pragma mark -#pragma mark periodic updates-(void)update {    }#pragma mark -#pragma mark dealloc-(void)dealloc {    [_key release];    [_animActions release];    [_animInfo release];    [_sfxInfo release];    [_sprite release];    [_spriteParent release];    [_userData release];    [super dealloc];}@end