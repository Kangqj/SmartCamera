//
//  ViewController.m
//  SmartCamera
//
//  Created by 康起军 on 15/10/23.
//  Copyright (c) 2015年 康起军. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "UIDevice+ExifOrientation.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "ShowImageViewController.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    BOOL isRunning;
    
    BOOL isSave;
}

@property (strong, nonatomic) UIImageView *cameraView;
@property (nonatomic, strong) CIDetector *faceDetector;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, readwrite) double lastSampleTimestamp;


@end

@implementation ViewController 

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.cameraView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.frame.size.width-300)/2, 340, 300, 300)];
    self.cameraView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.cameraView];
    
    [self initAVFoundation];
    
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace
                                           context:nil
                                           options:@{CIDetectorAccuracy : CIDetectorAccuracyLow}];
    
//    // 设置允许摇一摇功能
//    [UIApplication sharedApplication].applicationSupportsShakeToEdit = YES;
//    // 并让自己成为第一响应者
//    [self becomeFirstResponder];
    
}

- (void)initAVFoundation
{
    //负责输入和输出设备之间的数据传递
    self.session = [[AVCaptureSession alloc] init];
//    self.session.sessionPreset = AVCaptureSessionPreset3840x2160;
    
//    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];//取默认设备（后置摄像头摄像头）
    AVCaptureDevice *device = [self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];//取前置摄像头
    
    //负责从AVCaptureDevice获得输入数据
    NSError *error;
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if (self.input)
    {
        if ([self.session canAddInput:self.input])
        {
            [self.session addInput:self.input];
        }
    }
    else
    {
        NSLog(@"%@",error);
        return;
    }
    
    //负责从AVCaptureDevice获得输出的video数据
    AVCaptureVideoDataOutput *outPut = [[AVCaptureVideoDataOutput alloc] init];
    outPut.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCMPixelFormat_32BGRA) };
    // discard if the data output queue is blocked
    outPut.alwaysDiscardsLateVideoFrames = YES;
    // get the output for doing face detection.
    [[outPut connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    if ([self.session canAddOutput:outPut])
    {
        [self.session addOutput:outPut];
    }
    
    dispatch_queue_t queue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [outPut setSampleBufferDelegate:self queue:queue];
    
    //相机拍摄预览图层
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
//    previewLayer.frame = CGRectMake((self.view.frame.size.width-300)/2, 20, 300, 300);
    previewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    previewLayer.backgroundColor = [[UIColor lightGrayColor] CGColor];
//    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:previewLayer];
    
    [self.session startRunning];
    isRunning = YES;
}

-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position)
        {
            
            //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
            NSError *error;
            if ([camera lockForConfiguration:&error])
            {
                
                //设置自动闪光灯开启
                if ([camera isFlashModeSupported:AVCaptureFlashModeAuto])
                {
                    [camera setFlashMode:AVCaptureFlashModeAuto];
                }
                
                //设置自动聚焦
                if ([camera isFocusModeSupported:AVCaptureFocusModeAutoFocus])
                {
                    [camera setFocusMode:AVCaptureFocusModeAutoFocus];
                }
                //设置自动曝光
                if ([camera isExposureModeSupported:AVCaptureExposureModeAutoExpose])
                {
                    [camera setExposureMode:AVCaptureExposureModeAutoExpose];
                }
                
                [camera unlockForConfiguration];
            }else{
                NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
            }
            
            return camera;
        }
    }
    return nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.lastSampleTimestamp){
        self.lastSampleTimestamp = CACurrentMediaTime();
        
        return;
    }
    else{
        double now = CACurrentMediaTime();
        double timePassedSinceLastSample = now - self.lastSampleTimestamp;
        
        if (timePassedSinceLastSample < 0.5)
            return;
        self.lastSampleTimestamp = now;
    }
    
    // get the image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    if (attachments) {
        CFRelease(attachments);
    }
    
    ExifForOrientationType exifOrientation = [[UIDevice currentDevice] exifForCurrentOrientationWithFrontCamera:YES];
    
    NSDictionary *detectionOtions = @{ CIDetectorImageOrientation : @(exifOrientation),
                                       CIDetectorSmile : @YES,
                                       CIDetectorEyeBlink : @YES,
                                       CIDetectorAccuracy : CIDetectorAccuracyLow
                                       
                                       };
    
    NSArray *features = [self.faceDetector featuresInImage:ciImage
                                                   options:detectionOtions];
    NSLog(@"----------%d--------",features.count);
    
    if (isSave)
    {
        return;
    }
    
    for (CIFaceFeature *faceFeature in features){
        
        CGFloat faceWidth = faceFeature.bounds.size.width;
        
        // create a UIView using the bounds of the face
        UIView* faceView = [[UIView alloc] initWithFrame:faceFeature.bounds];
        
        // add a border around the newly created UIView
        
        faceView.layer.borderWidth = 1;
        faceView.layer.borderColor = [[UIColor redColor] CGColor];
        
        [self.view addSubview:faceView];
        
        if(faceFeature.hasLeftEyePosition)
            
        {
            // create a UIView with a size based on the width of the face
            
            UIView* leftEyeView = [[UIView alloc] initWithFrame:
                                   CGRectMake(faceFeature.leftEyePosition.x-faceWidth*0.15,
                                              faceFeature.leftEyePosition.y-faceWidth*0.15, faceWidth*0.3, faceWidth*0.3)];
            
            // change the background color of the eye view
            [leftEyeView setBackgroundColor:[[UIColor blueColor]
                                             colorWithAlphaComponent:0.3]];
            
            // set the position of the leftEyeView based on the face
            [leftEyeView setCenter:faceFeature.leftEyePosition];
            
            // round the corners
            leftEyeView.layer.cornerRadius = faceWidth*0.15;
            
            // add the view to the window
            [self.view  addSubview:leftEyeView];
            
        }
        
        if(faceFeature.hasRightEyePosition)
            
        {
            // create a UIView with a size based on the width of the face
            UIView* leftEye = [[UIView alloc] initWithFrame:
                               CGRectMake(faceFeature.rightEyePosition.x-faceWidth*0.15,
                                          faceFeature.rightEyePosition.y-faceWidth*0.15, faceWidth*0.3, faceWidth*0.3)];
            
            // change the background color of the eye view
            [leftEye setBackgroundColor:[[UIColor blueColor]
                                         colorWithAlphaComponent:0.3]];
            
            // set the position of the rightEyeView based on the face
            [leftEye setCenter:faceFeature.rightEyePosition];
            
            // round the corners
            leftEye.layer.cornerRadius = faceWidth*0.15;
            
            // add the new view to the window
            [self.view  addSubview:leftEye];
        }
        
        if(faceFeature.hasMouthPosition)
        {
            
            // create a UIView with a size based on the width of the face
            UIView* mouth = [[UIView alloc] initWithFrame:
                             CGRectMake(faceFeature.mouthPosition.x-faceWidth*0.2,
                                        faceFeature.mouthPosition.y-faceWidth*0.2, faceWidth*0.4, faceWidth*0.4)];
            
            // change the background color for the mouth to green
            [mouth setBackgroundColor:[[UIColor greenColor]
                                       colorWithAlphaComponent:0.3]];
            
            // set the position of the mouthView based on the face
            [mouth setCenter:faceFeature.mouthPosition];
            
            // round the corners
            mouth.layer.cornerRadius = faceWidth*0.2;
            
            // add the new view to the window
            [self.view  addSubview:mouth];
        }       
        
    }
    
    
    for ( CIFaceFeature *faceFeature in features)
    {
        if (faceFeature.hasSmile)
        {
            NSLog(@"----------笑了--------");
            [self showPhotoWith:sampleBuffer];
            isRunning = NO;
        }
        else if (faceFeature.leftEyeClosed)
        {
            NSLog(@"----------左眼眨眼--------");
            [self showPhotoWith:sampleBuffer];
        }
        else if (faceFeature.rightEyeClosed)
        {
            NSLog(@"----------右眼眨眼--------");
            [self showPhotoWith:sampleBuffer];
        }
    }
}

