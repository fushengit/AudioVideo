//
//  ViewController.m
//  05视频硬解码码H264
//
//  Created by 刘慧 on 2017/11/21.
//  Copyright © 2017年 fusheng@myzhenzhen.com. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
{
    
    //刷新页面工具
    CADisplayLink *displayLink;
    //解码队列
    dispatch_queue_t decodeQueue;
    
    //读取数据工具
    NSInputStream *inputStream;
    //packet : 一个{0x00,0x00,0x00,0x001}的startcode + nalu
    //h264 是由多个packet组成
    uint8_t *packetBuffer;
    long packetSize;
    //h264码流的位置
    uint8_t *inputBuffer;
    //h264已经读取的大小，用来做偏移量的效果
    long inputSize;
}
@end

//因为不知道每一个packet的长度，我们得根据视频分辨率大小设置一个每次最大的读取量
const long inputMaxSize = 480*640*1.5;
//这个可以说是h264的分割符号startcode
const uint8_t startCode[4] = {0,0,0,1};

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    decodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"h264"];
    inputStream = [[NSInputStream alloc] initWithURL:[NSURL fileURLWithPath:path]];
    [inputStream open];
    
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(showFrame)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    displayLink.paused = true;
    displayLink.frameInterval  = 2;
    
    inputSize = 0;
    inputBuffer = malloc(inputMaxSize);
}


- (void)showFrame{
    dispatch_sync(decodeQueue, ^{
        //1.获取packetBuffer和packetSize;
        
        
        //2.判断帧类型
        
    });
}





- (void)dealloc{
    [inputStream close];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
