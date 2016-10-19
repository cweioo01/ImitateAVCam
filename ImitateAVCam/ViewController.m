//
//  ViewController.m
//  ImitateAVCam
//
//  Created by ChenWei on 16/10/18.
//  Copyright © 2016年 cw. All rights reserved.
//

#import "ViewController.h"
#import "PreviewView.h"
#import <AVFoundation/AVFoundation.h>
#import "CapturePhoteDelegate.h"
#import <Photos/Photos.h>
#import <Foundation/Foundation.h>

typedef enum{
    /** 有授权但session配置失败 */
    kSessionSetupResultConfigFailure,
    kSessionSetupResultSuccess,
    /** 用户没有授权 */
    kSessionSetupResultNotAuthorized
}SessionSetupResult;

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>

@property (weak, nonatomic) IBOutlet PreviewView *previewView;
@property (weak, nonatomic) IBOutlet UILabel *livePhoneModeLabel;
@property (weak, nonatomic) IBOutlet UILabel *liveLabel;
/** 模式切换: 拍照模式 摄像模式 */
@property (weak, nonatomic) IBOutlet UISegmentedControl *captureModeSegmentedController;
/** 录像 */
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
/** 拍照 */
@property (weak, nonatomic) IBOutlet UIButton *photoBtn;
/** 切换摄像头 */
@property (weak, nonatomic) IBOutlet UIButton *toggleCameraBtn;

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (strong, nonatomic) AVCapturePhotoOutput *photoOutput;
@property (strong, nonatomic) AVCaptureMovieFileOutput *moveFileOutput;
/** 授权状态 */
@property (assign, nonatomic) AVAuthorizationStatus authorizationStatus;
/** 异步,并发数为1 */
@property (strong, nonatomic) NSOperationQueue *sessionQueue;
/** session设置结果 */
@property (assign, nonatomic) SessionSetupResult sessionSetupResult;
/** liveMode */
@property (assign, nonatomic) BOOL isLiveMode;

@property (strong, nonatomic) CapturePhoteDelegate *capturePhoteDelegate;

@property (strong, nonatomic) NSURL *moveFileURL;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;
    
    // 0.按钮的初始化状态
    self.captureModeSegmentedController.enabled = NO;
    self.recordBtn.enabled = NO;
    self.photoBtn.enabled = NO;
    self.toggleCameraBtn.enabled = NO;
    
    // 1.
    self.previewView.session = self.session;
    
    // 2.检查用户的授权状态
    // 初始化为determined
   AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    self.authorizationStatus = status;
    
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            break;
            
        case AVAuthorizationStatusNotDetermined:
            // 请求允许
            
        {
            [self.sessionQueue setSuspended:YES];
            
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                NSLog(@"111 %@", [NSThread currentThread]);
                if (!granted) {
                    weakSelf.authorizationStatus = AVAuthorizationStatusDenied;
                }else {
                    weakSelf.authorizationStatus = AVAuthorizationStatusAuthorized;
                }
                
                 [self.sessionQueue setSuspended:NO];
            }];
            break;
        }
        default:
            self.authorizationStatus = AVAuthorizationStatusDenied;
            break;
    }
    
    
    
    // 3.配置session
    if (self.authorizationStatus == AVAuthorizationStatusAuthorized) {
        NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
             NSLog(@"222  %@", [NSThread currentThread]);
            [self configSession];
        }];
        [self.sessionQueue addOperation:op];
    }else self.sessionSetupResult = kSessionSetupResultNotAuthorized;
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 1.异步
    [self.sessionQueue addOperationWithBlock:^{
        switch (self.sessionSetupResult) {
            case kSessionSetupResultSuccess:
                [self.session startRunning];
                break;
                
            case kSessionSetupResultNotAuthorized:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"请去授权" message:@"不授权无法用" preferredStyle:UIAlertControllerStyleAlert];
                    [alertVC addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[UIApplication sharedApplication] openURL: [NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }]];
                    
                    [alertVC addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    }]];
                    
                    
                    
                    [self presentViewController:alertVC animated:NO completion:nil];
                });

            }
                break;
            case kSessionSetupResultConfigFailure:
                [self showConfigSessionErrorMessage];
                break;
            default:
                break;
        }
    }];
    
    // 2.设置UI
    [self.sessionQueue addOperationWithBlock:^{
        // session正在运行
        if (self.session.isRunning) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.captureModeSegmentedController.enabled = YES;
                self.photoBtn.enabled = YES;
                self.toggleCameraBtn.enabled = YES;
            });
        }
    }];
    
}

