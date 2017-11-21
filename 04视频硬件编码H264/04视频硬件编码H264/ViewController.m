//
//  ViewController.m
//  04视频硬件编码H264
//
//  Created by 刘慧 on 2017/11/16.
//  Copyright © 2017年 fusheng@myzhenzhen.com. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CVPixelBuffer.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_queue_t outputQueue;
    dispatch_queue_t encodeQueue;
    VTCompressionSessionRef encodeSession;
    int64_t frameCount;
    BOOL isEncoding;
    NSFileHandle * fileHandle;
}
@property (weak, nonatomic) IBOutlet UIButton *controBtn;
@property(nonatomic,strong)UIImageView *playerView;
@property(nonatomic,strong)AVCaptureSession *avSession;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view insertSubview:self.playerView atIndex:0];
    outputQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self.avSession startRunning];
}

- (void)initEncodeSession{
    frameCount = 0;
    int32_t width = 480;//编码后视频分辨率的宽
    int32_t height = 640; //编码后视频分辨率的高
    OSStatus sessionStatus =
    VTCompressionSessionCreate(NULL,//函数标记，NULL表示default
                               width,
                               height,
                               kCMVideoCodecType_H264,//编码格式h264
                               NULL,//需要具体说明一个特殊的recoder的时候使用，NULL表示让系统选择一个合适的
                               NULL,//
                               NULL,//函数标记，NULL表示default
                               compressionOutputCallback, //编码后的回调
                               (__bridge void * _Nullable)(self), //编码后回调的对象
                               &encodeSession);
    if (sessionStatus!=0) {
        NSLog(@"fail create encodeSession");
        return;
    }
    
    /*视频编码需要设定一下参数:相关参数都可以在VTCompressionSessionPropertys.h中找到*/
    /*
     码率: 单位时间(s)的采样率
     * 我们设置的视频格式是： kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
     * 注释如下:   Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range (luma=[0,255] chroma=[1,255]).  baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct
     * YUV420采样规则：每个像素都采集Y，奇数行采集U,偶数行采集V  总采集数：W*H + W*H/2 = 1.5W*H ,所以单像素占1.5byte
     * YUV422采样规则：每两个像素为一组，采集两个Y，一个U，一个V。 总采集数：W*H*2 ,所以单像素占2byte
     * 码率设置是配套的，kVTCompressionPropertyKey_DataRateLimits和kVTCompressionPropertyKey_AverageBitRate需要同时设置，如果不设置就采用的是默认的，The default bit rate is zero
     */
    //1.最大码率设置 单位：byte
    //kVTCompressionPropertyKey_DataRateLimits API_AVAILABLE(macosx(10.8), ios(8.0), tvos(10.2)); // Read/write, CFArray[CFNumber], [bytes, seconds, bytes, seconds...], Optional
    int dataRateLimits = width*height*1.5;
    NSArray *limits = @[@(dataRateLimits),@(1)];
    OSStatus dataRateStatus =
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_DataRateLimits,
                         (__bridge CFTypeRef _Nonnull)(limits));
    if (dataRateStatus!=noErr) {
        NSLog(@"fail set DataRateLimits");
    }
    //2.设置平均码率 单位：bps   1bps=1bit每秒
    //kVTCompressionPropertyKey_AverageBitRate API_AVAILABLE(macosx(10.8), ios(8.0), tvos(10.2)); // Read/write, CFNumber<SInt32>, Optional
    int bitRate = width*height*1.5*8;
    CFNumberRef biteRate = CFNumberCreate(NULL,
                                          kCFNumberFloat32Type,
                                          &bitRate);
    OSStatus bitRateStatus =
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_AverageBitRate,
                         biteRate);
    if (bitRateStatus!=noErr) {
        NSLog(@"fail set bitRateStatus");
    }
    
    /*
     帧率: 单位时间(s)显示的帧数 单位FPS或Hz
        * kVTCompressionPropertyKey_ExpectedFrameRate // Read/write, CFNumber, Optional 期望帧率 fps
        * kVTCompressionPropertyKey_MaxKeyFrameInterval //Read/write, CFNumber<int>, Optional 同步帧(也就是关键帧)的时间间隔：gop size
     */
    int fps = 10;
    CFNumberRef cfps = CFNumberCreate(NULL, kCFNumberIntType, &fps);
    OSStatus expectedFrameRateStatus =
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_ExpectedFrameRate,
                         cfps);
    if (expectedFrameRateStatus!=noErr) {
        NSLog(@"fail set expectedFrameRateStatus");
    }
    //关键帧的间隔
    int syInterval = 10;
    CFNumberRef csyInterval = CFNumberCreate(NULL, kCFNumberIntType, &syInterval);
    OSStatus maxKeyFrameIntervalStatus =
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_MaxKeyFrameInterval,
                         csyInterval);
    if (maxKeyFrameIntervalStatus!=noErr) {
        NSLog(@"fail set expectedFrameRateStatus");
    }
    
    //实时编码输出降低延时：kVTCompressionPropertyKey_RealTime Read/write, CFBoolean or NULL, Optional, default NULL
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_RealTime,
                         kCFBooleanTrue);
    
    //编码优先级kVTCompressionPropertyKey_ProfileLevel
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_ProfileLevel,
                         kVTProfileLevel_H264_Baseline_AutoLevel);
    //准备开始编码
    OSStatus prepareStatus = VTCompressionSessionPrepareToEncodeFrames(encodeSession);
    if (prepareStatus!=noErr) {
        NSLog(@"prepare fail");
    }
}

