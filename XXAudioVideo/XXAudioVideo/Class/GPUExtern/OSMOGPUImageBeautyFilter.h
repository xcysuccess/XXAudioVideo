//
//  OSMOGPUImageBeautyFilter.h
//  Capture
//
//  Created by ShawnDu on 16/6/3.
//  Copyright © 2016年 ShawnDu. All rights reserved.
//
#import "GPUImage.h"

@class GPUImageCombinationFilter;

@interface OSMOGPUImageBeautyFilter : GPUImageFilterGroup {
    GPUImageBilateralFilter *bilateralFilter; //双边滤波模糊
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;//Canny边缘检测算法
    GPUImageHSBFilter *hsbFilter;//HSB颜色滤镜
    GPUImageCombinationFilter *combinationFilter;//滤镜的组合
    GPUImageBrightnessFilter *brightnessFilter;  //亮度
    GPUImageHighlightShadowFilter *highLightShadowFilter; //高光和暗部
    GPUImageSharpenFilter *sharpenFilter; //锐化
    GPUImageWhiteBalanceFilter *whiteBalanceFilter; //白平衡
    GPUImageContrastFilter *constrastFilter; //对比度
}

-(void) adjustHueValue:(CGFloat) value;

-(void) adjustSaturationValue:(CGFloat) value;

-(void) adjustBrightnessValue:(CGFloat) value;

-(void) adjustScreenBrightness:(CGFloat) value;

-(void) adjustHighlights:(CGFloat) value;

-(void) adjustShadows:(CGFloat) value;

-(void) adjustConstrastFilter:(CGFloat) value;

-(void) setStyle1;

-(void) setStyle2;

-(void) setStyle3;

@end
