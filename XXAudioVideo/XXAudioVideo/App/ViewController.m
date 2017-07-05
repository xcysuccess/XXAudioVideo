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

@end
