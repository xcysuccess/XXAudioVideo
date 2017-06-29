//
//  SSGPUImageBeautyFilter.m
//  Capture
//
//  Created by ShawnDu on 16/6/3.
//  Copyright © 2016年 ShawnDu. All rights reserved.
//  http://www.jianshu.com/p/945fc806a9b4

#import "OSMOGPUImageBeautyFilter.h"

@interface GPUImageCombinationFilter : GPUImageThreeInputFilter
{
    GLint smoothDegreeUniform;
}
@property (nonatomic, assign) CGFloat intensity;
@end

#pragma mark - shader
NSString *const kGPUImageBeautifyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 varying highp vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 uniform mediump float smoothDegree;
 
 void main()
 {
     highp vec4 bilateral = texture2D(inputImageTexture, textureCoordinate);
     highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);
     highp vec4 origin = texture2D(inputImageTexture3,textureCoordinate3);
     highp vec4 smooth;
     lowp float r = origin.r;
     lowp float g = origin.g;
     lowp float b = origin.b;
     if (canny.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > b && (max(max(r, g), b) - min(min(r, g), b)) > 0.0588 && abs(r-g) > 0.0588) {
         smooth = (1.0 - smoothDegree) * (origin - bilateral) + bilateral;
         
         smooth.r = log(1.0 + 0.2 * smooth.r)/log(1.2);
         smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
         smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
     }
     else {
         smooth = origin;
     }
//     smooth.r = log(1.0 + 0.2 * smooth.r)/log(1.2);
//     smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
//     smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
     gl_FragColor = smooth;
 }
 );

@implementation GPUImageCombinationFilter

- (id)init {
    if (self = [super initWithFragmentShaderFromString:kGPUImageBeautifyFragmentShaderString]) {
        smoothDegreeUniform = [filterProgram uniformIndex:@"smoothDegree"];
    }
    self.intensity = 0.62;
    return self;
}

- (void)setIntensity:(CGFloat)intensity {
    _intensity = intensity;
    [self setFloat:intensity forUniform:smoothDegreeUniform program:filterProgram];
}
@end

@interface OSMOGPUImageBeautyFilter()
@property (nonatomic, assign) CGFloat currentH;
@property (nonatomic, assign) CGFloat currentS;
@property (nonatomic, assign) CGFloat currentB;
@end

@implementation OSMOGPUImageBeautyFilter

- (id)init;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // 1.磨皮滤镜-双边滤波 GPU中自带
    bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    bilateralFilter.distanceNormalizationFactor = 6.4;
    [self addFilter:bilateralFilter];
    
    // 2.Canny边缘检测算法
    cannyEdgeFilter = [[GPUImageCannyEdgeDetectionFilter alloc] init];
    [self addFilter:cannyEdgeFilter];
    
    // 3.滤镜的组合: bilateral, edge detection and origin
    combinationFilter = [[GPUImageCombinationFilter alloc] init];
    [self addFilter:combinationFilter];
    
    [bilateralFilter addTarget:combinationFilter];
    [cannyEdgeFilter addTarget:combinationFilter];
    
    // 4.HSB颜色滤镜
    hsbFilter = [[GPUImageHSBFilter alloc] init];
    _currentH = 0.f;
    _currentS = 1.1;
    _currentB = 0.9f;
    
    [hsbFilter adjustBrightness:1.1f];
    [hsbFilter adjustSaturation:1.f];
    [combinationFilter addTarget:hsbFilter];
    
    // 5.增加一点美白效果
