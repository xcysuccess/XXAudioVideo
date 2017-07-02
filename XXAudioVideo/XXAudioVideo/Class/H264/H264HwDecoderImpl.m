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
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = NULL;
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &_deocderSession);
        CFRelease(attrs);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
    }
    
    return YES;
}

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    H264HwDecoderImpl *decoder = (__bridge H264HwDecoderImpl *)decompressionOutputRefCon;
    if (decoder.delegate != nil)
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

-(void)decodeNalu:(uint8_t *)data withSize:(uint32_t)dataLen{
    int nalType = data[4] & 0x1F;
    
    NALUnit *nalUnit = nil;;
    nalUnit.data = data;
    nalUnit.size = dataLen;
    nalUnit.type = nalType;
    
    uint32_t nalSize = (uint32_t)(dataLen- 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    
    nalUnit.data[0] = *(pNalSize + 3);
    nalUnit.data[1] = *(pNalSize + 2);
    nalUnit.data[2] = *(pNalSize + 1);
    nalUnit.data[3] = *(pNalSize);
    
    
    CVPixelBufferRef pixelBuffer = NULL;
    //传输的时候。关键帧不能丢数据 否则绿屏   B/P可以丢  这样会卡顿
    switch (nalType){
        case NALUTypeSPS:{//0x07
            _spsSize = nalUnit.size - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, nalUnit.data + 4, _spsSize);
        }
            break;
        case NALUTypePPS:{//0x08
            _ppsSize = nalUnit.size - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, nalUnit.data + 4, _ppsSize);
        }
            break;
        case NALUTypeBPFrame:{//0x01
            NSLog(@"Nal type is B/P frame");
            pixelBuffer = [self decode:nalUnit];
        }
            break;
        case NALUTypeIFrame:{//0x05
            if([self initH264Decoder]) {
                pixelBuffer = [self decode:nalUnit];
            }
        }
            break;
    }
    
}

@end
