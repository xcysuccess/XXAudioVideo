//
//  XXCameraViewController.m
//  XXCamara
//
//  Created by tomxiang on 20/10/2016.
//  Copyright © 2016 tomxiang. All rights reserved.
//

#import "XXCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "OSMOBeautyMenuView.h"

#import "GPUImageCustomFastUploadDataSource.h"
#import "OSMOGPUImageBeautyFilter.h"
#import "Masonry.h"
#import "H264HwEncoderImpl.h"

@interface XXCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,H264HwEncoderImplDelegate,OSMOBeautyMenuViewDelegate>
{
    H264HwEncoderImpl *h264Encoder;
    AVCaptureVideoPreviewLayer *previewLayer;
    NSFileHandle *fileHandle;
    NSString *h264File;
    BOOL isStartedEncoded;
    
    AVCaptureConnection* connection;


}
//iOS原生device
@property (nonatomic,strong) AVCaptureDevice                      *videoDevice;
@property (nonatomic,strong) AVCaptureSession                     *captureSession;


@property (nonatomic,strong) GPUImageView                         *gpuImageView;

@property (nonatomic,strong) GPUImageCustomFastUploadDataSource   *dataSource;
@property (nonatomic,strong) OSMOGPUImageBeautyFilter             *beautyFilter;

@property (nonatomic,strong) OSMOBeautyMenuView                   *beautyMenuView;
@end

@implementation XXCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initViews];
    [self initData];
    [self startCaptureSession];
}
-(void)dealloc{
    [self.dataSource removeAllTargets];
}

- (void) enterBackground{
//    [self.dataSource sync];
}

- (void) initData{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

}

- (void) initViews{
//    self.gpuImageView = [[GPUImageView alloc] initWithFrame:CGRectZero];
//    [self.view addSubview:self.gpuImageView];
//    [_gpuImageView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.width.height.equalTo(self.view);
//    }];
    
    self.beautyMenuView = [[OSMOBeautyMenuView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.beautyMenuView];
    self.beautyMenuView.delegate = self;
    [_beautyMenuView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.bottom.equalTo(self.view);
        make.height.mas_equalTo(100);
    }];
}

- (AVCaptureDevice *)p_cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}

- (void) startCaptureSession {
    NSError *error = nil;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    self.videoDevice = [self p_cameraWithPosition:AVCaptureDevicePositionFront];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice
                                                                        error:&error];
    if (!input) {
        NSLog(@"PANIC: no media input");
    }
    [session addInput:input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:previewLayer];
    [self.view bringSubviewToFront:_beautyMenuView];
    
    [session beginConfiguration];
    session.sessionPreset = AVCaptureSessionPresetHigh;

    connection = [output connectionWithMediaType:AVMediaTypeVideo];
    [self setRelativeVideoOrientation];
    [session commitConfiguration];

    [session startRunning];

    self.captureSession = session;
}

- (void)stopCaptureSession{
    [_captureSession stopRunning];
    [previewLayer removeFromSuperlayer];
}

#pragma mark- disOutputSampleBuffer
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    if(!h264Encoder){
        h264Encoder = [[H264HwEncoderImpl alloc] initWithConfiguration:width height:height];
        h264Encoder.delegate = self;
    }
    if(isStartedEncoded == YES){
        [h264Encoder encode:sampleBuffer];
    }

//    [self p_renderVideoFrameToGPUImageViewFromSampleBuffer:sampleBuffer devicePosition:_videoDevice.position];
}

- (void) p_renderVideoFrameToGPUImageViewFromSampleBuffer:(CMSampleBufferRef)sampleBuffer devicePosition:(AVCaptureDevicePosition) devicePosition{
    [self p_setTargetsAndFilters];
    [self p_setDataSourceOritation:devicePosition];
    
    [self.dataSource uploadSampleBuffer:sampleBuffer];
}

#pragma mark- 美颜以及过滤器
-(void) p_setTargetsAndFilters{
    //切换的时候要清空filters
    if (!_dataSource) {
        _dataSource     = [[GPUImageCustomFastUploadDataSource alloc] init];
        _beautyFilter   = [[OSMOGPUImageBeautyFilter alloc] init];
        [_dataSource addTarget:_beautyFilter];
        [_beautyFilter addTarget:_gpuImageView];
    }
}

#pragma mark- Rotation
-(void) p_setDataSourceOritation:(AVCaptureDevicePosition) devicePosition
{
    self.dataSource.rotation = [self.dataSource getGPUImageRotation];
    
    if(devicePosition == AVCaptureDevicePositionFront){
        self.dataSource.flip = [self.dataSource getGPUImageRotationFrontCamera];
    }else{
        self.dataSource.flip = GPUImageCustomDataSourceFlip_None;
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -  H264HwEncoderImplDelegate delegare

- (void)getSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"getSpsPps %d %d", (int)[sps length], (int)[pps length]);

    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
    
}
- (void)getEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"getEncodedData %d", (int)[data length]);

    if (fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:ByteHeader];
        [fileHandle writeData:data];
    }
}

#pragma mark- H264HwEncoderImplDelegate
-(void) startEncodeButtonClick{
    NSLog(@"%s",__func__);
    isStartedEncoded = YES;
    
    // 获取系统当前时间
    NSDate * date = [NSDate date];
    NSTimeInterval sec = [date timeIntervalSinceNow];
    NSDate * currentDate = [[NSDate alloc] initWithTimeIntervalSinceNow:sec];
    
    //设置时间输出格式：
    NSDateFormatter * df = [[NSDateFormatter alloc] init ];
    [df setDateFormat:@"HH-mm-ss"];
    NSString * na = [df stringFromDate:currentDate];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    h264File = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h264",na]];
    [fileManager removeItemAtPath:h264File error:nil];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
    
    // Open the file using POSIX as this is anyway a test application
    //fd = open([h264File UTF8String], O_RDWR);
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
}

-(void) stopEncodeButtonClick{
    NSLog(@"%s",__func__);
    isStartedEncoded = NO;
    [h264Encoder stopEncoder];
    [fileHandle closeFile];
    fileHandle = NULL;
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}
@end
