//
//  LXLXStatusHUDView.m
//  LXStatusHUD
//
//  Created by 从今以后 on 15/12/12.
//  Copyright © 2015年 从今以后. All rights reserved.
//

#import "LXStatusHUD.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - _LXAnimationDelegate -

@interface _LXAnimationDelegate : NSObject
{
    void (^_completion)(BOOL finished);
}
@end
@implementation _LXAnimationDelegate

- (instancetype)initWithCompletion:(void (^)(BOOL finished))completion
{
    self = [super init];
    if (self) {
        _completion = completion;
    }
    return self;
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (_completion) {
        _completion(flag);
        _completion = nil;
    }
}

@end

#pragma mark - CALayer (LXExtension) -

@implementation CALayer (LXExtension)

- (void)lx_addAnimation:(CAAnimation *)anim
                 forKey:(nullable NSString *)key
             completion:(nullable void(^)(BOOL finished))completion
{
    if (completion) {
        anim.delegate = [[_LXAnimationDelegate alloc] initWithCompletion:completion];
    }
    [self addAnimation:anim forKey:key];
}

@end

#pragma mark - UIBezierPath (LXExtension) -

@implementation UIBezierPath (LXExtension)

+ (instancetype)lx_bezierPathWithStartPoint:(CGPoint)start endPoint:(CGPoint)end
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:start];
    [path addLineToPoint:end];
    return path;
}

@end

#pragma mark - _LXHUDConfigurer -

@interface _LXHUDConfigurer : NSObject <LXHUDConfiguration>
@end
@implementation _LXHUDConfigurer
@synthesize radius;
@synthesize lineWidth;
@synthesize ringColor;
@synthesize checkmarkColor;
@synthesize exclamationColor;
@end

#pragma mark - LXStatusHUD -

#define LX_DEBUG 0

static const CFTimeInterval kStrokeRingAnimationDuration    = 1.0;
static const CFTimeInterval kThrowSmallBarAnimationDuration = 0.5;
static const CFTimeInterval kImpactAnimationDuration        = 0.25;
static const CFTimeInterval kExclamationAnimationDuration   = 0.5;
static const CFTimeInterval kCheckmarkAnimationDuration     = 0.5;
static const CFTimeInterval kRemovePatternDelayTime         = 0.5;

static const CGFloat kRadius = 40.0;
static const CGFloat kLineWidth = 10.0;

static inline UIColor * _RingColor()
{
    return [UIColor colorWithRed:0.212 green:0.231 blue:0.322 alpha:1.000];
}

static inline UIColor * _CheckmarkColor()
{
    return [UIColor colorWithRed:0.235 green:0.608 blue:0.431 alpha:1.000];
}

static inline UIColor * _ExclamationColor()
{
    return [UIColor colorWithRed:0.894 green:0.278 blue:0.255 alpha:1.000];
}

static inline CGRect _ScreenBounds()
{
    return UIScreen.mainScreen.bounds;
}

static inline CGPoint _PointOffset(CGPoint point, CGFloat dx, CGFloat dy)
{
    return (CGPoint){ point.x + dx, point.y + dy };
}

static inline CGRect _RectAdjust(CGRect rect, CGFloat dx, CGFloat dy, CGFloat dw, CGFloat dh)
{
    return (CGRect){ rect.origin.x + dx, rect.origin.y + dy, rect.size.width + dw, rect.size.height + dh };
}

static inline CAMediaTimingFunction * _EaseInTimingFunction()
{
    return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
}

static inline CAMediaTimingFunction * _EaseOutTimingFunction()
{
    return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
}

static inline CAMediaTimingFunction * _EaseInEaseOutTimingFunction()
{
    return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
}

static inline void _PerformWithoutAnimation(void (^actionsWithoutAnimation)())
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    actionsWithoutAnimation();
    [CATransaction commit];
}

static inline void _PerformAfterDelay(CFTimeInterval delay, dispatch_block_t block)
{
    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(when, dispatch_get_main_queue(), block);
}

