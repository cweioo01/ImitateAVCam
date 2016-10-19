//
//  CapturePhoteDelegate.m
//  ImitateAVCam
//
//  Created by ChenWei on 16/10/19.
//  Copyright © 2016年 cw. All rights reserved.
//

#import "CapturePhoteDelegate.h"
#import <AVFoundation/AVFoundation.h>

@implementation CapturePhoteDelegate
- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.backgroundColor = [UIColor redColor];
    [[UIApplication sharedApplication].keyWindow.rootViewController.view addSubview:view];
     view.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0];
    [UIView animateWithDuration:1 animations:^{
        view.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
    } completion:^(BOOL finished) {
        [view removeFromSuperview];
    } ];
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {

}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {

}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error {
    if (photoSampleBuffer != nil && error == nil) {
        self.photoData = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
    }else {
        self.filishedCaptureCallBackBlock(error);
        return;
    }

}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingRawPhotoSampleBuffer:(CMSampleBufferRef)rawSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error {
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error {
    if (error) {
        NSLog(@"Error capturing photo: %@", error);
        self.filishedCaptureCallBackBlock(error);
        return;
    }
    
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                [creationRequest addResourceWithType:PHAssetResourceTypePhoto data:self.photoData options:nil];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (!error) {
                    NSLog(@"保存成功");
                    self.filishedCaptureCallBackBlock(error);
                }else {
                    NSLog(@"保存失败 : %@", error);
                    self.filishedCaptureCallBackBlock(error);
                    return ;
                }
            }];
        }else { // 请求用户开启授权
            
            UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"请去授权" message:@"不授权无法用" preferredStyle:UIAlertControllerStyleAlert];
            [alertVC addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[UIApplication sharedApplication] openURL: [NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            }]];
            
            [alertVC addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                NSErrorDomain domain = @"用户取消了授权";
                NSError *error = [[NSError alloc] initWithDomain:domain code:0 userInfo:nil] ;
                

                self.filishedCaptureCallBackBlock(error);
            }]];
            
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertVC animated:NO completion:nil];
        }
    }];
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

@end
