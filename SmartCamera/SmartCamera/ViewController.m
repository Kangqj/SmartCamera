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

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    BOOL isRunning;
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
    previewLayer.frame = CGRectMake((self.view.frame.size.width-300)/2, 20, 300, 300);
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
    NSLog(@"----------%ld--------",features.count);
    for ( CIFaceFeature *faceFeature in features)
    {
        if (faceFeature.hasSmile)
        {
            NSLog(@"----------笑了--------");
            [self showPhotoWith:ciImage];
            isRunning = NO;
        }
        if (faceFeature.leftEyeClosed)
        {
            NSLog(@"----------左眼眨眼--------");
            [self showPhotoWith:ciImage];
        }
        if (faceFeature.rightEyeClosed)
        {
            NSLog(@"----------右眼眨眼--------");
            [self showPhotoWith:ciImage];
        }
    }
    
}

- (void)showPhotoWith:(CIImage *)ciImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UIImage *faceImage = [UIImage imageWithCIImage:ciImage scale:1 orientation:UIImageOrientationLeftMirrored];
        
        CGRect rect = self.cameraView.frame;
        rect.size.width = faceImage.size.width/5;
        rect.size.height = faceImage.size.height/5;
        self.cameraView.frame = rect;
        
        UIImageWriteToSavedPhotosAlbum(faceImage, nil, nil, nil);
        
        self.cameraView.image = faceImage;
        
        AudioServicesPlaySystemSound(1108);
        
        [self.session stopRunning];
    });
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