@interface LXStatusHUD () <LXHUDConfiguration>
@end
@implementation LXStatusHUD
{
    CAShapeLayer *_ringLayer;

    CAShapeLayer *_smallBarLayer;

    CAShapeLayer *_leftBigBarLayer;
    CAShapeLayer *_rightBigBarLayer;
    CAShapeLayer *_middleBigBarLayer;

    CAShapeLayer *_checkmarkLayer;

    CAShapeLayer *_topExclamationLayer;
    CAShapeLayer *_bottomExclamationLayer;

    CALayer *_wrapperLayer;

    BOOL _showSuccess;
}
@synthesize radius = _radius;
@synthesize lineWidth = _lineWidth;
@synthesize ringColor = _ringColor;
@synthesize checkmarkColor = _checkmarkColor;
@synthesize exclamationColor = _exclamationColor;

#pragma mark 初始化

- (instancetype)initWithConfigurer:(id<LXHUDConfiguration>)configurer
{
    self = [super initWithFrame:_ScreenBounds()];
    if (self) {
        _radius = configurer.radius;
        _lineWidth = configurer.lineWidth;
        _ringColor = configurer.ringColor;
        _checkmarkColor = configurer.checkmarkColor;
        _exclamationColor = configurer.exclamationColor;
        
        [self _setupRingLayer];
        [self _setupSmallBarLayer];
    }
    return self;
}

+ (instancetype)HUDWithConfiguration:(nullable LXHUDConfiguration)configuration
{
    id<LXHUDConfiguration> configurer = [_LXHUDConfigurer new];

    if (configuration) {
        configuration(configurer);
    }

    if (configurer.radius <= 0) {
        configurer.radius = kRadius;
    }

    if (configurer.lineWidth <= 0) {
        configurer.lineWidth = kLineWidth;
    }

    if (configurer.ringColor == nil) {
        configurer.ringColor = _RingColor();
    }

    if (configurer.checkmarkColor == nil) {
        configurer.checkmarkColor = _CheckmarkColor();
    }

    if (configurer.exclamationColor == nil) {
        configurer.exclamationColor = _ExclamationColor();
    }

    return [[LXStatusHUD alloc] initWithConfigurer:configurer];
}

#pragma mark 公共方法

+ (void)showSuccess
{
    [[self HUDWithConfiguration:nil] _showSuccess];
}

+ (void)showFailure
{
    [[self HUDWithConfiguration:nil] _showFailure];
}

+ (void)showSuccessWithConfiguration:(LXHUDConfiguration)configuration
{
    [[self HUDWithConfiguration:configuration] _showSuccess];
}

+ (void)showFailureWithConfiguration:(LXHUDConfiguration)configuration
{
    [[self HUDWithConfiguration:configuration] _showFailure];
}

#pragma mark - 私有方法 -

- (void)_showSuccess
{
    _showSuccess = YES;

    [self _setupBigBarLayers];
    [self _setupCheckmarkLayer];
    [self _showToWindow];
}

- (void)_showFailure
{
    _showSuccess = NO;

    [self _setupExclamationLayers];
    [self _showToWindow];
}

- (void)_showToWindow
{
#if LX_DEBUG && DEBUG
    [self _debug];
#endif
    [[UIApplication sharedApplication].keyWindow addSubview:self];

    [self _startAnimation];
}

- (void)_startAnimation
{
    [self _performStrokeRingAnimationWithCompletion:^(BOOL finished) {

        [self _performThrowSmallBarAnimationWithCompletion:^(BOOL finished) {

            [self _performShortenSmallBarAnimation];

            _showSuccess ?
            [self _performIncreaseBigBarAnimation] :
            [self _performIncreaseExclamationAnimation];

            [self _performExtrusionRingAnimation];

            _PerformAfterDelay(kImpactAnimationDuration + kRemovePatternDelayTime, ^{
                _showSuccess ?
                [self _removeBigBarLayers],
                [self _performCheckmarkAnimation] :
                [self _performShakeExclamationAnimation];
            });
        }];
    }];
}