- (void)showPhotoWith:(CMSampleBufferRef)sampleBuffer
{
    return;
    
    UIImage *imaged = [self imageFromSampleBuffer:sampleBuffer];
    UIImage *image = [self image:imaged rotation:UIImageOrientationRight];
    
    CGRect rect = self.cameraView.frame;
    rect.size.width = image.size.width/5;
    rect.size.height = image.size.height/5;
    self.cameraView.frame = rect;
    
    isSave = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.cameraView.image = image;
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/photo.png"];
        [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
        AudioServicesPlaySystemSound(1108);
        [self.session stopRunning];
        
//        ShowImageViewController *vc = [[ShowImageViewController alloc] init];
//        vc.showImage = image;
//        [self presentViewController:vc animated:YES completion:NULL];
        
//        [self performSelector:@selector(saveFinish) withObject:nil afterDelay:1.0];
    });
    
//    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)saveFinish
{
    isSave = NO;
    [self.session startRunning];
}

- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    NSString *msg = nil ;
    if(error != NULL)
    {
        msg = @"保存图片失败" ;
        
    }else{
        msg = @"保存图片成功" ;
        
        self.cameraView.image = image;
        
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/photo.png"];
        [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
        
        AudioServicesPlaySystemSound(1108);
        
        [self.session stopRunning];
        
        isSave = YES;
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"保存图片结果提示"
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil];
    [alert show];
}

