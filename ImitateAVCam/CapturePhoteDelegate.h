//
//  CapturePhoteDelegate.h
//  ImitateAVCam
//
//  Created by ChenWei on 16/10/19.
//  Copyright © 2016年 cw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

//typedef enum{
//    kCapturePhoteMessageFailure = 0, // 失败
//    kCapturePhoteMessageSussess      // 成功
//}CapturePhoteMessage;

@interface CapturePhoteDelegate : NSObject <AVCapturePhotoCaptureDelegate>
@property (strong, nonatomic) AVCapturePhotoSettings *capturePhotoSetting;
//- (instancetype)initWithSetting:
@property (strong, nonatomic) NSData *photoData;
/** 结束capturek后回调block */
@property (copy, nonatomic) void (^filishedCaptureCallBackBlock)(NSError *error);
@end