#if LX_DEBUG && DEBUG
- (void)_debug
{
    CGColorRef strokeColor = CGColorCreateCopyWithAlpha(_ringLayer.strokeColor, 0.3);

    _ringLayer.strokeColor = strokeColor;
    _ringLayer.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.1].CGColor;

    _smallBarLayer.strokeColor = strokeColor;

    _leftBigBarLayer.strokeColor = strokeColor;
    _rightBigBarLayer.strokeColor = strokeColor;
    _middleBigBarLayer.strokeColor = strokeColor;

    _topExclamationLayer.strokeColor = strokeColor;
    _bottomExclamationLayer.strokeColor = strokeColor;

    /* 小竖条图层的运动路线 */
    [self.layer addSublayer:({
        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.fillColor = nil;
        layer.strokeColor = [UIColor blueColor].CGColor;
        layer.path = [self _createSmallBarAnimationPath].CGPath;
        layer;
    })];

    /*  环形图层压缩至最大程度时的状态 */
    [self.layer addSublayer:({
        CGRect fromPathRect = CGPathGetPathBoundingBox(_ringLayer.path);
        CGRect toPathRect   = _RectAdjust(fromPathRect, -_lineWidth / 2, _lineWidth, _lineWidth, -_lineWidth);

        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.fillColor = nil;
        layer.lineWidth = _lineWidth;
        layer.strokeColor = strokeColor;
        layer.position = _ringLayer.position;
        layer.path = [UIBezierPath bezierPathWithOvalInRect:toPathRect].CGPath;
        layer;
    })];

    CFRelease(strokeColor);
}
#endif

#pragma mark 环形图层

- (void)_setupRingLayer
{
    _ringLayer = [CAShapeLayer layer];
    {
        CGPathRef path = [UIBezierPath bezierPathWithArcCenter:CGPointZero
                                                        radius:_radius
                                                    startAngle:M_PI * +(5 / 4.0)
                                                      endAngle:M_PI * -(3 / 4.0)
                                                     clockwise:NO].CGPath;
        _ringLayer.fillColor   = nil;
        _ringLayer.strokeColor = _ringColor.CGColor;
        _ringLayer.lineWidth   = _lineWidth;
        _ringLayer.path        = path;
        _ringLayer.bounds      = CGPathGetBoundingBox(path);
        _ringLayer.position    = self.center;
    }
    [self.layer addSublayer:_ringLayer];
}

- (void)_performStrokeRingAnimationWithCompletion:(void (^)(BOOL finished))completion
{
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    {
        CABasicAnimation *strokeEndAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        strokeEndAnimation.fromValue = @0;

        CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        rotationAnimation.byValue = @(M_PI * -(5 / 4.0));

        animationGroup.duration       = kStrokeRingAnimationDuration;
        animationGroup.timingFunction = _EaseInEaseOutTimingFunction();
        animationGroup.animations     = @[ strokeEndAnimation, rotationAnimation ];
    }
    [_ringLayer lx_addAnimation:animationGroup forKey:nil completion:completion];
}

- (void)_performExtrusionRingAnimation
{
    CGRect fromPathRect = CGPathGetPathBoundingBox(_ringLayer.path);
    CGRect toPathRect   = _RectAdjust(fromPathRect, -_lineWidth / 2, _lineWidth, _lineWidth, -_lineWidth);

    UIBezierPath *fromPath = [UIBezierPath bezierPathWithOvalInRect:fromPathRect];
    UIBezierPath *toPath   = [UIBezierPath bezierPathWithOvalInRect:toPathRect];

    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    {
        pathAnimation.fromValue      = (__bridge id)fromPath.CGPath;
        pathAnimation.toValue        = (__bridge id)toPath.CGPath;
        pathAnimation.autoreverses   = YES;
        pathAnimation.timingFunction = _EaseOutTimingFunction();
        pathAnimation.duration       = kImpactAnimationDuration / 2;
    }
    [_ringLayer addAnimation:pathAnimation forKey:nil];
}

#pragma mark 小竖条图层

- (void)_setupSmallBarLayer
{
    UIBezierPath *path = [UIBezierPath lx_bezierPathWithStartPoint:CGPointZero
                                                          endPoint:CGPointMake(0, _lineWidth * 2)];
    _smallBarLayer = [CAShapeLayer layer];
    {
        _smallBarLayer.hidden      = YES;
        _smallBarLayer.lineWidth   = _lineWidth / 2;
        _smallBarLayer.strokeColor = _ringColor.CGColor;
        _smallBarLayer.path        = path.CGPath;
        _smallBarLayer.bounds      = path.bounds;
        _smallBarLayer.position    = _PointOffset(self.center, _radius, 0);
    }
    [self.layer addSublayer:_smallBarLayer];
}

