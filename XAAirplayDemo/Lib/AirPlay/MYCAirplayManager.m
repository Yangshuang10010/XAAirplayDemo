//
//  MYCAirplayManager.m
//  AirplayTest
//
//  Created by 马雨辰 on 2018/8/9.
//  Copyright © 2018年 马雨辰. All rights reserved.
//

#import "MYCAirplayManager.h"
#import "GCDAsyncSocket.h"
@interface MYCAirplayManager()<NSNetServiceBrowserDelegate,NSNetServiceDelegate,GCDAsyncSocketDelegate, DLNADelegate>
{
    CGFloat _jumpStartTime;
    BOOL isPlaying;
}
@property(nonatomic,strong)NSNetServiceBrowser *serviceBrowser;

@property(nonatomic,strong)GCDAsyncSocket *socket;

@property(nonatomic,assign)BOOL userCloseSocket;//用户主动断开socket


@end

@implementation MYCAirplayManager

static MYCAirplayManager*_shardManager;

+ (MYCAirplayManager *)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shardManager = [[MYCAirplayManager alloc]init];
    });
    return _shardManager;
}


-(instancetype)init
{
    self = [super init];
    if(self)
    {
//        [self searchAirplayDevice];
    }
    return self;
}


-(NSMutableArray *)deviceList
{
    if(_deviceList == nil)
    {
        _deviceList = [[NSMutableArray alloc]init];
    }
    
    return  _deviceList;
}

/**
 搜索可支持Airplay的设备
 */
-(void)searchAirplayDeviceWithTimeOut:(CGFloat)timeout
{
    NSLog(@"搜索可支持的设备");
    //先清空临时数据
    [self clearCacheData];
    
    if (self.isAirPlay) {
        //airplay协议
        self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
        [self.serviceBrowser setDelegate:self];
        [self.serviceBrowser searchForServicesOfType:@"_airplay._tcp" inDomain:@"local."];
    }else {
        //DLAN协议
        self.dlnaManager = [MRDLNA sharedMRDLNAManager];
        self.dlnaManager.delegate = self;
        [self.dlnaManager startSearch];
    }

    double delayInSeconds = timeout;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(MYCAirplayManager:searchAirplayDeviceFinish:)])
        {
            [self.delegate MYCAirplayManager:self searchAirplayDeviceFinish:self.deviceList];
        }
    });
}


#pragma mark DLAN协议
- (void)searchDLNAResult:(NSArray *)devicesArray{
    NSLog(@"DLAN发现设备 %@", devicesArray);
    if ([devicesArray isKindOfClass:[NSArray class]] && devicesArray.count > 0) {
        for (CLUPnPDevice *model in devicesArray) {
            MYCAirplayDevice *deviceItem = [[MYCAirplayDevice alloc] init];
            deviceItem.dlanDevice = model;
            deviceItem.displayName = model.friendlyName;
            [self.deviceList addObject:deviceItem];
        }
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(MYCAirplayManager:searchedAirplayDevice:)])
        {
            [self.delegate MYCAirplayManager:self searchedAirplayDevice:self.deviceList];
        }
    }
}


#pragma mark AirPlay协议

#pragma mark NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:20.0];
    
    MYCAirplayDevice *airplayDevice = [[MYCAirplayDevice alloc]init];
    airplayDevice.netService = aNetService;
    
    [self.deviceList addObject:airplayDevice];

    if(!moreComing)
    {
        NSLog(@"找到设备完成");
        [self.serviceBrowser stop];
        self.serviceBrowser = nil;
    }
}


#pragma mark NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    for(NSInteger i = 0 ; i< self.deviceList.count ; i++)
    {
        MYCAirplayDevice *device = [self.deviceList objectAtIndex:i];
        
        if(sender == device.netService)
        {
            [device refreshInfo];
            break;
        }
    }
    
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(MYCAirplayManager:searchedAirplayDevice:)])
    {
        [self.delegate MYCAirplayManager:self searchedAirplayDevice:self.deviceList];
    }
}



#pragma mark -- GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    self.socketIsOnLine = YES;
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(MYCAirplayManager:selectedDeviceOnLine:)])
    {
        [self.delegate MYCAirplayManager:self selectedDeviceOnLine:self.selectedDevice];
    }
}


-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    self.socketIsOnLine = NO;
    
    if(self.userCloseSocket)
    {
        self.userCloseSocket = NO;

        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(MYCAirplayManager:selectedDeviceDisconnect:)])
        {
            [self.delegate MYCAirplayManager:self selectedDeviceDisconnect:self.selectedDevice];
        }
        
        return;
    }
    
    [self activateSocketToDevice:self.selectedDevice];
}

