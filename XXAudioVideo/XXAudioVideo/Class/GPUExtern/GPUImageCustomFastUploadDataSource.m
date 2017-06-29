//
//  GPUImageCustomFastUploadDataSource.m
//  DJITrackingKit
//
//  Created by tomxiang on 20/10/2016.
//  Copyright © 2016年 DJI. All rights reserved.
//

#import "GPUImageCustomFastUploadDataSource.h"

NSString *const kGPUImageCustomRGBAConversionPassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
 );


@interface GPUImageCustomFastUploadDataSource (){
    dispatch_semaphore_t    frameRenderingSemaphore;
    GLProgram*              passThoughProgram;
    
    GLint                   passThoughProgramPositionAttribute;
    GLint                   passThoughTextureCoordinateAttribute;
    GLint                   inputTextureUniform;
    
    int                     imageBufferWidth, imageBufferHeight;
}
@end

@implementation GPUImageCustomFastUploadDataSource

-(id) init{
    return [self initWithColorFormat:kCVPixelFormatType_32BGRA];
}

-(id) initWithColorFormat:(int)format{
    if (self = [super init]) {
        
        NSString* shaderString = kGPUImageCustomRGBAConversionPassthroughFragmentShaderString;
        //kGPUImagePassthroughFragmentShaderString;
        //kGPUImageCustomRGBAConversionPassthroughFragmentShaderString;
        if (format == kCVPixelFormatType_32BGRA) {
        }else{
            //TODO: more support
            assert(0);
        }
        
        //semphore for drop frames
        frameRenderingSemaphore = dispatch_semaphore_create(1);
        
        runSynchronouslyOnVideoProcessingQueue(^{
            //create shaders
            
            [GPUImageContext useImageProcessingContext];
            passThoughProgram = [[GPUImageContext sharedImageProcessingContext]
                                 programForVertexShaderString:kGPUImageVertexShaderString
                                 fragmentShaderString:shaderString];
            
            if (!passThoughProgram.initialized)
            {
                [passThoughProgram addAttribute:@"position"];
                [passThoughProgram addAttribute:@"inputTextureCoordinate"];
                
                if (![passThoughProgram link])
                {
                    NSString *progLog = [passThoughProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [passThoughProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [passThoughProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    passThoughProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }
            
            passThoughProgramPositionAttribute = [passThoughProgram attributeIndex:@"position"];
            passThoughTextureCoordinateAttribute = [passThoughProgram attributeIndex:@"inputTextureCoordinate"];
            inputTextureUniform = [passThoughProgram uniformIndex:@"inputImageTexture"];
        });
    }
    return self;
}

-(void) uploadSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        //drop frames if not run fast enough
        return;
    }
    
    CFRetain(sampleBuffer);
    runAsynchronouslyOnVideoProcessingQueue(^{
        //Feature Detection Hook.
        
        [self processVideoSampleBuffer:sampleBuffer];
        
        CFRelease(sampleBuffer);
        dispatch_semaphore_signal(frameRenderingSemaphore);
    });
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth              = (int) CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight             = (int) CVPixelBufferGetHeight(cameraFrame);
    CMTime currentTime           = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    imageBufferWidth             = bufferWidth;
    imageBufferHeight            = bufferHeight;
    
    [GPUImageContext useImageProcessingContext];
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        //upload buffer
        CVOpenGLESTextureRef textureRef = NULL;
        CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_RGBA, bufferWidth, bufferHeight, GL_RGBA, GL_UNSIGNED_BYTE, 0, &textureRef);
        if (err)
        {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            assert(NO);
            return;
        }
        
        GLuint texture = CVOpenGLESTextureGetName(textureRef);
        
        //shaders for drawing
        [GPUImageContext setActiveShaderProgram:passThoughProgram];
        
        CGFloat rotatedImageBufferWidth = imageBufferWidth;
        CGFloat rotatedImageBufferHeight = imageBufferHeight;
        
        //rotation
        const GLfloat *texCood = [self getCGFloatTextureFromOutputWidth:&rotatedImageBufferWidth
                                                           OutputHeight:&rotatedImageBufferHeight
                                                               rotation:_rotation];
        
        
        // Construct frame buffer
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(rotatedImageBufferWidth, rotatedImageBufferHeight) textureOptions:self.outputTextureOptions onlyTexture:NO];
        [outputFramebuffer activateFramebuffer];
        
        const GLfloat* squareVertices = [self getVertexCordWithFlip:_flip];
        
        // Reset OpenGL workspace
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        // Setup OpenGL uniforms
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glUniform1i(inputTextureUniform, 4);
        
        // Setup OpenGL vertices
        glVertexAttribPointer(passThoughProgramPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
        glVertexAttribPointer(passThoughTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, texCood);
        
        
        // Setup OpenGL draw arrays
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        
        // notify targets
        [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:rotatedImageBufferWidth height:rotatedImageBufferHeight time:currentTime];
        
        CFRelease(textureRef);
    }
}