- (UIBezierPath *)_createSmallBarAnimationPath
{
    CGPoint ringCenter    = self.center;

    CGPoint startPoint    = _PointOffset(ringCenter, _radius, 0);
    CGPoint endPoint1     = _PointOffset(ringCenter, _radius / 2, -2 * _radius);
    CGPoint controlPoint1 = _PointOffset(ringCenter, _radius, -2 * _radius);

    CGPoint endPoint2     = _PointOffset(ringCenter, 0, -(_radius + 1.5 * _lineWidth));
    CGPoint controlPoint2 = _PointOffset(ringCenter, 0, -2 * _radius);

    UIBezierPath *path = [UIBezierPath bezierPath];
    {
        [path moveToPoint:startPoint];
        [path addQuadCurveToPoint:endPoint1 controlPoint:controlPoint1];
        [path addQuadCurveToPoint:endPoint2 controlPoint:controlPoint2];
    }

    return path;
}

- (void)_performThrowSmallBarAnimationWithCompletion:(void (^)(BOOL finished))completion
{
    CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    {
        positionAnimation.path                = [self _createSmallBarAnimationPath].CGPath;
        positionAnimation.keyTimes            = @[ @0, @0.7, @1 ];
        positionAnimation.rotationMode        = kCAAnimationRotateAuto;
        positionAnimation.duration            = kThrowSmallBarAnimationDuration;
        positionAnimation.timingFunctions     = @[ _EaseOutTimingFunction(), _EaseInTimingFunction() ];
        positionAnimation.removedOnCompletion = NO;
        positionAnimation.fillMode            = kCAFillModeForwards;
    }

    [_smallBarLayer lx_addAnimation:positionAnimation forKey:@"position" completion:^(BOOL finished) {
        [_smallBarLayer removeAnimationForKey:@"position"];
        _PerformWithoutAnimation(^{
            _smallBarLayer.affineTransform = CGAffineTransformIdentity;
        });
        completion(finished);
    }];

    _PerformWithoutAnimation(^{
        _smallBarLayer.hidden = NO;
        // 沿着曲线运动时是横着的，所以需要旋转一下
        _smallBarLayer.affineTransform = CGAffineTransformMakeRotation(M_PI_2);
        _smallBarLayer.position = CGPathGetCurrentPoint(positionAnimation.path);
    });
}

- (void)_performShortenSmallBarAnimation
{
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    {
        CABasicAnimation *strokeStartAnimation = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
        strokeStartAnimation.toValue = @1.0;

        CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position.y"];
        positionAnimation.byValue = @(_lineWidth);

        animationGroup.removedOnCompletion = NO;
        animationGroup.fillMode            = kCAFillModeForwards;
        animationGroup.timingFunction      = _EaseOutTimingFunction();
        animationGroup.duration            = kImpactAnimationDuration / 2;
        animationGroup.animations          = @[ strokeStartAnimation, positionAnimation ];
    }
    [_smallBarLayer lx_addAnimation:animationGroup forKey:nil completion:^(BOOL finished) {
        [_smallBarLayer removeFromSuperlayer];
        _smallBarLayer = nil;
    }];
}

#pragma mark 大竖条图层

- (CAShapeLayer *)_createBigBarLayerWithPath:(CGPathRef)path position:(CGPoint)position
{
    CAShapeLayer *bigBarLayer = [CAShapeLayer layer];
    {
        bigBarLayer.strokeEnd   = 0;
        bigBarLayer.strokeColor = _RingColor().CGColor;
        bigBarLayer.lineWidth   = _lineWidth;
        bigBarLayer.path        = path;
        bigBarLayer.anchorPoint = CGPointMake(0.5, 0);
        bigBarLayer.bounds      = CGPathGetBoundingBox(path);
        bigBarLayer.position    = position;
    }
    return bigBarLayer;
}