#pragma mark 回调结果
//协议参数和返回参考：https://nto.github.io/AirPlay.html#audio-remotecontrol
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"dataStr----%@",dataStr);

    NSRange okRange = [dataStr rangeOfString:@"200 OK"];
    
    if (tag == 0) {
        if (okRange.location > 0 && okRange.length > 0) {//结果包含200状态字符串
            [self stopGetPlayInfo];
        }else {
            [self.socket readDataWithTimeout:- 1 tag:0];
        }
    }
    
//    if (tag == 100) {
//        //获取plist字符串位置
//        NSRange plistRange = [dataStr rangeOfString:@"<?xml"];
////        NSLog(@"%ld, %ld", range.location, range.length); // location为查询字符串所在位置，length为查询字符串的长度
//        if (plistRange.location > 0 && plistRange.length > 0) {//结果包含plist
//            //截取plist字符串
//            NSString *source = [dataStr substringFromIndex:plistRange.location];
//            //字符串解析转换字典
//            NSData* plistData = [source dataUsingEncoding:NSUTF8StringEncoding];
//            NSError *error;
//            NSPropertyListFormat format;
//            NSDictionary *info = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:&format error:&error];
//            //字典解析成功
//            if ([info isKindOfClass:[NSDictionary class]]) {
//                //回调通知结果
//                if (self.delegate && [self.delegate respondsToSelector:@selector(MYCAirplayManager:getPlaybackinfo:)]) {
//                    [self.delegate MYCAirplayManager:self getPlaybackinfo:info];
//                }
//            }
//            if (![info intForKey:@"readyToPlay"]) {
//                [self.socket readDataWithTimeout:- 1 tag:100];
//            }
//
//            [self startGetPlaybackPosition];
//        }else {
//            [self.socket readDataWithTimeout:- 1 tag:100];
//        }
//    }
    

    if (tag == 200) {
        //获取plist字符串位置
        NSRange startRange = [dataStr rangeOfString:@"duration: "];
        NSRange endRange = [dataStr rangeOfString:@"position: "];

        NSRange durationRange = NSMakeRange(startRange.location + startRange.length, endRange.location - startRange.location - startRange.length);
        if (durationRange.location > 0 && durationRange.length > 0 && endRange.location > 0 && endRange.length > 0 ) {//结果
            NSString *duration = [dataStr substringWithRange:durationRange];
            duration = [duration stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            NSString *position = [dataStr substringFromIndex:endRange.location+endRange.length];
            position = [position stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            NSMutableDictionary *info = [NSMutableDictionary dictionary];;
//            [info setValue:[duration trimString] forKey:@"duration"];
//            [info setValue:[position trimString] forKey:@"position"];
            //回调通知结果
            if (self.delegate && [self.delegate respondsToSelector:@selector(MYCAirplayManager:getPlaybackinfo:)]) {
                [self.delegate MYCAirplayManager:self getPlaybackinfo:info];
            }
        }

        [self stopGetPlayInfo];
    }
}

-(void)startGetPlaybackInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(getPlaybackInfo) withObject:nil afterDelay:0.5];
        [self performSelector:@selector(getPlaybackPosition) withObject:nil afterDelay:0.5];
    });
}

-(void)stopGetPlayInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    });
}


#pragma mark -- 用户操作

/**
 激活socket
 
 @param device 链接的设备
 */
-(void)activateSocketToDevice:(MYCAirplayDevice *)device
{
    
    if(self.socket == nil)
    {
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    
    
    if(self.socketIsOnLine)
    {
        if([self.selectedDevice.hostName isEqualToString:device.hostName] && self.selectedDevice.port == device.port)
        {
            //同一台设备，同一个端口
            
            return;
        }
        else
        {
            [self.socket disconnect];
        }
    }
    
    NSError *error = nil;
    
    [self.socket connectToHost:device.hostName onPort:device.port viaInterface:nil withTimeout:-1 error:&error];
    
    self.selectedDevice = device;
}



/**
 在Airplay设备上播放视频
 
 @param airplayDeivce 播放设备
 @param videoUrlStr 视频url
 */
-(void)playVideoOnAirplayDevice:(MYCAirplayDevice *)airplayDeivce
                    videoUrlStr:(NSString *)videoUrlStr
                  startPosition:(CGFloat)startPosition
{
    NSString *url = videoUrlStr;
    
    
    _jumpStartTime = 0;
    _startPosition = startPosition;
    
    if (self.isAirPlay) {
        //airplay协议
        NSString *body = [[NSString alloc] initWithFormat:@"Content-Location: %@\r\n"
                          "Start-Position: %f\r\n", url, startPosition];
        NSUInteger length = [body length];
        
        NSString *message = [[NSString alloc] initWithFormat:@"POST /play HTTP/1.1\r\n"
                             "Content-Length: %lu\r\n"
                             "User-Agent: MediaControl/1.0\r\n\r\n%@", (unsigned long)length, body];
        
        
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];

        [self sendData:data withTag:0];
    }else {
        //DLAN协议
        self.dlnaManager.device = airplayDeivce.dlanDevice;
        self.dlnaManager.playUrl = videoUrlStr;
        self.dlnaManager.startPosition = startPosition;
        [self.dlnaManager startDLNA];
    }
}
/**
 切集
 */