#pragma mark - toggle Capture Mode 
- (IBAction)toggleCaptureMode:(UISegmentedControl *)sender {
    // phote 模式
    if (sender.selectedSegmentIndex == 0) {
        self.recordBtn.enabled = NO;
        
        // 切换配置
        [self.sessionQueue addOperationWithBlock:^{
            [self.session beginConfiguration];
//            [self.session removeOutput:self.moveFileOutput];
            self.session.sessionPreset = AVCaptureSessionPresetPhoto;
            [self.session commitConfiguration];
            
//            self.moveFileOutput = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.livePhoneModeLabel.hidden = NO;
            });
        }];
    }else { // move 模式
        self.recordBtn.enabled = YES;
        self.livePhoneModeLabel.hidden = YES;
        
        [self.sessionQueue addOperationWithBlock:^{
            // 可以添加move模式
            if ([self.session.outputs containsObject:self.moveFileOutput]) {
                [self.session beginConfiguration];
                AVCaptureConnection *connection = [self.moveFileOutput connectionWithMediaType:AVMediaTypeVideo];
                if ([connection isVideoStabilizationSupported]) {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                }
                
                [self.session commitConfiguration];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.recordBtn.enabled = YES;
                });
                self.session.sessionPreset = AVCaptureSessionPresetHigh;
                return ;
            }
            if ([self.session canAddOutput:self.moveFileOutput]) {
                 [self.session beginConfiguration];
                [self.session addOutput:self.moveFileOutput];
                self.session.sessionPreset = AVCaptureSessionPresetHigh;
                
                AVCaptureConnection *connection = [self.moveFileOutput connectionWithMediaType:AVMediaTypeVideo];
                if ([connection isVideoStabilizationSupported]) {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                }
                
                [self.session commitConfiguration];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.recordBtn.enabled = YES;
                });
            }else { // 不能添加move模式
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showVerifyAlertViewWithTitle:@"失败失败" message:@"由于你设备或者其它未知的原因无法切换到摄像械"];
                });
            }
        }];
        
    }
}


#pragma mark - capturing photo
- (IBAction)capturePhoto:(UIButton *)sender {
    
    [self.sessionQueue addOperationWithBlock:^{
        // 当前不是photo模式
        if (![self.session.inputs containsObject:self.photoOutput]) {
            
        }
        
        // 请求授权
        if (!([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized)) {
            
            [self requestAuthored];
            
            // 用户不授权
            if (!([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized)) return;
        }
        
        // 设置方向
        AVCaptureConnection *connection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        
        // photoSetting: 闪光 \ 高分辨率支持 \ 从支持的预览格式数组中选一个预览格式 \
        // 设置路径(LIVE Phote保存用,普通模式不用设.)
        //
        AVCapturePhotoSettings *capturePhoteSetting = [AVCapturePhotoSettings photoSettings];
        capturePhoteSetting.flashMode = AVCaptureFlashModeAuto;
        capturePhoteSetting.highResolutionPhotoEnabled = YES;
        
        if (self.photoOutput.availablePhotoPixelFormatTypes.count > 0) {
            capturePhoteSetting.previewPhotoFormat = @{ (id)kCVPixelBufferPixelFormatTypeKey : self.photoOutput.availablePhotoPixelFormatTypes.firstObject};
        }
        
        //
        CapturePhoteDelegate *capturePhoteDelegate = [[CapturePhoteDelegate alloc] init];
        self.capturePhoteDelegate = capturePhoteDelegate;
        // 处理capture后的回调block
        __weak typeof(self) weakSelf = self;
        void (^filishbblock)(NSError *error)  = ^(NSError *error){
            if (error) {
                NSLog(@"filisbakc,, %@", error.userInfo);
                weakSelf.capturePhoteDelegate = nil;
            }
            
        };
        
        capturePhoteDelegate.filishedCaptureCallBackBlock = filishbblock;
        
        self.capturePhoteDelegate.capturePhotoSetting = capturePhoteSetting;
        [self.photoOutput capturePhotoWithSettings:capturePhoteSetting delegate: capturePhoteDelegate];
    }];

 
    
    
}

#pragma mark - recored move
- (IBAction)recoreMoveFile:(UIButton *)sender {
    
    if (self.moveFileOutput == nil)  return;
    
    // 1.禁止切换模式的点击
    self.toggleCameraBtn.enabled = NO;
    self.captureModeSegmentedController.enabled = NO;
    self.recordBtn.enabled = NO;
    
    [self.sessionQueue addOperationWithBlock:^{
        NSString *fileName = [NSUUID UUID].UUIDString;
        NSString *filePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@".mov"];
        if (!(self.moveFileOutput.isRecording == YES)) {
            [_moveFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:filePath] recordingDelegate:self];
        }else [_moveFileOutput stopRecording];
    }];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
//    self.moveFileURL = fileURL;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordBtn.enabled = YES;
        [self.recordBtn setTitle:@"停止记录" forState:UIControlStateNormal];
    });

}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    BOOL success = YES;
    if (error != nil) { // move 记录结束
        // 保存move
        success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
    }
    
    if (success) {
        // 查看授权,然后保存文件
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
               // 可以保存
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetCreationRequest *createRequest = [PHAssetCreationRequest creationRequestForAsset];
                    
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    [createRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:outputFileURL options:options];
                    
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    if (!success) {
                        NSLog(@" 保存move 失败 %@:", error);
                    }else { // 保存成功,清除temp中临时文件
                        [[NSFileManager defaultManager] removeItemAtPath:outputFileURL.path error:nil];
                        NSLog(@" 保存move 成功");
                    }
                }];
                
            }else {
                
            }
        }];
    }
    
    self.recordBtn.enabled = YES;
    [self.recordBtn setTitle:@"开始记录" forState:UIControlStateNormal];
}

