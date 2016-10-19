//
//  PreviewView.m
//  ImitateAVCam
//
//  Created by ChenWei on 16/10/18.
//  Copyright © 2016年 cw. All rights reserved.
//

#import "PreviewView.h"


@implementation PreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (void)setSession:(AVCaptureSession *)session {
    self.videoPreviewView.session = session;
}

- (AVCaptureSession *)session {
    return _videoPreviewView.session;
}

- (AVCaptureVideoPreviewLayer *)videoPreviewView {
    if (_videoPreviewView == nil) {
        _videoPreviewView = (AVCaptureVideoPreviewLayer *)self.layer;
    }
    return _videoPreviewView;
}

@end
