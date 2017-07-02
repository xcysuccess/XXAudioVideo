//
//  H264HwDecoderImpl.h
//  XXAudioVideo
//
//  Created by tomxiang on 2017/6/30.
//  Copyright © 2017年 tomxiang. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface NALUnit: NSObject
@property(assign,nonatomic) unsigned int type;
@property(assign,nonatomic) unsigned int size;
@property(assign,nonatomic) unsigned char *data;
@end


typedef enum{
    NALUTypeBPFrame = 0x01,
    NALUTypeIFrame = 0x05,
    NALUTypeSPS = 0x07,
    NALUTypePPS = 0x08
}NALUType;

@protocol H264HwDecoderImplDelegate <NSObject>
- (void)displayDecodedFrame:(CVImageBufferRef )imageBuffer;
@end

@interface H264HwDecoderImpl : NSObject
@property (weak, nonatomic) id<H264HwDecoderImplDelegate> delegate;

- (instancetype) initWithConfiguration;

-(void)decodeNalu:(uint8_t *)data withSize:(uint32_t)dataLen;

@end