#pragma mark - session
- (NSOperationQueue *)sessionQueue {
    if (_sessionQueue == nil) {
        _sessionQueue = [[NSOperationQueue alloc] init];
        _sessionQueue.maxConcurrentOperationCount = 1;
    }
    return _sessionQueue;
}
- (AVCaptureSession *)session{
    if (_session == nil) {
        _session = [[AVCaptureSession alloc] init];
    }
    return _session;
}
- (AVCapturePhotoOutput *)photoOutput {
    if (_photoOutput == nil) {
        _photoOutput = [[AVCapturePhotoOutput alloc] init];
    }
    return _photoOutput;
}
- (AVCaptureMovieFileOutput *)moveFileOutput {
    if (_moveFileOutput == nil) {
        _moveFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    }
    return _moveFileOutput;
}

- (void)configSession {
    
    [self.session beginConfiguration];
    
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    // 1.添加videoDeviceInput
    // 只能返回Returns the default device used to capture data of a given media type. 要返回其它得用另一个方法.
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    if (captureDevice == nil) {
        captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    }
    
    if (captureDevice == nil) {
        captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (error || videoDeviceInput == nil) {
        NSLog(@"创建input失败 : %@", error);
        self.sessionSetupResult = kSessionSetupResultConfigFailure;
        [self.session commitConfiguration];
        return;
    }else {
        if ([self.session canAddInput:videoDeviceInput]) {
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
        }else {
            NSLog(@"add input failure : %@", error);
            self.sessionSetupResult = kSessionSetupResultConfigFailure;
            [self.session commitConfiguration];
            return;
        }
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        self.previewView.videoPreviewView.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }];
    
    // 2.添加audioInput
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    NSError *audioError = nil;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&audioError];
    
    if (audioError || audioInput == nil) {
        NSLog(@"creat audoInput error : %@", audioError);
    }else {
        if ([self.session canAddInput:audioInput]) {
            [self.session addInput:audioInput];
        }else {
            NSLog(@"can't add audioInput");

        }
    }
    
    
    // 3.add output
    if ([self.session canAddOutput:self.photoOutput]) {
        [self.session addOutput:self.photoOutput];
        self.photoOutput.highResolutionCaptureEnabled = YES;
        self.photoOutput.livePhotoCaptureEnabled = self.photoOutput.livePhotoCaptureSupported;
        self.isLiveMode = self.photoOutput.isLivePhotoCaptureSupported ? YES : NO;
        
    }else {
        NSLog(@"can't add photoOutput");
        self.sessionSetupResult = kSessionSetupResultConfigFailure;
        [self.session commitConfiguration];
        return;
    }
    
    
    self.sessionSetupResult = kSessionSetupResultSuccess;
    
    [self.session commitConfiguration];
}

/** 请求授权 */
- (void)requestAuthored {
    NSLog(@"requestAuthored = %@", [NSThread currentThread]);
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"请去授权" message:@"不授权无法用" preferredStyle:UIAlertControllerStyleAlert];
        [alertVC addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL: [NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
        }]];
        
        [alertVC addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
    
        [self presentViewController:alertVC animated:NO completion:nil];
}

/** sesson 配置失败信息 */
- (void)showConfigSessionErrorMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"录制失败" message:@"未知原因无法打开摄像设备,请检查设备" preferredStyle:UIAlertControllerStyleAlert];
        [alertVc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:alertVc animated:NO completion:nil];
    });
}

#pragma makr - 内部方法
/** 弹框显示确认信息 */
- (void)showVerifyAlertViewWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [vc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:vc animated:YES completion:nil];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

}
@end