//来自：http://blog.sina.com.cn/s/blog_6dce99b10101bswg.html
// 通过抽样缓存数据创建一个UIImage对象
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return (image);
}

//图片旋转
- (UIImage *)image:(UIImage *)image rotation:(UIImageOrientation)orientation
{
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    switch (orientation) {
        case UIImageOrientationLeft:
            rotate = M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = 0;
            translateY = -rect.size.width;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationRight:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationDown:
            rotate = M_PI;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = -rect.size.width;
            translateY = -rect.size.height;
            break;
        default:
            rotate = 0.0;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = 0;
            translateY = 0;
            break;
    }

    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    //做CTM变换
    CGContextTranslateCTM(context, 0.0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextRotateCTM(context, rotate);
    CGContextTranslateCTM(context, translateX, translateY);
    
    CGContextScaleCTM(context, scaleX, scaleY);
    //绘制图片
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    
    return newPic;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.session.running)
    {
        [self.session stopRunning];
    }
    else
    {
        [self.session startRunning];
        
        self.cameraView.image = nil;
        
        isSave = NO;
    }
}

#pragma mark 切换摄像头
// 摇一摇开始摇动
- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    NSLog(@"开始摇动");
    return;
}

// 摇一摇取消摇动
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    NSLog(@"取消摇动");
    return;
}

// 摇一摇摇动结束
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (event.subtype == UIEventSubtypeMotionShake)
    {
        [self switchPosition];
        
        // 判断是否是摇动结束
        NSLog(@"摇动结束");
    }
    return;
}
- (void)switchPosition
{
    AVCaptureDevice *curDevice = self.input.device;
    AVCaptureDevicePosition curPosition = curDevice.position;
    
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    
    if (curPosition == AVCaptureDevicePositionFront || curPosition == AVCaptureDevicePositionUnspecified) {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    
    //获得需要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:toChangeDevice error:nil];
    
    //改变会话设置前一定先要开启配置，配置完成后提交配置改变
    [self.session beginConfiguration];
    //移除原有输入对象
    [self.session removeInput:self.input];
    
    if ([self.session canAddInput:toChangeDeviceInput])
    {
        [self.session addInput:toChangeDeviceInput];
        self.input = toChangeDeviceInput;
    }
    
    //提交会话配置
    [self.session commitConfiguration];
}

#pragma mark 切换摄像头

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
