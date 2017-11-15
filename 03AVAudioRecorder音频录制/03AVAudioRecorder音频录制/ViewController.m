//
//  ViewController.m
//  03AVAudioRecorder音频录制
//
//  Created by 刘慧 on 2017/11/15.
//  Copyright © 2017年 fusheng@myzhenzhen.com. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface ViewController ()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>
@property(nonatomic,strong)AVAudioRecorder *recorder;
@property(nonatomic,strong)AVAudioPlayer *audioPlayer;
@end
@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
}
- (IBAction)btnAction:(UIButton *)sender {
    if (!sender.selected) {
        //开始录制
        //1.请求权限
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/test.wav"];
                    unlink([path UTF8String]);
                    if ([self.recorder prepareToRecord]) {
                        [self.recorder record];
                    }else{
                        NSLog(@"recorder prepareFail");
                    }
                });
            }else{
                NSLog(@"has no permission");
            }
        }];
    }else{
        //结束录制
        [self.recorder stop];
    }
    sender.selected = !sender.selected;
}

- (void)playeWithUrl:(NSURL*)url{
    _audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:nil];
    _audioPlayer.volume = 1;
    _audioPlayer.delegate = self;
    if ([_audioPlayer prepareToPlay]) {
        [_audioPlayer play];
    }else{
        NSLog(@"播放失败");
    }
}

#pragma mark   ---
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    [self playeWithUrl:recorder.url];
}
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"finish play");
}
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * __nullable)error{
    NSLog(@"play error");
}

#pragma mark  getter&&setter
- (AVAudioRecorder *)recorder{
    if (!_recorder) {
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/test.mp4"];
        unlink([path UTF8String]);
        //这些设置参数都可以在 AVAudioSettings.h 中找到
        NSMutableDictionary *settings = [NSMutableDictionary dictionary];
        //1.设置录制格式 wav
        [settings setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
        //2.采样率Hz: 8000/44100/96000 每秒从音频信号中提取并组成离散信号的采样个数
        [settings setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
        //3.音频通道设置 ： 1或者2
        [settings setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];
        //4.设置音频质量
        [settings setValue:[NSNumber numberWithInt:AVAudioQualityLow] forKey:AVEncoderAudioQualityKey];\
        _recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                settings:settings
                                                error:nil];
        _recorder.delegate = self;
    }
    return _recorder;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
