////  SWPhysicsObject.h//  SWGameLib//////  Copyright (c) 2010 Sangwoo Im////  Permission is hereby granted, free of charge, to any person obtaining a copy//  of this software and associated documentation files (the "Software"), to deal//  in the Software without restriction, including without limitation the rights//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell//  copies of the Software, and to permit persons to whom the Software is//  furnished to do so, subject to the following conditions:////  The above copyright notice and this permission notice shall be included in//  all copies or substantial portions of the Software.////  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN//  THE SOFTWARE.//  //  Created by Sangwoo Im on 4/19/10.//  Copyright 2010 Sangwoo Im. All rights reserved.//#import <Foundation/Foundation.h>#import "SWObject.h"#import "chipmunk.h"#import "CCSprite.h"@class SWDefaultObjectManager;/** * This class extends SWObject to support chipmunk. * * @remark You must use SWDefaultObjectTemplates class to instantiate this class. */@interface SWPhysicsObject : SWObject {@protected    CGPoint                   _lastContactPoint;    NSMutableArray            *_constraints;    cpShape                   *_shape;    BOOL                      _enablePosUpdate;    BOOL                      _enableRotUpdate;    CCSprite                  *_shadow;    CGFloat                   _zHeight;    NSTimeInterval            _lastUpdate;@private    SWPhysicsObject           *_parent;    SWDefaultObjectManager    *_spawnManager;}/** * time stamp for updates */@property (nonatomic, assign)           NSTimeInterval  lastUpdate;/** * imaginary z height that is used for shadow offsetting. */@property (nonatomic, assign)           CGFloat         zHeight;/** * Shadow sprite object. can be nil. */@property (nonatomic, retain)           CCSprite        *shadow;/** * Set it to NO if you want to disable position updates from chipmunk */@property (nonatomic, assign)           BOOL            enablePosUpdate;/** * Set it to No if you want to disable rotation updates from chipmunk */@property (nonatomic, assign)           BOOL            enableRotUpdate;/** * constraints */@property (nonatomic, retain, readonly) NSArray         *constraints;/** * parent object */@property (nonatomic, assign)           SWPhysicsObject *parent;/**  * last contact point that is generated by chipmunk */@property (nonatomic, assign, readonly) CGPoint lastContactPoint;/** * mass of the object. Use object template to set this value initially. */@property (nonatomic, assign, readonly) cpFloat mass;/** * friction of the object. Use object template to set this value initially. */@property (nonatomic, assign, readonly) cpFloat friction;/** * elasticity of the object. Use object template to set this value initially. */@property (nonatomic, assign, readonly) cpFloat elasticity;/** * collision layer */@property (nonatomic, assign) cpLayers collisionLayers;/** * linear velocity vector */@property (nonatomic, assign) cpVect linearVelocity;/** * angular velocity */@property (nonatomic, assign) cpFloat angularVelocity;/** * shape of the object. updates to chipmunk objects need to be done with available interfaces, not directly. */@property (nonatomic, assign, readonly) cpShape *shape;/** * manager to handle spawn, despawn, updates of this object. */@property (nonatomic, assign) SWDefaultObjectManager *spawnManager;/** * Determines whether a collision with other object at a given point is possible. * * @param p contact point * @param obj object to be collided with * @return YES if collision is possible. */-(BOOL)beginCollisionWithPoint:(CGPoint)p object:(SWPhysicsObject *)obj;/** * Determines whether a collision has any kind of after effects * @param YES if there is a aftereffect to process */-(BOOL)afterEffectsExist:(SWPhysicsObject *)obj;/** * Process after effects */-(void)processAfterEffectsWithObject:(SWPhysicsObject *)obj;/** * Do any kinds of clean up */-(void)endCollisionWithObject:(SWPhysicsObject *)obj;/** * applies a new force accumulatively to the current force. * @param f the new force */-(void)applyForce:(cpVect)f;/** * Resets the current force to 0 */-(void)resetForce;/** * move the current object to a given point in a given time period */-(void)moveTo:(CGPoint)pos inTime:(CGFloat)dt;@end@interface SWPhysicsObject()/** * all subclasses need to override this method instead of spawn method. */-(void)spawnOnCurrentThread;/** * all subclasses need to override this method instead of despawn method. */-(void)despawnOnCurrentThread;@end