//    brightnessFilter = [[GPUImageBrightnessFilter alloc] init];
//    brightnessFilter.brightness = 0.08;
//    [hsbFilter addTarget:brightnessFilter];
    //6.锐化
    sharpenFilter = [[GPUImageSharpenFilter alloc] init];
    [hsbFilter addTarget:sharpenFilter];
    
    
    // 6.高光调节，暗部加深
    highLightShadowFilter = [[GPUImageHighlightShadowFilter alloc] init];
    highLightShadowFilter.highlights = 0.8f;
    highLightShadowFilter.shadows = 0.f;
    [sharpenFilter addTarget:highLightShadowFilter];
    
    // 7.白平衡
    whiteBalanceFilter = [[GPUImageWhiteBalanceFilter alloc] init];
    [highLightShadowFilter addTarget:whiteBalanceFilter];
    
    // 8.对比度
    constrastFilter = [[GPUImageContrastFilter alloc] init];
    [whiteBalanceFilter addTarget:constrastFilter];
    
    // terminalFilter为最终的filter，initialFilters为filter数组
    self.initialFilters = [NSArray arrayWithObjects:bilateralFilter,cannyEdgeFilter,combinationFilter,nil];
    self.terminalFilter = constrastFilter;
    
    return self;
}

-(void) setStyle1{
    [self adjustHueValue:0.5];
    [self adjustSaturationValue:0.4];
    [self adjustBrightnessValue:0.37];
    [self adjustScreenBrightness:0.5];
    [self adjustHighlights:0.0];
//    [self adjustShadows:0.48];
    [self adjustConstrastFilter:0.38];
}
-(void) setStyle2{
    [self adjustHueValue:0.53];
    [self adjustSaturationValue:0.52];
    [self adjustBrightnessValue:0.44];
    [self adjustScreenBrightness:0.59];
    [self adjustHighlights:0.46];
//    [self adjustShadows:0.49];
    [self adjustConstrastFilter:0.28];
}
-(void) setStyle3{
    [self adjustHueValue:0.7];
    [self adjustSaturationValue:0.50];
    [self adjustBrightnessValue:0.48];
    [self adjustScreenBrightness:0.51];
    [self adjustHighlights:0.05];
//    [self adjustShadows:0.48];
    [self adjustConstrastFilter:0.30];
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex
{
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters)
    {
        if (currentFilter != self.inputFilterToIgnoreForUpdates)
        {
            if (currentFilter == combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex
{
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters)
    {
        if (currentFilter == combinationFilter) {
            textureIndex = 2;
        }
        [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
    }
}

-(void) adjustHueValue:(CGFloat) value {
    NSLog(@"磨皮程度:%f",value);

    bilateralFilter.distanceNormalizationFactor = value * 8.0;

//    value = value * 360.f;
//    _currentH = value;
//    
//    NSLog(@"H:%f",value);
//
//    [hsbFilter rotateHue:value];
//    [self refreshHSB];
}

-(void) adjustSaturationValue:(CGFloat) value {
    value = value < 0 ? 0 : value;
    value = value > 1 ? 1 : value;
    value = value * 2.f;
    _currentS = value;

    NSLog(@"S:%f",value);
    [self refreshHSB];
}

-(void) adjustBrightnessValue:(CGFloat) value {
    value = value < 0 ? 0 : value;
    value = value > 1 ? 1 : value;
    value = value * 2.f;
    _currentB = value;

    NSLog(@"B:%f",_currentB);
    [self refreshHSB];
}

-(void) adjustScreenBrightness:(CGFloat) value{
    if(value == 0.5){
        value = 0;
    }else{
        if(value < 1){
            value = (value - 0.5) * 10;
        }else{
            value = 4.0f;
        }
    }
    NSLog(@"锐化的值:value:%f",value);
    sharpenFilter.sharpness = value;
}

-(void) refreshHSB{
    [hsbFilter reset];
    
    [hsbFilter rotateHue:_currentH];
    [hsbFilter adjustSaturation:_currentS];
    [hsbFilter adjustBrightness:_currentB];
}

-(void) adjustHighlights:(CGFloat) value{
    
    NSLog(@"adjustHighlights:%f",value);

    highLightShadowFilter.highlights = value;
}

-(void) adjustShadows:(CGFloat) value{
    
    NSLog(@"adjustShadows:%lf",floor(value*100) / 100 *10000);
    
    whiteBalanceFilter.temperature = floor(value*100) / 100 *10000;
    
//    highLightShadowFilter.shadows = value;
}
-(void) adjustConstrastFilter:(CGFloat) value{
    
    NSLog(@"contrast:%lf",value*4);
    
    constrastFilter.contrast = value * 4;
}

@end
