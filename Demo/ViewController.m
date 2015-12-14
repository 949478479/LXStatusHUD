//
//  ViewController.m
//  LXStatusHUD
//
//  Created by 从今以后 on 15/12/11.
//  Copyright © 2015年 从今以后. All rights reserved.
//

#import "ViewController.h"
#import "LXStatusHUD.h"

@interface ViewController ()

@end

@implementation ViewController

- (IBAction)success:(id)sender {

//    [LXStatusHUD showSuccessWithConfiguration:^(id<LXHUDConfiguration>  _Nonnull configurer) {
//        configurer.checkmarkColor = [UIColor orangeColor];
//    }];

    [LXStatusHUD showSuccess];

}

- (IBAction)failure:(id)sender {

//    [LXStatusHUD showFailureWithConfiguration:^(id<LXHUDConfiguration>  _Nonnull configurer) {
//        configurer.radius = 60;
//        configurer.lineWidth = 15;
//        configurer.exclamationColor = [UIColor greenColor];
//    }];

    [LXStatusHUD showFailure];
}

@end
