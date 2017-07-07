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
#import "VideoFileParser.h"

#import "Masonry.h"
#import "LASessionSize.h"
#import "H264HwEncoderImpl.h"
#import "H264HwDecoderImpl.h"
#import "AAPLEAGLLayer.h"

@interface XXCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,H264HwEncoderImplDelegate,H264HwDecoderImplDelegate,OSMOBeautyMenuViewDelegate>
{
    NSFileHandle *_fileHandle;
    NSString *_h264File;
    BOOL _isStartedEncoded;
    
    AVCaptureConnection  *_connection;
    AVCaptureDevice      *_videoDevice;
    AVCaptureSession     *_captureSession;
    OSMOBeautyMenuView   *_beautyMenuView;
    
    H264HwEncoderImpl *_h264Encoder;
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    H264HwDecoderImpl *_h264Decoder;
    AAPLEAGLLayer *_playLayer;
}
@end

@implementation XXCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initViews];
    [self initData];
    [self startCaptureSession];
}
-(void)dealloc{
}

- (void) enterBackground{
//    [self.dataSource sync];
}

- (void) initData{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    if(!_h264Encoder){
        _h264Encoder = [[H264HwEncoderImpl alloc] initWithConfiguration];
        _h264Encoder.delegate = self;
    }
    if (!_h264Decoder) {
        _h264Decoder = [[H264HwDecoderImpl alloc] initWithConfiguration];
        _h264Decoder.delegate = self;
    }

}

- (void) initViews{
    self.view.backgroundColor = [UIColor yellowColor];
    _beautyMenuView = [[OSMOBeautyMenuView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_beautyMenuView];
    _beautyMenuView.delegate = self;
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
    _videoDevice = [self p_cameraWithPosition:AVCaptureDevicePositionFront];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice
                                                                        error:&error];
    if (!input) {
        NSLog(@"PANIC: no media input");
    }
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [session addInput:input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [session addOutput:output];
    
    [session beginConfiguration];
    session.sessionPreset = AVCaptureSessionPresetiFrame1280x720;
    _connection = [output connectionWithMediaType:AVMediaTypeVideo];
    [self setRelativeVideoOrientation];
    [session commitConfiguration];
    [session startRunning];

    _captureSession = session;
    
    //view
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    _previewLayer.frame = CGRectMake(0, 120, 160, 300);
    _previewLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.view.layer addSublayer:_previewLayer];
    
    _playLayer = [[AAPLEAGLLayer alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 160, 120, 160, 300)];
    _playLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.view.layer addSublayer:_playLayer];
    
    [self.view bringSubviewToFront:_beautyMenuView];
}

- (void)stopCaptureSession{
    [_captureSession stopRunning];
    [_previewLayer removeFromSuperlayer];
    [_playLayer removeFromSuperlayer];
}

#pragma mark- disOutputSampleBuffer
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    [[LASessionSize sharedInstance] setWidth:(CGFloat)width height:(CGFloat)height];
    
    if(_isStartedEncoded == YES){
        [_h264Encoder encode:sampleBuffer];
    }
}

#pragma mark -  H264HwEncoderImplDelegate delegare

- (void)getSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"getSpsPps %d %d", (int)[sps length], (int)[pps length]);

    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [_fileHandle writeData:ByteHeader];
    [_fileHandle writeData:sps];
    [_fileHandle writeData:ByteHeader];
    [_fileHandle writeData:pps];

    //--h264 decode sps
    NSMutableData *h264Data = [[NSMutableData alloc] init];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:sps];
    [_h264Decoder decodeNalu:(uint8_t *)[h264Data bytes] withSize:(uint32_t)h264Data.length];

    //--h264 decode pps
    [h264Data resetBytesInRange:NSMakeRange(0, [h264Data length])];
    [h264Data setLength:0];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:pps];
    [_h264Decoder decodeNalu:(uint8_t *)[h264Data bytes] withSize:(uint32_t)h264Data.length];
}

- (void)getEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    if (_fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [_fileHandle writeData:ByteHeader];
        [_fileHandle writeData:data];
    
        //--h264 decode data
        NSMutableData *h264Data = [[NSMutableData alloc] init];
        [h264Data appendData:ByteHeader];
        [h264Data appendData:data];
        [_h264Decoder decodeNalu:(uint8_t *)[h264Data bytes] withSize:(uint32_t)h264Data.length];
    }
}

#pragma mark- H264HwEncoderImplDelegate
-(void) startEncodeButtonClick{
    NSLog(@"%s",__func__);
    
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
    
//    _h264File = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h264",na]];
    _h264File = [documentsDirectory stringByAppendingPathComponent:@"test_tomxiang.h264"];
    
    [fileManager removeItemAtPath:_h264File error:nil];
    [fileManager createFileAtPath:_h264File contents:nil attributes:nil];
    
    // Open the file using POSIX as this is anyway a test application
    //fd = open([h264File UTF8String], O_RDWR);
    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:_h264File];
    _isStartedEncoded = YES;
    
}

-(void) stopEncodeButtonClick{
    NSLog(@"%s",__func__);
    _isStartedEncoded = NO;
    [_h264Encoder stopEncoder];
    [_h264Decoder stopDecoder];
    [_fileHandle closeFile];
    _fileHandle = NULL;
}

- (void)closeVCClick{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}
- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            _connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            _connection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            _connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            _connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

#pragma mark -  H264解码回调  H264HwDecoderImplDelegate delegare
- (void)displayDecodedFrame:(CVImageBufferRef )imageBuffer
{
    if(imageBuffer)
    {
        _playLayer.pixelBuffer = imageBuffer;
        CVPixelBufferRelease(imageBuffer);
    }
}

@end
