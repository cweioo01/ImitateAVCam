
# 系统自带的,可以在没有window里弹出,可以可直接决定授权状态,不用进设置界面.
[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
 if (!granted) {
 weakSelf.authorizationStatus = kAuthorizationStatusDetermined;
 }else {
 weakSelf.authorizationStatus = kAuthorizationStatusDenied;
 }
 }];

# operateion

* NSBlockOperation 添加的第一个block在主线程执行,后加加的block在异步线程执行.
    * 要手动启动
 ```objc
NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
NSLog(@"%@", [NSThread currentThread]);
}];

[op addExecutionBlock:^{
NSLog(@"===%@", [NSThread currentThread]);

}];
[op start];
```
# NSOperationQueue 与主线程和其它线程异步执行.(当maxCurrentcount = 1时,添加的block是串行的)

```ojbc
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
[queue addOperationWithBlock:^{
NSLog(@"queue111===%@", [NSThread currentThread]);
}];

[queue addOperationWithBlock:^{
NSLog(@"queue222===%@", [NSThread currentThread]);
}];
```

# 不能显示摄像头照到的:等同于没有开启摄像功能
* 1.没有previewLayer :
    * 下面的方法默认值为nil.最好写上懒加载的方法(getter方法).不然导致为nil.无videoLayer,layer也无session,所以没有图像.
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *videoPreviewView;

# 无法拍照
* 2. AVCapturePhotoCaptureDelegate这个代理对象在captureing形如时销毁了. (没有capture摄像头拍到的图片)
    * 原因:这个代理我不是用的控制器,是自己写的一个对象A实现了代理方法,但是对A没有强引用,导致开始执行capturing,A就销毁了.


# 点击按钮当获取到用户不授权后要return ,不要再继续往下执行. 能授权才执行相当capture代码.


# 输出模式并存
* 可以多种输出模式并存(比如photoOutput 和moveOutput,),但是在拍照和录像时要切换到对应的sessionPreset


# 切换摄像头(前置和后置)
* 有新输入可切换
    * 选择对应的,(从可发现的设备中选优先方向和mediaType支持的设置,不行再其次)
        * 能否加入sessioon
            *  能 : 根据新输入设备修改相应的output参照.
            * 不能:维持原来的
    * 找不到对应,条件放松到只是前后换下也没有:维持原来的
* 没有可换的:维持原来的

# NSUUID 
* 创建唯一字串符,用作路径用.

# 写入图片到相册步骤
```objc
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
```
# move 写入相册
*　先入在临时ｔｅｍｐ中，
＊　写入
＊删除临时temp中的
```objc
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
```







