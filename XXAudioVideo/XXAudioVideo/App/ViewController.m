//
//  ViewController.m
//  XXAudioVideo
//
//  Created by tomxiang on 2017/6/26.
//  Copyright © 2017年 tomxiang. All rights reserved.
//

#import "ViewController.h"
#import "XXCameraViewController.h"
#import "XXFileDecodeViewController.h"
#import "XXH265CameraViewController.h"
#import "XXFFmpegViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onPushCamera:(UIButton *)sender {
    
    XXCameraViewController *xxCameraVC = [[XXCameraViewController alloc] init];
    [self presentViewController:xxCameraVC animated:YES completion:^{
    }];
}
- (IBAction)onPushDecodeVC:(UIButton *)sender {
    XXFileDecodeViewController *xxFileVC = [[XXFileDecodeViewController alloc] init];
    [self presentViewController:xxFileVC animated:YES completion:^{
        
    }];
}
- (IBAction)onPushH265VC:(id)sender {
    XXH265CameraViewController *h265VC = [[XXH265CameraViewController alloc] init];
    [self presentViewController:h265VC animated:YES completion:^{
        
    }];
}
- (IBAction)onPushFFmpegVC:(UIButton *)sender {
    XXFFmpegViewController *ffmpegVC = [[XXFFmpegViewController alloc] init];
    [self presentViewController:ffmpegVC animated:YES completion:^{
        
    }];
}

@end