- (void)_setupBigBarLayers
{
    CGPoint position   = _PointOffset(self.center, 0, -_radius + _lineWidth / 2);
    CGPoint startPoint = CGPointZero;
    CGPoint endPoint   = { 0, _radius * 2 };
    UIBezierPath *path = [UIBezierPath lx_bezierPathWithStartPoint:startPoint endPoint:endPoint];

    _middleBigBarLayer = [self _createBigBarLayerWithPath:path.CGPath position:position];

    position.y += _radius;
    startPoint = position;
    endPoint   = _PointOffset(startPoint, 0, _radius);
    path       = [UIBezierPath lx_bezierPathWithStartPoint:startPoint endPoint:endPoint];

    _leftBigBarLayer = [self _createBigBarLayerWithPath:path.CGPath position:position];
    _leftBigBarLayer.affineTransform = CGAffineTransformMakeRotation(M_PI / 3);

    path = [UIBezierPath lx_bezierPathWithStartPoint:startPoint endPoint:endPoint];

    _rightBigBarLayer = [self _createBigBarLayerWithPath:path.CGPath position:position];
    _rightBigBarLayer.affineTransform = CGAffineTransformMakeRotation(-M_PI / 3);

    [self.layer addSublayer:_leftBigBarLayer];
    [self.layer addSublayer:_rightBigBarLayer];
    [self.layer addSublayer:_middleBigBarLayer];
}

- (void)_performIncreaseBigBarAnimation
{
    CAKeyframeAnimation *strokeEndAnimaiton1 = [CAKeyframeAnimation animationWithKeyPath:@"strokeEnd"];
    {
        strokeEndAnimaiton1.values = @[ @0.0, @0.5, @1.0 ];
        strokeEndAnimaiton1.keyTimes = @[ @0, @0.5, @1.0 ];
        strokeEndAnimaiton1.duration = kImpactAnimationDuration;
        strokeEndAnimaiton1.timingFunctions = @[ _EaseOutTimingFunction(), _EaseOutTimingFunction() ];
    }
    [_middleBigBarLayer addAnimation:strokeEndAnimaiton1 forKey:nil];

    CABasicAnimation *strokeEndAnimaiton2 = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    {
        strokeEndAnimaiton2.fromValue      = @0.0;
        strokeEndAnimaiton2.toValue        = @1.0;
        strokeEndAnimaiton2.duration       = kImpactAnimationDuration / 2;
        strokeEndAnimaiton2.timingFunction = _EaseOutTimingFunction();
        strokeEndAnimaiton2.fillMode       = kCAFillModeBackwards;
        strokeEndAnimaiton2.beginTime      = CACurrentMediaTime() + kImpactAnimationDuration / 2;
    }
    [_leftBigBarLayer addAnimation:strokeEndAnimaiton2 forKey:nil];
    [_rightBigBarLayer addAnimation:strokeEndAnimaiton2 forKey:nil];

    _PerformWithoutAnimation(^{
        _leftBigBarLayer.strokeEnd = 1.0;
        _rightBigBarLayer.strokeEnd = 1.0;
        _middleBigBarLayer.strokeEnd = 1.0;
    });
}

- (void)_removeBigBarLayers
{
    [_leftBigBarLayer removeFromSuperlayer];
    [_rightBigBarLayer removeFromSuperlayer];
    [_middleBigBarLayer removeFromSuperlayer];

    _leftBigBarLayer = nil;
    _rightBigBarLayer = nil;
    _middleBigBarLayer = nil;
}

#pragma mark 对勾图层

- (void)_setupCheckmarkLayer
{
    CGFloat delta  = _radius / 4;
    CGPoint center = self.center;
    CGPoint point1 = _PointOffset(center, -delta, +delta);
    CGPoint point2 = _PointOffset(center, +delta, +delta);
    CGPoint point3 = _PointOffset(center, +delta, -3 * delta);

    UIBezierPath *checkmarkPath = [UIBezierPath lx_bezierPathWithStartPoint:point1 endPoint:point2];
    {
        [checkmarkPath addLineToPoint:point3];
        [checkmarkPath applyTransform:CGAffineTransformMakeRotation(M_PI / 4)];
    }

    _checkmarkLayer = [CAShapeLayer layer];
    {
        _checkmarkLayer.strokeEnd   = 0;
        _checkmarkLayer.fillColor   = nil;
        _checkmarkLayer.strokeColor = _checkmarkColor.CGColor;
        _checkmarkLayer.lineWidth   = _lineWidth;
        _checkmarkLayer.path        = checkmarkPath.CGPath;
        _checkmarkLayer.bounds      = checkmarkPath.bounds;
        _checkmarkLayer.position    = center;
    }
    [self.layer addSublayer:_checkmarkLayer];
}

