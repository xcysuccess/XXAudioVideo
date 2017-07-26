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
#import "LAScreenEx.h"


#define BASECELLIDENDIFIFY @"BASE_CELL_IDENDIFIFY"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property(nonatomic,strong) NSArray *listArray;
@property(nonatomic,strong) UITableView *baseTableView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:
                             @"H264实时编解码", @"H264文件解码", @"H265编解码", @"H264软编解码",nil];
    self.listArray = array;
    
}

-(void)loadView
{
    [super loadView];
    
    UITableView* tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    //    CZ_SetClearBackgroundColor(tableView);
    [tableView setBackgroundColor:[UIColor clearColor]];
    
    tableView.backgroundView = nil;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    _baseTableView = tableView;
    
    [_baseTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:BASECELLIDENDIFIFY];
    [self.view addSubview:_baseTableView];
}

#pragma mark- Delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _adapt_H(44);
}


- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return _adapt_H(20.f);;
}

- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == [tableView numberOfSections] - 1) {
        return _adapt_H(20);
    }  else {
        return _adapt_H(0.01);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.row) {
        case 0:{
                XXCameraViewController *xxCameraVC = [[XXCameraViewController alloc] init];
                [self presentViewController:xxCameraVC animated:YES completion:^{
                }];
            }
            break;
        case 1:{
            XXFileDecodeViewController *xxFileVC = [[XXFileDecodeViewController alloc] init];
            [self presentViewController:xxFileVC animated:YES completion:^{
                
            }];
        }
            break;
        case 2:{
            XXH265CameraViewController *h265VC = [[XXH265CameraViewController alloc] init];
            [self presentViewController:h265VC animated:YES completion:^{
                
            }];
        }
            break;
        case 3:{
            XXFFmpegViewController *ffmpegVC = [[XXFFmpegViewController alloc] init];
            [self presentViewController:ffmpegVC animated:YES completion:^{
                
            }];
        }
            break;
        default:
            break;
    }
    
}

#pragma mark- DataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;              // Default is 1 if not implemented
{
    return 1.f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.listArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = [indexPath row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BASECELLIDENDIFIFY forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:BASECELLIDENDIFIFY];
    }
    
    cell.textLabel.text = [self.listArray objectAtIndex:row];
    
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
