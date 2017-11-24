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
    CMVideoFormatDescriptionRef videoFormatDescription;
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
                                                        &videoFormatDescription);
    if (formateStatus!=noErr) {
        NSLog(@"FormatDescriptionCreate fail");
        return;
    }
    //2. 创建VTDecompressionSessionRef
    //确定编码格式
    const void *keys[] = {kCVPixelBufferPixelFormatTypeKey};
    
    uint32_t t = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    CFNumberRef type = CFNumberCreate(NULL, kCFNumberSInt32Type, &t);
    const void *values[] = {type};
    
    CFDictionaryRef att = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    
    VTDecompressionOutputCallbackRecord VTDecompressionOutputCallbackRecord;
    VTDecompressionOutputCallbackRecord.decompressionOutputCallback = decompressionOutputCallback;
    VTDecompressionOutputCallbackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    
    OSStatus sessionStatus =
    VTDecompressionSessionCreate(NULL,
                                 videoFormatDescription,
                                 NULL,
                                 att,
                                 &VTDecompressionOutputCallbackRecord,
                                 &decodeSession);
    if (sessionStatus!=noErr) {
        NSLog(@"SessionCreate fail");
        [self endDecode];
    }
}
- (CVPixelBufferRef)decode{
    CVPixelBufferRef outputPixeBuffer = NULL;
    if (!decodeSession) {
        return NULL;
    }
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
        return NULL;
    }
    //2.创建CMSampleBufferRef
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {packetSize};
    OSStatus sampleBufferStatus =
    CMSampleBufferCreateReady(NULL,
                              blockBuffer,
                              videoFormatDescription,
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
        return NULL;
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
        sampleBuffer = NULL;
    }
    if (decodeStatus!=noErr) {
        NSLog(@"DecodeFrame fail %d",decodeStatus);
        return NULL;
    }
    return outputPixeBuffer;
}

void decompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
                                      void * CM_NULLABLE sourceFrameRefCon,
                                      OSStatus status,
                                      VTDecodeInfoFlags infoFlags,
                                      CM_NULLABLE CVImageBufferRef imageBuffer,
                                      CMTime presentationTimeStamp,
                                      CMTime presentationDuration ){
    
    
    
}

- (IBAction)startDecode:(UIButton *)sender {
    sender.hidden = true;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"abc" ofType:@"h264"];
    inputStream = [[NSInputStream alloc] initWithURL:[NSURL fileURLWithPath:path]];
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
        
        if (inputSize < inputMaxSize && inputStream.hasBytesAvailable) {
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
        
        
        
//        long thisTimeInput = 0;
//        if (inputSize<inputMaxSize&&inputStream.hasBytesAvailable) {
//            thisTimeInput = [inputStream read:inputBuffer maxLength:inputMaxSize-inputSize];
//        }
//        if (memcmp(inputBuffer, startCode, 4)==0 && thisTimeInput>4) {
//            uint8_t *pStart = inputBuffer+4;
//            uint8_t *pEnd = inputBuffer+thisTimeInput;
//            while (pStart!=pEnd) {
//                if (memcmp(pStart-3, startCode, 4)==0) {
//                    packetSize = pStart -3 -inputBuffer;
//                    packetBuffer = malloc(packetSize);
//                    memcpy(packetBuffer, inputBuffer, packetSize);
//                    inputSize += packetSize;
//                    memmove(inputBuffer, inputBuffer+packetSize, inputMaxSize-inputSize);
//                    break;
//                }else{
//                    ++pStart;
//                }
//            }
//        }
        
        
        //2.判断帧类型（根据码流结构可知，startcode后面紧跟着就是码流的类型）
        if (packetBuffer==NULL||packetSize==0) {
            [self endDecode];
            return;
        }
        uint32_t nalSize = (uint32_t)(packetSize - 4);
        uint32_t *pNalSize = (uint32_t *)packetBuffer;
        *pNalSize = CFSwapInt32HostToBig(nalSize);
        
        CVPixelBufferRef pixelBuffer = NULL;
        switch (packetBuffer[4]&0x1f) {
            case 0x05:
                //IDR frame
                [self initDecodeSession];
                pixelBuffer = [self decode];
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
                pixelBuffer = [self decode];
                break;
        }
        //3.展示
        if (pixelBuffer) {
            CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            UIImage *image = [UIImage imageWithCIImage:ciimage];
            dispatch_async(dispatch_get_main_queue(), ^{
                ((UIImageView*)self.view).image = image;
            });
        }
    });
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
