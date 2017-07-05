//
//  H264HwEncoderImpl.m
//  XXAudioVideo
//
//  Created by tomxiang on 2017/6/27.
//  Copyright © 2017年 tomxiang. All rights reserved.
//

#import "H264HwEncoderImpl.h"
#import "LAScreenEx.h"
#import "LASessionSize.h"

@import VideoToolbox;
@import AVFoundation;

@interface H264HwEncoderImpl()
{
    VTCompressionSessionRef EncodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef  format;
    CMSampleTimingInfo * timingInfo;
    NSData *sps;
    NSData *pps;
    
    int frameID;
}
@end

@implementation H264HwEncoderImpl

- (instancetype) initWithConfiguration
{
    if(self = [super init]){
        EncodingSession = nil;
        aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        frameID = 0;
        sps = NULL;
        pps = NULL;
        
        [self p_initVideoToolBox:[LASessionSize sharedInstance].h264outputWidth
                          height:[LASessionSize sharedInstance].h264outputHeight];
    }
    return self;
}



- (void) p_initVideoToolBox:(size_t)width  height:(size_t)height{

    dispatch_sync(aQueue, ^{
        //1.Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, (int32_t)width, (int32_t)height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &EncodingSession);
        if (status != 0){
            NSLog(@"H264: Unable to create a H264 session");
            return ;
        }
        
        //2.Set the properties
        // 设置实时编码输出（避免延迟）
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        // 设置关键帧（GOPsize)间隔
        int frameInterval = 10;
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);

        // 设置期望帧率
        int fps = 30;
        CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        //3.Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
    });
}
//http://km.oa.com/group/16071/articles/show/288149?kmref=search&from_page=2&no=5
//- (void) encode:(CMSampleBufferRef )sampleBuffer
//{
//    dispatch_sync(aQueue, ^{
//        frameID++;
//
//        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
//        // 帧时间，如果不设置会导致时间轴过长。
//        CMTime presentationTimeStamp = CMTimeMake(frameID, 1000);
//        VTEncodeInfoFlags flags;
//
//        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
//                                                              imageBuffer,
//                                                              presentationTimeStamp,
//                                                              kCMTimeInvalid,
//                                                              NULL, NULL, &flags);
//        if (statusCode != noErr) {
//            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
//            VTCompressionSessionInvalidate(EncodingSession);
//            CFRelease(EncodingSession);
//            EncodingSession = NULL;
//            return;
//        }
//        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
//    });
//}
- (void) encode:(CMSampleBufferRef )sampleBuffer
{
    if (EncodingSession==nil||EncodingSession==NULL)
    {
        return;
    }
    dispatch_sync(aQueue, ^{
        frameID++;
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime presentationTimeStamp = CMTimeMake(frameID, 1000);
        VTEncodeInfoFlags flags;
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        if (statusCode != noErr)
        {
            if (EncodingSession!=nil||EncodingSession!=NULL)
            {
                VTCompressionSessionInvalidate(EncodingSession);
                CFRelease(EncodingSession);
                EncodingSession = NULL;
                return;
            }
        }
    });
}

// 编码完成回调
void didCompressH264(void *outputCallbackRefCon,void *sourceFrameRefCon,OSStatus status,VTEncodeInfoFlags infoFlags,CMSampleBufferRef sampleBuffer){
    if (status != noErr) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264HwEncoderImpl* encoder = (__bridge H264HwEncoderImpl*)outputCallbackRefCon;

    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize,sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        
        if (statusCode == noErr) {
            
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            
            if(statusCode == noErr){
                // Found pps
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if(encoder.delegate){
                    [encoder->_delegate getSpsPps:encoder->sps pps:encoder->pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if(statusCodeRet == noErr){
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; //返回的NALU数据前四子节不是00 01的startcode，而是大端模式
        
        //循环获取NALU数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            //Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder.delegate getEncodedData:data isKeyFrame:keyframe];
            
            // Move to the nex NAL unit in the buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void) stopEncoder{
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(EncodingSession);
    CFRelease(EncodingSession);
    EncodingSession = NULL;
}

@end
