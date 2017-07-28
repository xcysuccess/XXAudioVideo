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

#import "XXFileDecodeView.h"
#import "Masonry.h"
#import "XXFFmpegManager.h"
#import "XXFFmpegManagerD.h"

@interface XXFFmpegViewController ()<XXFileDecodeViewDelegate>
{
    XXFileDecodeView   *_beautyMenuView;
    XXFFmpegManager    *_ffmpegManager;
    XXFFmpegManagerD   *_ffmpegManager2;
}
@end

@implementation XXFFmpegViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    av_register_all();
    
    [self initViews];
    [self initData];
}
-(void)dealloc{
}

- (void) initViews{
    self.view.backgroundColor = [UIColor yellowColor];
    _beautyMenuView = [[XXFileDecodeView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_beautyMenuView];
    _beautyMenuView.delegate = self;
    [_beautyMenuView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.bottom.equalTo(self.view);
        make.height.mas_equalTo(100);
    }];
}

- (void) initData{
    _ffmpegManager = [[XXFFmpegManager alloc] init];
    _ffmpegManager2 = [[XXFFmpegManagerD alloc] init];
}

#pragma mark- XXFileDecodeViewDelegate
- (void)startDecodeButtonClick{
    [_ffmpegManager yuvCodecToVideoH264];
}
- (void)stopDecodeButtonClick{
    
}
- (void)closeVCClick{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
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
