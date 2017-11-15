//
//  ViewController.m
//  02AVCaptureSession实现实时录制
//
//  Created by 刘慧 on 2017/11/15.
//  Copyright © 2017年 fusheng@myzhenzhen.com. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>
@property(nonatomic,strong)AVPlayer *avPlayer;
@property(nonatomic,strong)AVCaptureSession *avSession;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self avSession];
}
- (IBAction)startRecode:(id)sender {
    UIButton *btn = sender;
    AVCaptureMovieFileOutput *output = self.avSession.outputs.firstObject;
    if (!btn.selected) {
        /*---开始录制------*/
        NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"output.mp4"];
        [output startRecordingToOutputFileURL:[NSURL fileURLWithPath:path] recordingDelegate:self];
    }else{
        /*---结束录制------*/
        [output stopRecording];
    }
    btn.selected = !btn.selected;
}

- (void)playeWithUrl:(NSURL*)url{
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
    [self.avPlayer replaceCurrentItemWithPlayerItem:item];
    [self.avPlayer play];
}

#pragma mark   ----AVCaptureFileOutputRecordingDelegate
//开始录制回调
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{}
//暂停录制回调
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didPauseRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{}
//恢复录制回调
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didResumeRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{}
//即将结束录制回调
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput willFinishRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections error:(NSError *)error{}
//已经结束录制回调
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    [self playeWithUrl:outputFileURL];
}


#pragma mark  getter&&setter
- (AVCaptureSession *)avSession{
    if (!_avSession) {
        //1.创建录制管理对象
        _avSession = [[AVCaptureSession alloc]init];
        //2.创建视频输入对象：这里有两种方法获取视频输入device，视频输入时带着摄像头方向
//        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        //3.创建音频输入对象
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
        //4.创建输出对象
        AVCaptureMovieFileOutput *output = [[AVCaptureMovieFileOutput alloc]init];
        //5.开始绑定设备
        [_avSession beginConfiguration]; //开始配置
        if ([_avSession canAddInput:videoInput]) {
            [_avSession addInput:videoInput];
        }else{
            NSLog(@"add videoInput fail");
        }
        if ([_avSession canAddInput:audioInput]) {
            [_avSession addInput:audioInput];
        }else{
            NSLog(@"add audioInput fail");
        }
        if ([_avSession canAddOutput:output]) {
            [_avSession addOutput:output];
        }else{
            NSLog(@"add output fail");
        }
        _avSession.sessionPreset = AVCaptureSessionPreset640x480;
        AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:_avSession];
        layer.frame = self.view.bounds;
        [self.view.layer insertSublayer:layer atIndex:0];
        [_avSession commitConfiguration];//结束配置
        //6.开始运行
        [_avSession startRunning];
    }
    return _avSession;
}
- (AVPlayer *)avPlayer{
    if (!_avPlayer) {
        _avPlayer = [[AVPlayer alloc] init];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];
        layer.frame = self.view.bounds;
        [self.view.layer addSublayer:layer];
    }
    return _avPlayer;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
