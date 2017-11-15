//
//  ViewController.m
//  01UIImagePickerController实现视频录制
//
//  Created by 刘慧 on 2017/11/15.
//  Copyright © 2017年 fusheng@myzhenzhen.com. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
@interface ViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property(nonatomic,strong)UIImagePickerController *picker;
@property(nonatomic,strong)AVPlayer *avPlayer;
@property(nonatomic,strong)UIButton *controlBtn;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}
- (IBAction)startRecode:(id)sender {
    [self presentViewController:self.picker animated:true completion:nil];
}
- (void)controlRecoder:(UIButton*)btn{
    if (!btn.selected) {
        [self.picker startVideoCapture];
    }else{
        [self.picker stopVideoCapture];
    }
    btn.selected = !btn.selected;
}

- (void)playeWithUrl:(NSURL*)url{
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
    [self.avPlayer replaceCurrentItemWithPlayerItem:item];
    [self.avPlayer play];
}

#pragma mark  getter&&setter
-(UIImagePickerController *)picker{
    if (!_picker) {
        _picker = [[UIImagePickerController alloc] init];
        //设置视频来源是摄像头
        _picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        //设置摄像头方向,默认是UIImagePickerControllerCameraDeviceRear
        _picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        //设置摄像头类型：有拍照和录制视频两种。所以这个不适用于kUTTypeMovie 这种既有音频又有视频录制的效果
//        _picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
        //设置媒体类型
        _picker.mediaTypes = @[(NSString *)kUTTypeMovie];
        //设置视频质量:实际上就是设置视频的分辨率,默认为UIImagePickerControllerQualityTypeMedium
        _picker.videoQuality = UIImagePickerControllerQualityType640x480;
        //闪光灯效果: 关闭，自动，打开 只能在拍照的时候设置闪光效果，录制视频是没有效果的
        _picker.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        
        //设置是否显示系统的相机控制UI,默认是true，这个需要配合cameraOverlayView使用，用cameraOverlayView上面的控件来控制录制效果
        _picker.showsCameraControls = false;
        _picker.cameraOverlayView = self.controlBtn;
        _picker.delegate = self;
    }
    return _picker;
}
- (AVPlayer *)avPlayer{
    if (!_avPlayer) {
        _avPlayer = [[AVPlayer alloc] init];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];
        layer.frame = self.view.bounds;
        [self.view.layer insertSublayer:layer atIndex:0];
    }
    return _avPlayer;
}
- (UIButton *)controlBtn{
    if (!_controlBtn) {
        _controlBtn = [[UIButton alloc]init];
        [_controlBtn setTitle:@"开始录制" forState:UIControlStateNormal];
        [_controlBtn setTitle:@"结束录制" forState:UIControlStateSelected];
        [_controlBtn addTarget:self action:@selector(controlRecoder:) forControlEvents:UIControlEventTouchUpInside];
        [_controlBtn sizeToFit];
    }
    return _controlBtn;
}
#pragma mark  --UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    NSURL *url = info[UIImagePickerControllerMediaURL];
    [picker dismissViewControllerAnimated:true completion:^{
        [self playeWithUrl:url];
    }];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:true completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
