//
//  LASessionSize.m
//  XXAudioVideo
//
//  Created by tomxiang on 2017/7/2.
//  Copyright © 2017年 tomxiang. All rights reserved.
//

#import "LASessionSize.h"
#import "LAScreenEx.h"
@implementation LASessionSize

+ (instancetype)sharedInstance
{
    static LASessionSize *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [LASessionSize new];
    });
    return instance;
}


-(void) setWidth:(CGFloat) width height:(CGFloat) height{
    
    size_t widthReal = 0,heightReal = 0;
    if(ISPORTRAIT == true){
        widthReal = MIN(width, height);
        heightReal = MAX(width, height);
    }else{
        widthReal = MAX(width, height);
        heightReal = MIN(width, height);
    }
    _h264outputWidth = widthReal;
    _h264outputHeight = heightReal;
}
@end