- (void)_performCheckmarkAnimation
{
    CABasicAnimation *strokeEndAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    {
        strokeEndAnimation.fromValue      = @0.0;
        strokeEndAnimation.toValue        = @1.0;
        strokeEndAnimation.duration       = kCheckmarkAnimationDuration;
        strokeEndAnimation.timingFunction = _EaseInEaseOutTimingFunction();
    }
    [_checkmarkLayer addAnimation:strokeEndAnimation forKey:nil];

    _PerformWithoutAnimation(^{
        _checkmarkLayer.strokeEnd = 1.0;
    });
    _ringLayer.strokeColor = _checkmarkColor.CGColor;

    _PerformAfterDelay(kCheckmarkAnimationDuration + kRemovePatternDelayTime, ^{
        [self removeFromSuperview];
    });
}

#pragma mark 感叹号图层

- (void)_setupExclamationLayers
{
    CGPoint startPoint = CGPointZero;
    CGPoint endPoint   = { 0, 2 * _radius - 4.5 * _lineWidth };
    CGPoint position   = _PointOffset(self.center, 0, -_radius + _lineWidth / 2);
    UIBezierPath *path = [UIBezierPath lx_bezierPathWithStartPoint:startPoint endPoint:endPoint];

    _topExclamationLayer = [self _createBigBarLayerWithPath:path.CGPath position:position];
    [self.layer addSublayer:_topExclamationLayer];

    endPoint = CGPointMake(0, _lineWidth);
    position = _PointOffset(position, 0, 2 * _radius - _lineWidth);
    path     = [UIBezierPath lx_bezierPathWithStartPoint:startPoint endPoint:endPoint];

    _bottomExclamationLayer = [self _createBigBarLayerWithPath:path.CGPath position:position];
    _bottomExclamationLayer.hidden = YES;
    _bottomExclamationLayer.strokeEnd = 1.0;

    [self.layer addSublayer:_bottomExclamationLayer];
}

- (void)_performIncreaseExclamationAnimation
{
    CABasicAnimation *strokeEndAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    {
        strokeEndAnimation.fromValue      = @0.0;
        strokeEndAnimation.toValue        = @1.0;
        strokeEndAnimation.timingFunction = _EaseOutTimingFunction();
        strokeEndAnimation.duration       = kImpactAnimationDuration / 2;
    }
    [_topExclamationLayer addAnimation:strokeEndAnimation forKey:nil];

    CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position.y"];
    {
        positionAnimation.fromValue      = @(_topExclamationLayer.position.y);
        positionAnimation.byValue        = @(_lineWidth);
        positionAnimation.fillMode       = kCAFillModeBackwards;
        positionAnimation.timingFunction = _EaseOutTimingFunction();
        positionAnimation.duration       = kImpactAnimationDuration / 2;
        positionAnimation.beginTime      = CACurrentMediaTime() + strokeEndAnimation.duration;
    }
    [_topExclamationLayer addAnimation:positionAnimation forKey:nil];

    positionAnimation.byValue   = @(-2 * _lineWidth);
    positionAnimation.fromValue = @(_bottomExclamationLayer.position.y);
    [_bottomExclamationLayer addAnimation:positionAnimation forKey:nil];

    _PerformWithoutAnimation(^{
        _bottomExclamationLayer.hidden   = NO;
        _topExclamationLayer.strokeEnd   = 1.0;
        _topExclamationLayer.position    = _PointOffset(_topExclamationLayer.position, 0, _lineWidth);
        _bottomExclamationLayer.position = _PointOffset(_bottomExclamationLayer.position, 0, -2 * _lineWidth);
    });
}

- (void)_performShakeExclamationAnimation
{
    CAKeyframeAnimation *rotationAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation"];
    {
        rotationAnimation.duration = kExclamationAnimationDuration;
        rotationAnimation.values   = @[ @0, @(M_PI_4 / 3), @(-M_PI_4 / 3),
                                        @(M_PI_4 / 6), @(-M_PI_4 / 6), @0 ];
    }
    [self.layer addAnimation:rotationAnimation forKey:nil];

    _ringLayer.strokeColor = _exclamationColor.CGColor;
    _topExclamationLayer.strokeColor = _exclamationColor.CGColor;
    _bottomExclamationLayer.strokeColor = _exclamationColor.CGColor;

    _PerformAfterDelay(kExclamationAnimationDuration + kRemovePatternDelayTime, ^{
        [self removeFromSuperview];
    });
}

- (void)dealloc
{
    NSLog(@"%@", self);
}

@end

NS_ASSUME_NONNULL_END