//-(void)changeUrl:(NSString *)videoUrl {
//    [self changeUrl:videoUrl startPosition:0];
//}

-(void)changeUrl:(NSString *)videoUrl
   startPosition:(CGFloat)startPosition
{
    [self stopGetPlayInfo];
    
    _startPosition = startPosition;
    _jumpStartTime = 0;
    
    [self activateSocketToDevice:self.selectedDevice];
    
    self.dlnaManager.device = self.selectedDevice.dlanDevice;
    self.dlnaManager.playUrl = videoUrl;
    self.dlnaManager.startPosition = startPosition;
    [self.dlnaManager playTheURL:videoUrl startPositon:startPosition];
}

-(void)upnpSetAVTransportURIResponse
{
    [self startGetPlaybackInfo];//获取播放状态
//    [self.dlnaManager seekChanged:_startPosition];
}

/**
 快进到某个播放时间
 @param playTime 播放时间（秒）
 */
-(void)seekPlayTime:(CGFloat)playTime
{
    [self stopGetPlayInfo];
    NSLog(@"快进点击 = %f", playTime);
    if (self.isAirPlay) {
        //airplay协议
        NSString *message = [[NSString alloc] initWithFormat:@"POST /scrub?position=%f HTTP/1.1\r\n\r\n"
                             "Content-Length: 0"
                             "User-Agent: MediaControl/1.0\r\n\r\n",playTime];

        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
        
        [self sendData:data withTag:3];
    }else {
        //DLAN协议
        [self.dlnaManager seekChanged:playTime];
    }
}

-(void)jumpStartWithPlayTime:(CGFloat)playTime
{
    if (_jumpStartTime > 0) {//当前视频已经跳过，不重复执行
        return;
    }
    _jumpStartTime = playTime;
    [self seekPlayTime:playTime];
}


/**
 暂停正在播放的视频
 */
-(void)pauseVideoPlay
{
    if (self.isAirPlay) {
        //airplay协议
        NSString *message = [[NSString alloc] initWithFormat:@"POST /rate?value=0.0 HTTP/1.1\r\n\r\n"
                             "Content-Length: 0"
                             "User-Agent: MediaControl/1.0\r\n\r\n"];
        
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
        
        [self sendData:data withTag:2];
    }else {
        //DLAN协议
        [self.dlnaManager dlnaPause];
    }
}

-(void)videoPlayWithSpeed:(CGFloat)speed
{
    if (self.isAirPlay) {
        //TODO
    }else {
        //DLAN协议
        [self.dlnaManager dlnaPlayWithSpeed:[NSString stringWithFormat:@"%.2f", speed]];
    }
}


-(void)changeRate:(CGFloat)playTime
{
    [self.dlnaManager dlnaPlay];
}


/**
 继续播放
 */
-(void)playVideo
{
    if (self.isAirPlay) {
        //airplay协议
        NSString *message = [[NSString alloc] initWithFormat:@"POST /rate?value=1.0 HTTP/1.1\r\n\r\n"
                             "Content-Length: 0"
                             "User-Agent: MediaControl/1.0\r\n\r\n"];
        
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
        
        [self sendData:data withTag:1];
    }else {
        //DLAN协议
        [self.dlnaManager dlnaPlay];
    }
}


/**
 设置音量
 */
- (void)volumeChanged:(CGFloat)volume
{
    [self.dlnaManager volumeChanged:[NSString stringWithFormat:@"%.0f", volume]];
}

/**
 获取播放状态信息
 */
