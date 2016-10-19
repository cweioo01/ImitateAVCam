//
//  PreviewView.h
//  ImitateAVCam
//
//  Created by ChenWei on 16/10/18.
//  Copyright © 2016年 cw. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface PreviewView : UIView
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *videoPreviewView;
@property (strong, nonatomic) AVCaptureSession *session;
@end
