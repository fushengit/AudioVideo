//
//  ViewController.m
//  05视频硬解码码H264
//
//  Created by 刘慧 on 2017/11/21.
//  Copyright © 2017年 fusheng@myzhenzhen.com. All rights reserved.
//

#import "ViewController.h"
#import <VideoToolbox/VideoToolbox.h>
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
    //h264码流的位置（不是起始位置，每次读取完一个packet后移动到下一个packet）
    uint8_t *inputBuffer;
    //总共已经读取文件真实的大小
    long inputSize;
    //最大读取文件的大小
    long inputMaxSize;
    
    VTDecompressionSessionRef  decodeSession;
    CMFormatDescriptionRef formatDescriptionOut;
    uint8_t *sps;
    long spsSize;
    uint8_t *pps;
    long ppsSize;
}
@property (weak, nonatomic) IBOutlet UIButton *controlBtn;

@end

//这个可以说是h264的分割符号startcode
const uint8_t startCode[4] = {0,0,0,1};

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    decodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(showFrame)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    displayLink.paused = true;
    displayLink.frameInterval  = 2;
}

- (void)initDecodeSession{
    if (decodeSession) {
        return;
    }
    //1. 创建CMVideoFormatDescriptionRef
    const uint8_t *param[2] = {sps,pps};
    const size_t paramSize[2] = {spsSize,ppsSize};
    OSStatus formateStatus =
    CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL,
                                                        2,
                                                        param,
                                                        paramSize,
                                                        4,
                                                        &formatDescriptionOut);
    
    if (formateStatus!=noErr) {
        NSLog(@"FormatDescriptionCreate fail");
        return;
    }
    //2. 创建VTDecompressionSessionRef
    //确定编码格式
    const void *keys[] = {kCVPixelBufferPixelFormatTypeKey};
    
    uint32_t t = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    const void *values[] = {CFNumberCreate(NULL, kCFNumberSInt32Type, &t)};
    
    CFDictionaryRef att = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    
    VTDecompressionOutputCallbackRecord VTDecompressionOutputCallbackRecord;
    VTDecompressionOutputCallbackRecord.decompressionOutputCallback = decompressionOutputCallback;
    VTDecompressionOutputCallbackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    
    OSStatus sessionStatus =
    VTDecompressionSessionCreate(NULL,
                                 formatDescriptionOut,
                                 NULL,
                                 att,
                                 &VTDecompressionOutputCallbackRecord,
                                 &decodeSession);
    CFRelease(att);
    if (sessionStatus!=noErr) {
        NSLog(@"SessionCreate fail");
        [self endDecode];
    }
}


- (void)decode{
    if (!decodeSession) {
        return;
    }
    CVPixelBufferRef outputPixeBuffer = NULL;
    //1.创建CMBlockBufferRef
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus blockBufferStatus =
    CMBlockBufferCreateWithMemoryBlock(NULL,
                                       packetBuffer,
                                       packetSize,
                                       NULL,
                                       NULL,
                                       0,
                                       packetSize,
                                       0,
                                       &blockBuffer);
    if (blockBufferStatus!=noErr) {
        NSLog(@"BolkBufferCreate fail");
        return;
    }
    //2.创建CMSampleBufferRef
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {packetSize};
    OSStatus sampleBufferStatus =
    CMSampleBufferCreateReady(kCFAllocatorDefault,
                              blockBuffer,
                              formatDescriptionOut,
                              1, //sample 的数量
                              0, //sampleTimingArray 的长度
                              NULL, //sampleTimingArray 对每一个设置一些属性，这些我们并不需要
                              1, //sampleSizeArray 的长度
                              sampleSizeArray,
                              &sampleBuffer);
    
    if (blockBuffer) {
        free(blockBuffer);
        blockBuffer = NULL;
    }
    if (sampleBufferStatus!=noErr) {
        NSLog(@"SampleBufferCreate fail");
        return;
    }
    //3.编码生成
    OSStatus decodeStatus =
    VTDecompressionSessionDecodeFrame(decodeSession,
                                      sampleBuffer,
                                      kVTDecodeFrame_EnableAsynchronousDecompression,//the video decoder is compelled to emit every frame before it returns
                                      &outputPixeBuffer,
                                      NULL); //receive information about the decode operation
    if (sampleBuffer) {
        free(sampleBuffer);
        sampleBuffer =NULL;
    }
    if (decodeStatus!=noErr) {
        NSLog(@"DecodeFrame fail %d",(int)decodeStatus);
        return;
    }
}

void decompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
                                      void * CM_NULLABLE sourceFrameRefCon,
                                      OSStatus status,
                                      VTDecodeInfoFlags infoFlags,
                                      CM_NULLABLE CVImageBufferRef imageBuffer,
                                      CMTime presentationTimeStamp,
                                      CMTime presentationDuration ){
    if (imageBuffer) {
        CIImage *ciimage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        UIImage *image = [UIImage imageWithCIImage:ciimage];
        dispatch_async(dispatch_get_main_queue(), ^{
            ViewController *self = (__bridge ViewController *)(decompressionOutputRefCon);
            ((UIImageView*)self.view).image = image;
        });
    }
}

- (IBAction)startDecode:(UIButton *)sender {
    sender.hidden = true;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"h264"];
    inputStream = [[NSInputStream alloc] initWithFileAtPath:path];
    [inputStream open];
    
    inputSize = 0;
    inputMaxSize = [NSData dataWithContentsOfFile:path].length;
    
    if (inputBuffer) {
        free(inputBuffer);
        inputBuffer = NULL;
    }
    inputBuffer = malloc(inputMaxSize);
    
    displayLink.paused = false;
}
- (void)endDecode{
    self.controlBtn.hidden = false;
    displayLink.paused = true;
    [inputStream close];
}

- (void)showFrame{
    dispatch_sync(decodeQueue, ^{
        //1.获取packetBuffer和packetSize
        packetSize = 0;
        if (packetBuffer) {
            free(packetBuffer);
            packetBuffer = NULL;
        }
        if (inputSize < inputMaxSize && inputStream.hasBytesAvailable) { //一般情况下只会执行一次,使得inputMaxSize等于inputSize
            inputSize += [inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
        }
        if (memcmp(inputBuffer, startCode, 4) == 0) {
            if (inputSize > 4) { // 除了开始码还有内容
                uint8_t *pStart = inputBuffer + 4;
                uint8_t *pEnd = inputBuffer + inputSize;
                while (pStart != pEnd) { //这里使用一种简略的方式来获取这一帧的长度：通过查找下一个0x00000001来确定。
                    if(memcmp(pStart - 3, startCode, 4) == 0) {
                        packetSize = pStart - inputBuffer - 3;
                        if (packetBuffer) {
                            free(packetBuffer);
                            packetBuffer = NULL;
                        }
                        packetBuffer = malloc(packetSize);
                        memcpy(packetBuffer, inputBuffer, packetSize); //复制packet内容到新的缓冲区
                        memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize); //把缓冲区前移
                        inputSize -= packetSize;
                        break;
                    }
                    else {
                        ++pStart;
                    }
                }
            }
        }
        if (packetBuffer==NULL||packetSize==0) {
            [self endDecode];
            return;
        }
        
        //2.将packet的前4个字节换成大端的长度
        //大端：高字节保存在低地址
        //小端：高字节保存在高地址
        //大小端的转换实际上及时将字节顺序换一下即可
        uint32_t nalSize = (uint32_t)(packetSize - 4);
        uint8_t *pNalSize = (uint8_t*)(&nalSize);
        packetBuffer[0] = pNalSize[3];
        packetBuffer[1] = pNalSize[2];
        packetBuffer[2] = pNalSize[1];
        packetBuffer[3] = pNalSize[0];
        
        //3.判断帧类型（根据码流结构可知，startcode后面紧跟着就是码流的类型）
        int nalType = packetBuffer[4] & 0x1f;
        switch (nalType) {
            case 0x05:
                //IDR frame
                [self initDecodeSession];
                [self decode];
                break;
            case 0x07:
                //sps
                if (sps) {
                    free(sps);
                    sps = NULL;
                }
                spsSize = packetSize-4;
                sps = malloc(spsSize);
                memcpy(sps, packetBuffer+4, spsSize);
                break;
            case 0x08:
                //pps
                if (pps) {
                    free(pps);
                    pps = NULL;
                }
                ppsSize = packetSize-4;
                pps = malloc(ppsSize);
                memcpy(pps, packetBuffer+4, ppsSize);
                break;
            default:
                // B/P frame
                [self decode];
                break;
        }
    });

}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