-(const GLfloat*) getCGFloatTextureFromOutputWidth:(CGFloat*) rotatedImageBufferWidth OutputHeight:(CGFloat*) rotatedImageBufferHeight rotation:(GPUImageCustomDataSourceRotation)rotation {

    static const GLfloat textureCoordinates90CW[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat textureCoordinates270CW[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat textureCoordinatesZero[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat textureCoordinates180CW[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    switch (rotation) {
        case GPUImageCustomDataSourceRotation_None:{
            *rotatedImageBufferWidth  = imageBufferWidth,
            *rotatedImageBufferHeight = imageBufferHeight;
            return textureCoordinatesZero;
        }
            break;
        case GPUImageCustomDataSourceRotation_90CW:{
            *rotatedImageBufferWidth  = imageBufferHeight,
            *rotatedImageBufferHeight = imageBufferWidth;
            return textureCoordinates90CW;
        }
            break;
        case GPUImageCustomDataSourceRotation_180CW:{
            *rotatedImageBufferWidth  = imageBufferWidth,
            *rotatedImageBufferHeight = imageBufferHeight;
            return textureCoordinates180CW;
        }
            break;
            
        case GPUImageCustomDataSourceRotation_270CW:{
            *rotatedImageBufferWidth  = imageBufferHeight,
            *rotatedImageBufferHeight = imageBufferWidth;
            return textureCoordinates270CW;
        }
            break;
        default:
            break;
    }

    *rotatedImageBufferWidth = imageBufferWidth;
    *rotatedImageBufferHeight = imageBufferHeight;
    return textureCoordinatesZero;
}

-(const GLfloat*) getVertexCordWithFlip:(GPUImageCustomDataSourceFlip)flip{
    
    static const GLfloat squareVertices_Normal[] = {
        -1.0f, -1.0f,
        +1.0f, -1.0f,
        -1.0f, +1.0f,
        +1.0f, +1.0f,
    };
    
    static const GLfloat squareVertices_FlipH[] = {
        +1.0f, -1.0f,
        -1.0f, -1.0f,
        +1.0f, +1.0f,
        -1.0f, +1.0f,
    };
    
    static const GLfloat squareVertices_FlipV[] = {
        -1.0f, +1.0f,
        +1.0f, +1.0f,
        -1.0f, -1.0f,
        +1.0f, -1.0f,
    };
    
    static const GLfloat squareVertices_FlipHV[] = {
        +1.0f, +1.0f,
        -1.0f, +1.0f,
        +1.0f, -1.0f,
        -1.0f, -1.0f,
    };
    
    switch (flip) {
        case GPUImageCustomDataSourceFlip_None:
            return squareVertices_Normal;
            break;
        case GPUImageCustomDataSourceFlip_Horizontal:
            return squareVertices_FlipH;
            break;
        case GPUImageCustomDataSourceFlip_Vertical:
            return squareVertices_FlipV;
            break;
        case GPUImageCustomDataSourceFlip_Both:
            return squareVertices_FlipHV;
            break;
        default:
            break;
    }
    
    return squareVertices_Normal;
}

- (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime;
{
    // First, update all the framebuffers in the targets
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject        = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];

            //[currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
            [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight)
                                atIndex:textureIndexOfTarget];
            
            [currentTarget setCurrentlyReceivingMonochromeInput:NO];
            
            [currentTarget setInputFramebuffer:outputFramebuffer
                                       atIndex:textureIndexOfTarget];
        }
    }
    
    // Then release our hold on the local framebuffer to send it back to the cache as soon as it's no longer needed
    [outputFramebuffer unlock];
    outputFramebuffer = nil;
    
    // Finally, trigger rendering as needed
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject        = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget newFrameReadyAtTime:currentTime
                                           atIndex:textureIndexOfTarget];
            }
        }
    }
}

-(void) sync{
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);
    
    runSynchronouslyOnVideoProcessingQueue(^{
        dispatch_semaphore_signal(wait);
    });
    
    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
}

-(GPUImageCustomDataSourceRotation) getGPUImageRotation{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if(orientation == UIInterfaceOrientationPortrait){
        return GPUImageCustomDataSourceRotation_90CW;
    }else if(orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return GPUImageCustomDataSourceRotation_270CW;
    }else if(orientation == UIInterfaceOrientationLandscapeRight) {
        return GPUImageCustomDataSourceRotation_None;
    } else {
        return GPUImageCustomDataSourceRotation_180CW;
    }
}

-(GPUImageCustomDataSourceFlip) getGPUImageRotationFrontCamera{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if(orientation == UIInterfaceOrientationPortrait){
        return GPUImageCustomDataSourceFlip_Horizontal;
    }else if(orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return GPUImageCustomDataSourceFlip_Horizontal;
    }else if(orientation == UIInterfaceOrientationLandscapeRight) {
        return GPUImageCustomDataSourceFlip_Vertical;
    } else {
        return GPUImageCustomDataSourceFlip_Vertical;
    }
}
@end