- (void)initFileHandle{
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"test.h264"];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if(fileHandle == nil) {
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    } else {
        [fileHandle seekToEndOfFile];
    }
    NSLog(@"%@",fileHandle);
}
- (void)invaliteHandle{
    [fileHandle closeFile];
    fileHandle = nil;
}

void (compressionOutputCallback)(void * CM_NULLABLE outputCallbackRefCon,
                                    void * CM_NULLABLE sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                                    CM_NULLABLE CMSampleBufferRef sampleBuffer ){
    /*
     此时的sampleBuffer 是编码后的sampleBuffer，将sampleBuffer转换成h264即可
     步骤  1、通过关键帧，将sps和pps取出保存在h264头部。
          2、遍历CMBlockBufferRef 中的所有data，存入h264中
     */
    
    //1.判断是否成功解码
    if(status!=noErr){
        NSLog(@"解码失败");
        return;
    }
    if(!CMSampleBufferDataIsReady(sampleBuffer)){
        NSLog(@"解码失败");
        return;
    }
    //2.判断是否是关键帧，也就是同步帧
    CFArrayRef attArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if(attArray==NULL||CFArrayGetCount(attArray)<=0){
        return;
    }
    CFDictionaryRef attDict = CFArrayGetValueAtIndex(attArray, 0);
    BOOL isKeyFrame = !CFDictionaryContainsKey(attDict, kCMSampleAttachmentKey_NotSync);
    if(isKeyFrame){
        CMFormatDescriptionRef formatDes = CMSampleBufferGetFormatDescription(sampleBuffer);
        const uint8_t *spsPointer;
        size_t spsSize;
        OSStatus spsStatus =  CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDes,
                                                                                 0,
                                                                                 &spsPointer,
                                                                                 &spsSize,
                                                                                 NULL,
                                                                                 NULL);
        NSData *spsData = [NSData dataWithBytes:spsPointer length:spsSize];
        
        const uint8_t *ppsPointer;
        size_t ppsSize;
        OSStatus ppsStatus =  CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDes,
                                                                                 1,
                                                                                 &ppsPointer,
                                                                                 &ppsSize,
                                                                                 NULL,
                                                                                 NULL);
        NSData *ppsData = [NSData dataWithBytes:ppsPointer length:ppsSize];
        if(spsStatus==noErr && ppsStatus==noErr){
            ViewController * self = (__bridge ViewController *)(outputCallbackRefCon);
            [self writeSps:spsData Pps:ppsData];
        }
    }
    //3.获取data写入
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t totalLength;
    char *dataPointer;
    OSStatus getBolckPointerStatus =
    CMBlockBufferGetDataPointer(blockBuffer,
                                0, //数据偏移量,这里我们从头开始获取整个数据，是不需要偏移量的
                                NULL, //设置了偏移量就会返回这个偏移量的大小，不需要的一个参数
                                &totalLength,//整个数据的长度
                                &dataPointer);
    if(getBolckPointerStatus!=noErr){
        NSLog(@"获取数据失败");
        return;
    }
    /*
     返回的nalu数据前四个字节不是 0x00,0x00,0x00,0x01 的start code ，而是大端模式的长度length
     nalu数据的结构：
        前四个字节+视频数据  前四个字节+视频数据  前四个字节+视频数据......
     处理结果：
        0x00,0x00,0x00,0x01+视频数据  0x00,0x00,0x00,0x01+视频数据  0x00,0x00,0x00,0x01+视频数据......
     处理方法：
        1.取出第一块数据的开头四个字节，将这四个字节转换成小端。这样就能得出第一条数据的视频数据的length
        2.根据视频数据的指针位置和视频数据的length可以将这一块视频数据转化成data
        3.将视频数据data前面加上0x00,0x00,0x00,0x01 的start code 后写入文件。
        4.去除第二块数据重复1的操作，直至将整个buffer的视频数据写入文件。
     */
    
    static const int headerLenth = 4;
    size_t bufferOffset = 0;
    while(bufferOffset<totalLength-headerLenth){
        uint32_t naluLength;
        memcpy(&naluLength, dataPointer+bufferOffset, headerLenth);
        naluLength = CFSwapInt32BigToHost(naluLength);
        NSData *data = [NSData dataWithBytes:dataPointer+bufferOffset+headerLenth length:naluLength];
        ViewController * self = (__bridge ViewController *)(outputCallbackRefCon);
        [self writeEncodeData:data];
        bufferOffset += naluLength + headerLenth;
    }
}

