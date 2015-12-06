//
//  ShowImageViewController.m
//  SmartCamera
//
//  Created by 康起军 on 15/11/30.
//  Copyright (c) 2015年 康起军. All rights reserved.
//

#import "ShowImageViewController.h"

@interface ShowImageViewController ()

@end

@implementation ShowImageViewController

@synthesize showImage;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIImageView *cameraView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    cameraView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:cameraView];
    cameraView.image = self.showImage;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self dismissViewControllerAnimated:YES completion:NULL];
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
