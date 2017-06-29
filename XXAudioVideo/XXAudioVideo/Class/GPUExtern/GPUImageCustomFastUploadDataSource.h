//
//  GPUImageCustomFastUploadDataSource.h
//  DJITrackingKit
//
//  Created by tomxiang on 20/10/2016.
//  Copyright © 2016年 DJI. All rights reserved.
//

#import "GPUImage.h"

typedef enum : NSUInteger {
    GPUImageCustomDataSourceRotation_None,
    GPUImageCustomDataSourceRotation_90CW,
    GPUImageCustomDataSourceRotation_180CW,
    GPUImageCustomDataSourceRotation_270CW,
} GPUImageCustomDataSourceRotation;

typedef enum : NSUInteger {
    GPUImageCustomDataSourceFlip_None,
    GPUImageCustomDataSourceFlip_Horizontal,
    GPUImageCustomDataSourceFlip_Vertical,
    GPUImageCustomDataSourceFlip_Both,
} GPUImageCustomDataSourceFlip;

/**
 *  data source for CMPicelBuffer input to gpu image system
 *  only support kCVPixelFormatType_32BGRA input now
 */

extern NSString *const kGPUImageCustomRGBAConversionPassthroughFragmentShaderString;

@interface GPUImageCustomFastUploadDataSource : GPUImageOutput

-(id) initWithColorFormat:(int)format;

/**
 *  rotate the output
 */
@property (nonatomic, assign) GPUImageCustomDataSourceRotation rotation;

/**
 *  flip will effect after rotate
 */
@property (nonatomic, assign) GPUImageCustomDataSourceFlip flip;

/**
 *  @param sampleBuffer and process sample buffer
 *  also can connect to a audio capture output
 */
-(void) uploadSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 *  sync complete current work in render queue
 *  will cause dead lock if call in render queue
 */
-(void) sync;

-(GPUImageCustomDataSourceRotation) getGPUImageRotation;

-(GPUImageCustomDataSourceFlip) getGPUImageRotationFrontCamera;
@end
