//
//  XXFFmpegViewController.m
//  XXAudioVideo
//
//  Created by tomxiang on 2017/7/19.
//  Copyright © 2017年 tomxiang. All rights reserved.
//

#import "XXFFmpegViewController.h"
#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavutil/opt.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
    
#ifdef __cplusplus
};
#endif
@interface XXFFmpegViewController ()

@end

@implementation XXFFmpegViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    av_register_all();
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