- (void)writeSps:(NSData*)sps Pps:(NSData*)pps{
    //h264协议 start code
    const uint8_t start[] = {0x00,0x00,0x00,0x01};
    const size_t lenth = 4;
    NSData *header = [NSData dataWithBytes:start length:lenth];
    if (fileHandle) {
        [fileHandle writeData:header];
        [fileHandle writeData:sps];
        [fileHandle writeData:header];
        [fileHandle writeData:pps];
    }
    NSLog(@"文件写入sps pps");
}
- (void)writeEncodeData:(NSData*)data{
    //h264协议 start code
    const uint8_t start[] = {0x00,0x00,0x00,0x01};
    const size_t lenth = 4;
    NSData *header = [NSData dataWithBytes:start length:lenth];
    if (fileHandle) {
        [fileHandle writeData:header];
        [fileHandle writeData:data];
    }
    NSLog(@"文件写入data");
}


#pragma mark  ---delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    //sampleBuffer --->image并展示
    CVImageBufferRef imagebuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciimage = [CIImage imageWithCVImageBuffer:imagebuffer];
    UIImage *image = [UIImage imageWithCIImage:ciimage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playerView.image = image;
    });
    //硬件编码，单独用一个线程采集防止阻塞摄像头采集,一定要用同步线程，异步回产生异常！！！
    dispatch_sync(encodeQueue, ^{
        if (isEncoding) {
            [self startEncode:sampleBuffer];
        }
    });
}

#pragma mark   ---event
- (IBAction)buttonAction:(UIButton *)sender {
    if (!sender.selected) {
        //开始编码
        [self initFileHandle];
        dispatch_sync(encodeQueue, ^{
            [self initEncodeSession];
            isEncoding = true;
        });
    }else{
        //结束编码
        isEncoding = false;
        [self stopEncode];
        [self invaliteHandle];
    }
    sender.selected = !sender.selected;
}
//开始编码
- (void)startEncode:(CMSampleBufferRef)buffer{
    //1. 从CMSampleBuffer 提取CVImageBuffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    //2.添加一个时间戳
    CMTime pts = CMTimeMake(frameCount++, 1000);
    VTEncodeInfoFlags infoFlagsOut;
    OSStatus encodeStatus =
    VTCompressionSessionEncodeFrame(encodeSession,
                                    imageBuffer,
                                    pts, //获取到的这个sample buffer数据的展示时间戳。每一个传给这个session的时间戳都要大于前一个展示时间戳.如果不设置会导致时间轴过长
                                    kCMTimeInvalid,//这个帧的展示时间.如果没有时间信息,可设置kCMTimeInvalid.
                                    NULL, //包含这个帧的属性.帧的改变会影响后边的编码帧.
                                    NULL, //回调函数会引用你设置的这个帧的参考值.
                                    &infoFlagsOut);//指向一个VTEncodeInfoFlags来接受一个编码操作.如果使用异步运行,kVTEncodeInfo_Asynchronous被设置；同步运行,kVTEncodeInfo_FrameDropped被设置；设置NULL为不想接受这个信息.
    if (encodeStatus!=noErr) {
        NSLog(@"编码失败 %d",(int)encodeStatus);
        //结束编码
        [self buttonAction:self.controBtn];
    }
}
//结束编码
- (void)stopEncode{
    VTCompressionSessionCompleteFrames(encodeSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(encodeSession);
    CFRelease(encodeSession);
    encodeSession = NULL;
}

#pragma mark    ---getter&&setter
- (AVCaptureSession *)avSession{
    if (!_avSession) {
        _avSession = [[AVCaptureSession alloc]init];
        _avSession.sessionPreset = AVCaptureSessionPreset640x480;

        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        
        NSMutableDictionary *settings = [NSMutableDictionary new];
        //需要设置视频的格式，h264仅支持yuv格式。
        [settings setValue:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc]init];
        output.alwaysDiscardsLateVideoFrames = false;
        output.videoSettings = settings;
        [output setSampleBufferDelegate:self queue:outputQueue];

        [_avSession beginConfiguration];
        if ([_avSession canAddInput:input]) {
            [_avSession addInput:input];
        }
        if ([_avSession canAddOutput:output]) {
            [_avSession addOutput:output];
        }
        [_avSession commitConfiguration];
    }
    return _avSession;
}

- (UIImageView *)playerView{
    if (!_playerView) {
        //CIImage和UIView坐标系是反的，需要设置UIImageView宽度为屏幕高度，长度为屏幕宽度，在旋转90度,还得设置锚点
        _playerView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width)];
        _playerView.layer.anchorPoint = CGPointMake(0, 0);
        _playerView.layer.position = CGPointMake(self.view.bounds.size.width, 0);
        _playerView.transform = CGAffineTransformMakeRotation(M_PI_2);
        _playerView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _playerView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
