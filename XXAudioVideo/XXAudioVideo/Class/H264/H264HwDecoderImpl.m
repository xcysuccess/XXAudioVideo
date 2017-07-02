//
//  H264HwDecoderImpl.m
//  XXAudioVideo
//
//  Created by tomxiang on 2017/6/30.
//  Copyright © 2017年 tomxiang. All rights reserved.
//

#import "H264HwDecoderImpl.h"
#import "LAScreenEx.h"

@import VideoToolbox;
@import AVFoundation;

@implementation NALUnit

@end

@interface H264HwDecoderImpl()
{
    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;
    
    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
}
@end

@implementation H264HwDecoderImpl

- (instancetype) initWithConfiguration
{
    if(self = [super init]){
        _deocderSession = nil;
        _sps = NULL;
        _pps = NULL;
    }
    return self;
}

- (BOOL) initH264Decoder{
    if (_deocderSession) {
        return YES;
    }
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    if(status == noErr) {
        NSDictionary* destinationPixelBufferAttributes = @{
                                                           (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                                                           //硬解必须是 kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                                                           //                                                           或者是kCVPixelFormatType_420YpCbCr8Planar
                                                           //因为iOS是  nv12  其他是nv21
                                                           (id)kCVPixelBufferWidthKey : [NSNumber numberWithInt:600],
                                                           (id)kCVPixelBufferHeightKey : [NSNumber numberWithInt:800],
                                                           //这里款高和编码反的
                                                           (id)kCVPixelBufferOpenGLCompatibilityKey : [NSNumber numberWithBool:YES]
                                                           };
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL,
                                              (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                              &callBackRecord,
                                              &_deocderSession);
        
        VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
        VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
    }
    
    return YES;
}

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    H264HwDecoderImpl *decoder = (__bridge H264HwDecoderImpl *)decompressionOutputRefCon;
    if (decoder.delegate!=nil)
    {
        [decoder.delegate displayDecodedFrame:pixelBuffer];
    }
}

-(CVPixelBufferRef) decode:(NALUnit *) nalUnit{
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)nalUnit.data,
                                                          nalUnit.size,
                                                          kCFAllocatorNull,
                                                          NULL,
                                                          0,
                                                          nalUnit.size,
                                                          0,
                                                          &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {nalUnit.size};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1,
                                           0,
                                           NULL,
                                           1,
                                           sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
            }
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixelBuffer;
}

-(void) decodeNalu:(uint8_t *)frame withSize:(uint32_t)frameSize
{
    //    NSLog(@">>>>>>>>>>开始解码");
    int nalu_type = (frame[4] & 0x1F);
    CVPixelBufferRef pixelBuffer = NULL;
    uint32_t nalSize = (uint32_t)(frameSize - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    frame[0] = *(pNalSize + 3);
    frame[1] = *(pNalSize + 2);
    frame[2] = *(pNalSize + 1);
    frame[3] = *(pNalSize);
    //传输的时候。关键帧不能丢数据 否则绿屏   B/P可以丢  这样会卡顿
    switch (nalu_type)
    {
        case 0x05:
            //           NSLog(@"nalu_type:%d Nal type is IDR frame",nalu_type);  //关键帧
            if([self initH264Decoder])
            {
                pixelBuffer = [self decode:frame withSize:frameSize];
            }
            break;
        case 0x07:
            //           NSLog(@"nalu_type:%d Nal type is SPS",nalu_type);   //sps
            _spsSize = frameSize - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, &frame[4], _spsSize);
            break;
        case 0x08:
        {
            //            NSLog(@"nalu_type:%d Nal type is PPS",nalu_type);   //pps
            _ppsSize = frameSize - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, &frame[4], _ppsSize);
            break;
        }
        case 0x06: { // SEI
//            Supplemental enhancement information (SEI) and video usability information (VUI), which are extra information that can be inserted into the bitstream to enhance the use of the video for a wide variety of purposes.[clarification needed] SEI FPA (Frame Packing Arrangement) message that contains the 3D arrangement:
//                0: checkerboard: pixels are alternatively from L and R.1: column alternation: L and R are interlaced by column.2: row alternation: L and R are interlaced by row.3: side by side: L is on the left, R on the right.4: top bottom: L is on top, R on bottom.5: frame alternation: one view per frame.
            break;
        }
        default:
        {
            //            NSLog(@"Nal type is B/P frame");//其他帧
            if([self initH264Decoder])
            {
                pixelBuffer = [self decode:frame withSize:frameSize];
            }
            break;
        }
            
            
    }
}
-(CVPixelBufferRef)decode:(uint8_t *)frame withSize:(uint32_t)frameSize
{
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void *)frame,
                                                          frameSize,
                                                          kCFAllocatorNull,
                                                          NULL,
                                                          0,
                                                          frameSize,
                                                          FALSE,
                                                          &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {frameSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
            }
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixelBuffer;
}

//-(void)decodeNalu:(uint8_t *)data withSize:(uint32_t)dataLen{
//    int nalType = data[4] & 0x1F;
//
//    NALUnit *nalUnit = nil;;
//    nalUnit.data = data;
//    nalUnit.size = dataLen;
//    nalUnit.type = nalType;
//
//    uint32_t nalSize = (uint32_t)(dataLen- 4);
//    uint8_t *pNalSize = (uint8_t*)(&nalSize);
//
//    nalUnit.data[0] = *(pNalSize + 3);
//    nalUnit.data[1] = *(pNalSize + 2);
//    nalUnit.data[2] = *(pNalSize + 1);
//    nalUnit.data[3] = *(pNalSize);
//
//
//    CVPixelBufferRef pixelBuffer = NULL;
//    //传输的时候。关键帧不能丢数据 否则绿屏   B/P可以丢  这样会卡顿
//    switch (nalType){
//        case NALUTypeSPS:{//0x07
//            _spsSize = nalUnit.size - 4;
//            _sps = malloc(_spsSize);
//            memcpy(_sps, nalUnit.data + 4, _spsSize);
//        }
//            break;
//        case NALUTypePPS:{//0x08
//            _ppsSize = nalUnit.size - 4;
//            _pps = malloc(_ppsSize);
//            memcpy(_pps, nalUnit.data + 4, _ppsSize);
//        }
//            break;
//        case NALUTypeBPFrame:{//0x01
//            NSLog(@"Nal type is B/P frame");
//            pixelBuffer = [self decode:nalUnit];
//        }
//            break;
//        case NALUTypeIFrame:{//0x05
//            if([self initH264Decoder]) {
//                pixelBuffer = [self decode:nalUnit];
//            }
//        }
//            break;
//    }
//
//}

@end
