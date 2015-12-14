//
//  LXLXStatusHUDView.h
//  LXStatusHUD
//
//  Created by 从今以后 on 15/12/12.
//  Copyright © 2015年 从今以后. All rights reserved.
//

@import UIKit;
@protocol LXHUDConfiguration;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LXHUDConfiguration)(id<LXHUDConfiguration> configurer);

@protocol LXHUDConfiguration <NSObject>
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) UIColor *ringColor;
@property (nonatomic) UIColor *checkmarkColor;
@property (nonatomic) UIColor *exclamationColor;
@end

@interface LXStatusHUD : UIView

+ (void)showSuccess;
+ (void)showFailure;

+ (void)showSuccessWithConfiguration:(LXHUDConfiguration)configuration;
+ (void)showFailureWithConfiguration:(LXHUDConfiguration)configuration;

@end

NS_ASSUME_NONNULL_END