-(void)getPlaybackInfo
{
    if (self.isAirPlay) {
        //airplay协议
        [self stopGetPlayInfo];
        NSString *message = [[NSString alloc] initWithFormat:@"GET /playback-info HTTP/1.1\r\n\r\n"
                             "Content-Length: 0"
                             "User-Agent: MediaControl/1.0\r\n\r\n"];

        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];

        [self sendData:data withTag:100];
    }else {
        //DLAN协议
        [self.dlnaManager getTransportInfo];
    }
}

//播放状态回调
-(void)upnpGetTransportInfoResponse:(CLUPnPTransportInfo *)info
{
    NSLog(@"%@ === %@", info.currentTransportState, info.currentTransportStatus);
    dispatch_async(dispatch_get_main_queue(), ^{
        //回调通知结果
        if (self.delegate && [self.delegate respondsToSelector:@selector(MYCAirplayManager:getPlaybackStatus:)]) {
            [self.delegate MYCAirplayManager:self getPlaybackStatus:info];
        }
    });
    
    if (![self trimEmpty:info.currentTransportStatus]) {
        if ([info.currentTransportState isEqualToString:@"PLAYING"]) {
            //播放中
            isPlaying = YES;
        }else if ([info.currentTransportState isEqualToString:@"STOPPED"]){
            //停止
            isPlaying = NO;
        }else {
            //暂停
            isPlaying = NO;
        }
    }
    [self startGetPlaybackInfo];
}

//获取播放进度
-(void)getPlaybackPosition
{
    if (self.isAirPlay) {
        //airplay协议
        //    GET /playback-info HTTP/1.1
        //    Content-Length: 0
        //    User-Agent: MediaControl/1.0
        //    X-Apple-Session-ID: 24b3fd94-1b6d-42b1-89a3-47108bfbac89
            NSString *message = [[NSString alloc] initWithFormat:@"GET /scrub HTTP/1.1\r\n\r\n"
                                 "Content-Length: 0"
                                 "User-Agent: iTunes/10.6 (Macintosh; Intel Mac OS X 10.7.3) AppleWebKit/535.18.5\r\n\r\n"];
            
            NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
            
            [self sendData:data withTag:200];
    }else {
        //DLAN协议
        [self.dlnaManager getPositionInfo];
    }
}

//DLAN播放进度回调
-(void)upnpGetPositionInfoResponse:(CLUPnPAVPositionInfo *)info
{
    if (info.relTime > 0) {
        if (_startPosition > 0) {
            [self seekPlayTime:_startPosition];
            _startPosition = 0;
        }
        NSMutableDictionary *infoDic = [NSMutableDictionary dictionary];;
        [infoDic setValue:[NSString stringWithFormat:@"%f", info.trackDuration] forKey:@"duration"];
        [infoDic setValue:[NSString stringWithFormat:@"%f", info.relTime] forKey:@"position"];
//        NSLog(@"DLAN播放进度回调: %@", infoDic);
        dispatch_async(dispatch_get_main_queue(), ^{
            //回调通知结果
            if (self.delegate && [self.delegate respondsToSelector:@selector(MYCAirplayManager:getPlaybackinfo:)]) {
                [self.delegate MYCAirplayManager:self getPlaybackinfo:infoDic];
            }
        });
    }
//    [self startGetPlaybackPosition];
}


/**
 退出播放
 */
-(void)stop
{
    [self stopGetPlayInfo];
    if (self.isAirPlay) {
        //airplay协议
        
        NSString *message = [[NSString alloc] initWithFormat:@"POST /stop HTTP/1.1\r\n\r\n"
                             "Content-Length: 0"
                             "User-Agent: MediaControl/1.0\r\n\r\n"];

        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];

        [self sendData:data withTag:4];

        [self closeSocket];
    }else {
        //DLAN协议
        [self.dlnaManager endDLNA];
    }
}

-(void)closeSocket
{
    self.userCloseSocket = YES;
    
    [self.socket disconnect];
}

-(void)sendData:(NSData *)data withTag:(long )tag
{
    [self.socket writeData:data withTimeout:-1 tag:tag];
    
    [self.socket readDataWithTimeout:-1 tag:tag];
    
}



-(void)clearCacheData
{
    [self.deviceList removeAllObjects];
}

/**
 音量
 */
-(void)changeVolume:(CGFloat)volume {
    NSString *vol = [NSString stringWithFormat:@"%.f", volume];
    NSLog(@"音量========>: %@",vol);
    [self.dlnaManager volumeChanged:vol];
}





-(BOOL)trimEmpty:(NSString *)str
{
    NSString *trimStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return (trimStr == nil || trimStr.length <= 0);
}

@end
