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
    VTCompressionSessionRef encodeSession;
}
@property(nonatomic,strong)UIImageView *playerView;
@property(nonatomic,strong)AVCaptureSession *avSession;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view insertSubview:self.playerView atIndex:0];
    outputQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self.avSession startRunning];
    [self initEncodeSession];
}

- (void)initEncodeSession{
    
    int width = 480;//编码后视频分辨率的宽
    int height = 640; //编码后视频分辨率的高
    OSStatus sessionStatus =
    VTCompressionSessionCreate(NULL,//函数标记，NULL表示default
                               height,
                               640,
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
    /*
        视频编码需要设定一下参数:相关参数都可以在VTCompressionSessionPropertys.h中找到
     
        1.码率:单位时间的采样率
            我们设置的视频格式是： kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            注释如下:   Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range (luma=[0,255] chroma=[1,255]).  baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct
            YUV420采样规则：每个像素都采集Y，奇数行采集U,偶数行采集V  总采集数：W*H + W*H/2 = 1.5W*H ,所以单像素占1.5byte
            YUV422采样规则：每两个像素为一组，采集两个Y，一个U，一个V。 总采集数：W*H*2 ,所以单像素占2byte
        2.帧率:
     */
    
    //1.最大码率设置 单位：byte
    //kVTCompressionPropertyKey_DataRateLimits API_AVAILABLE(macosx(10.8), ios(8.0), tvos(10.2)); // Read/write, CFArray[CFNumber], [bytes, seconds, bytes, seconds...], Optional
    int dataRateLimits = width*height*1.5;
    NSArray *limits = @[@(dataRateLimits),@(1)];
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_DataRateLimits,
                         (__bridge CFTypeRef _Nonnull)(limits));
    //2.设置平均码率 单位：bps
    //kVTCompressionPropertyKey_AverageBitRate API_AVAILABLE(macosx(10.8), ios(8.0), tvos(10.2)); // Read/write, CFNumber<SInt32>, Optional
    int bitRate = width*height;
    CFNumberRef biteRate = CFNumberCreate(NULL,
                                          kCFNumberFloat32Type,
                                          &bitRate);
    VTSessionSetProperty(encodeSession,
                         kVTCompressionPropertyKey_AverageBitRate,
                         biteRate);
    
}

void (compressionOutputCallback)(void * CM_NULLABLE outputCallbackRefCon,
                                    void * CM_NULLABLE sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                                    CM_NULLABLE CMSampleBufferRef sampleBuffer ){
    
    
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
    //硬件编码
    
}

#pragma mark   ---event
- (IBAction)buttonAction:(UIButton *)sender {
    if (!sender.selected) {
        //开始编码

    }else{
        //结束编码
        
    }
    sender.selected = !sender.selected;
}

#pragma mark    ---getter&&setter
- (AVCaptureSession *)avSession{
    if (!_avSession) {
        _avSession = [[AVCaptureSession alloc]init];
        
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
    }
    return _playerView;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
