//
//  ViewController.m
//  AirplayDemo
//
//  Created by Yangshuang on 2020/8/28.
//  Copyright © 2020 Yangshuang. All rights reserved.
//

#import "ViewController.h"
#import "CLPlayerView.h"
#import "SVProgressHUD.h"
#import "MYCAirplayManager.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <CoreLocation/CoreLocation.h>

#define kApplication        [UIApplication sharedApplication]
#define SCREEN_H        CGRectGetHeight([[UIScreen mainScreen] bounds])
#define SCREEN_W        CGRectGetWidth([[UIScreen mainScreen] bounds])

static NSString *videoUrl = @"http://v3.cztv.com/cztv/vod/2018/06/28/7c45987529ea410dad7c088ba3b53dac/h264_1500k_mp4.mp4";

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource, MYCAirplayManagerDelegate, CLLocationManagerDelegate, CLPlayerSliderDelegateDelegate>{
    // 当前可投屏设备
    MYCAirplayDevice *_currentDevice;
    //标记是否投屏成功了
    BOOL _airplaying;
}


// 播放器
@property (nonatomic, weak) CLPlayerView *playerView;
// 设备列表
@property (nonatomic, strong) UITableView  *deviceListView;
// 设备集合
@property (nonatomic, strong) NSMutableArray<MYCAirplayDevice *> *deviceArray;
// 开始投屏按钮
@property (nonatomic, strong) UIButton *airPlayBeginButton;
// 结束投屏按钮
@property (nonatomic, strong) UIButton *airPlayStopButton;
// 快进按钮
@property (nonatomic, strong) UIButton *fastForwardButton;
// 定位
@property (nonatomic, strong) CLLocationManager *locationManager;



@end

@implementation ViewController


#pragma mark ——— lazy load
/**
 * 设备集合
 */
- (NSMutableArray<MYCAirplayDevice *> *)deviceArray {
    if (!_deviceArray) {
        _deviceArray = [NSMutableArray array];
    }
    return _deviceArray;
}



-(UITableView *)deviceListView{
    if (!_deviceListView) {
        _deviceListView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _deviceListView. backgroundColor = [UIColor whiteColor];
        _deviceListView.frame = CGRectMake(0, SCREEN_H, SCREEN_W,SCREEN_H - (self.airPlayStopButton.frame.origin.y + 45 + 40));
        [_deviceListView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass(UITableViewCell.class)];
        _deviceListView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _deviceListView.dataSource = self;
        _deviceListView.delegate = self;
        _deviceListView.hidden = YES;
    }
    return _deviceListView;
}


#pragma mark ——— view cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor darkGrayColor];
    [self initPlayerView];
    [MYCAirplayManager sharedManager].delegate = self;
    [SVProgressHUD setDefaultStyle:SVProgressHUDStyleDark];
    [SVProgressHUD setDefaultAnimationType:SVProgressHUDAnimationTypeNative];
}


#pragma mark ——— initSubViews
-(void)initPlayerView{
    
    CLPlayerView *playerView = [[CLPlayerView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_W, 300)];
    _playerView = playerView;
    _playerView.delegate = self;
    [self.view addSubview:_playerView];
    
    [_playerView updateWithConfigure:^(CLPlayerViewConfigure *configure) {
        //后台返回是否继续播放
        configure.backPlay = NO;
        //转子颜色
        configure.strokeColor = [UIColor redColor];
        //工具条消失时间，默认10s
        configure.toolBarDisappearTime = 8;
        //顶部工具条隐藏样式，默认不隐藏
        configure.topToolBarHiddenType = TopToolBarHiddenAlways;
     }];
    _playerView.url = [NSURL URLWithString:videoUrl];
//    //播放
    [_playerView playVideo];
    //返回按钮点击事件回调,小屏状态才会调用，全屏默认变为小屏
    [_playerView backButton:^(UIButton *button) {
        NSLog(@"返回按钮被点击");
    }];
    //播放完成回调
    [_playerView endPlay:^{
        NSLog(@"播放完成");
    }];
    
    //开启投屏按钮
    _airPlayBeginButton = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_W/4 - 90/2 , playerView.frame.origin.y+300+ 40, 90, 45)];
    [_airPlayBeginButton setTitle:@"开启投屏" forState:UIControlStateNormal];
    _airPlayBeginButton.backgroundColor = [UIColor greenColor];
    [_airPlayBeginButton addTarget:self action:@selector(airPlayBegin:) forControlEvents:UIControlEventTouchUpInside];
    _airPlayBeginButton.layer.cornerRadius = 45.0/2;
    _airPlayBeginButton.clipsToBounds = YES;
    [self.view addSubview:_airPlayBeginButton];
    
    //关闭投屏按钮
    _airPlayStopButton = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_W/4*3 - 90/2 , playerView.frame.origin.y+300+ 40, 90, 45)];
    [_airPlayStopButton setTitle:@"关闭投屏" forState:UIControlStateNormal];
    _airPlayStopButton.backgroundColor = [UIColor greenColor];
    [_airPlayStopButton addTarget:self action:@selector(airPlayStop:) forControlEvents:UIControlEventTouchUpInside];
    _airPlayStopButton.layer.cornerRadius = 45.0/2;
    _airPlayStopButton.clipsToBounds = YES;
    [self.view addSubview:_airPlayStopButton];
    
    // 设备列表
    [self.view addSubview:self.deviceListView];
}

#pragma mark ——— Action
// 开始投屏
-(void)airPlayBegin:(UIButton *)sender{
    sender.userInteractionEnabled = NO;
    [SVProgressHUD showWithStatus:@"正在查找设备"];
    [[MYCAirplayManager sharedManager] searchAirplayDeviceWithTimeOut:10];
}

// 停止投屏
-(void)airPlayStop:(UIButton *)sender{
    [[MYCAirplayManager sharedManager] stop];
    [SVProgressHUD showSuccessWithStatus:@"断开连接"];
    _airplaying = NO;
}



#pragma mark ——— wifi & Location

/** 获取wifi信息
 *  可不用，如需展示当前wifi信息 可以使用，直接投屏不需要定位 wifi 相关方法
 */
-(void)getWiFiInfo {
    [self getLocation];
}

// 获取SSID
- (void)fetchSSIDInfo {
    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    id info = nil;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        if (info && [info count]) { break; }
    }
    NSLog(@"%@",info);
    NSString *ssid = [info stringForKey:@"SSID"];
    if ([self trimEmpty:ssid]) {
        [SVProgressHUD showInfoWithStatus:@"无法获取当前WiFi信息"];
    }else {
        [SVProgressHUD showSuccessWithStatus:[NSString stringWithFormat:@"当前WiFi:%@",[info stringForKey:@"SSID"]]];
    }
}


// 获取地理位置
- (void)getLocation {
    BOOL enable = [CLLocationManager locationServicesEnabled];
    NSInteger state = [CLLocationManager authorizationStatus];
        
    if (!enable || 2 > state) {// 尚未授权位置权限
        if (8 <= [[UIDevice currentDevice].systemVersion floatValue]) {
            NSLog(@"系统位置权限授权弹窗");
            // 系统位置权限授权弹窗
            _locationManager = [[CLLocationManager alloc] init];
            _locationManager.delegate = self;
            [_locationManager requestAlwaysAuthorization];
            [_locationManager requestWhenInUseAuthorization];
        }
    }else {
        if (state == kCLAuthorizationStatusDenied) {// 授权位置权限被拒绝
            NSLog(@"授权位置权限被拒绝");
            UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:@"提示"
                                                                              message:@"投屏需要获取您的位置权限，用来获取wifi信息，方便您进行投屏操作"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
            [alertCon addAction:[UIAlertAction actionWithTitle:@"暂不设置" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                
            }]];
            
            [alertCon addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                dispatch_after(0.2, dispatch_get_main_queue(), ^{
                    NSURL *url = [[NSURL alloc] initWithString:UIApplicationOpenSettingsURLString];// 跳转至系统定位授权
                    if([[UIApplication sharedApplication] canOpenURL:url]) {
                        if (@available(iOS 10.0, *)) {
                            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                            }];
                        } else {
                            // Fallback on earlier versions
                            [[UIApplication sharedApplication] openURL:url];
                        }
                    }
                });
            }]];
            [self presentViewController:alertCon animated:YES completion:^{
                [SVProgressHUD showErrorWithStatus:@"授权位置权限被拒绝"];
            }];
        }
    }
}


#pragma mark - 定位授权代理方法
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
        status == kCLAuthorizationStatusAuthorizedAlways) {
        //再重新获取ssid
        [self fetchSSIDInfo];
    }
}


#pragma mark ——— CLPlayerSliderDelegateDelegate
-(void)cl_progressValueDidChanged:(CGFloat)value{
    if (_airplaying) {
        [[MYCAirplayManager sharedManager] seekPlayTime:value];
    }
}


#pragma mark ——— MYCAirplayManagerDelegate
/**
 搜索设备完成
 @param deviceList 设备列表（如果为空，则表明没有搜索到支持Airplay的设备）
 */
- (void)MYCAirplayManager:(MYCAirplayManager *)airplayManager searchAirplayDeviceFinish:(NSMutableArray <MYCAirplayDevice *>*)deviceList {
    self.airPlayBeginButton.userInteractionEnabled = YES;
    if (deviceList.count == 0) {
        [SVProgressHUD showErrorWithStatus:@"未搜索到投屏设备"];
    }
}

/**
 搜索到了可支持的设备完成

 在执行 searchAirplayDevice 搜索到设备后调用
 
 @param deviceList 设备列表
 */
- (void)MYCAirplayManager:(MYCAirplayManager *)airplayManager searchedAirplayDevice:(NSMutableArray <MYCAirplayDevice *>*)deviceList {
    NSLog(@"搜索完成:%@", deviceList);
    self.airPlayBeginButton.userInteractionEnabled = YES;
    if (self.deviceArray.count > 0) {
        [self.deviceArray removeAllObjects];
    }
    if (deviceList.count > 0) {
        [SVProgressHUD showSuccessWithStatus:@"搜索完成"];
        [self.deviceArray addObjectsFromArray:deviceList];
        [self.deviceListView reloadData];
        self.deviceListView.hidden = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:1.0 animations:^{
                self.deviceListView.frame = CGRectMake(0, self.airPlayBeginButton.frame.origin.y+45+40, SCREEN_W,SCREEN_H - (self.airPlayBeginButton.frame.origin.y+45+40));
            }];
        });
    } else {
        [SVProgressHUD showErrorWithStatus:@"未搜索到投屏设备"];
        self.deviceListView.hidden = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:1.0 animations:^{
                self.deviceListView.frame = CGRectMake(0, SCREEN_H, SCREEN_W,SCREEN_H - (self.airPlayStopButton.frame.origin.y + 45 + 40));
            }];
        });
    }
}


/**
 设备已经连通后回调此代理
 */
- (void)MYCAirplayManager:(MYCAirplayManager *)airplayManager selectedDeviceOnLine:(MYCAirplayDevice *)airplayDevice {
    [SVProgressHUD showSuccessWithStatus:[NSString stringWithFormat:@"设备已连接---%@",airplayDevice.displayName]];
}

-(void)airPlayWithVideoUrl:(NSString *)url
{
    if ([self trimEmpty:url]) return;
    if (_currentDevice) {
        [[MYCAirplayManager sharedManager] activateSocketToDevice:_currentDevice];
        //开始时间，传值范围0-1 airplay传百分比，dlan传秒
//        CGFloat startPosition = self.moviePlayer.duration > 0 ? self.moviePlayer.currentPlaybackTime/self.moviePlayer.duration : 0;

        _airplaying = NO;
        // 当前时间位置
        CGFloat total = (CGFloat)_playerView.playerItem.duration.value / _playerView.playerItem.duration.timescale;
        CGFloat dragedSeconds   = total * _playerView.sliderValue;
        [[MYCAirplayManager sharedManager] playVideoOnAirplayDevice:_currentDevice videoUrlStr:url
                                                      startPosition:dragedSeconds];
    }
}

/**
 设备已经断开后回调此代理
 */
- (void)MYCAirplayManager:(MYCAirplayManager *)airplayManager selectedDeviceDisconnect:(MYCAirplayDevice *)airplayDevice {
    NSLog(@"设备已断开---%@",airplayDevice.displayName);
    [SVProgressHUD showWithStatus:[NSString stringWithFormat:@"设备已断开---%@",airplayDevice.displayName]];
}


/**
 投屏播放信息更新调此代理 - 每秒回调更新
 */
-(void)MYCAirplayManager:(MYCAirplayManager *)airplayManager getPlaybackinfo:(NSDictionary *)playbackInfo
{
    if (playbackInfo && [playbackInfo isKindOfClass:[NSDictionary class]]) {
        double currentTime = floor([[self stringForKey:@"position" withDictionary:playbackInfo] floatValue]);
        double totalTime = floor([[self stringForKey:@"duration" withDictionary:playbackInfo] floatValue]);
        
        // 这里实获取到上面👆时间 可以更新播放器进度  具体内容不实现了

//        if (currentTime > 0) {
        
//            if (currentTime > 0 && totalTime > 0 && currentTime >= totalTime-1) {

//            }else {
//                //跳过片头、片尾提示
//            }
//        }
    }
}


/**
投屏播放状态更新调此代理
*/
-(void)MYCAirplayManager:(MYCAirplayManager *)airplayManager getPlaybackStatus:(CLUPnPTransportInfo *)playbackInfo{

    if (![self trimEmpty:playbackInfo.currentTransportStatus]) {
        if ([playbackInfo.currentTransportState isEqualToString:@"PLAYING"]) {
            //播放中
            [self.playerView playVideo];
            _airplaying = YES;
        }else if ([playbackInfo.currentTransportState isEqualToString:@"STOPPED"]){
            //初始化加载中会返回stopped状态，需要判断_airplaying已经再播放的退出才响应
            if (_airplaying) {
                //暂停播放
                [self.playerView pausePlay];
                _airplaying = NO;
            }
        }
    }
}




#pragma tableView--delegate
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.deviceArray.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(UITableViewCell.class)];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:NSStringFromClass(UITableViewCell.class)];
    }
    if (indexPath.row < self.deviceArray.count) {
        if (self.deviceArray[indexPath.row].displayName.length > 0) {
            cell.textLabel.text = self.deviceArray[indexPath.row].displayName;
        }else{
            cell.textLabel.text = @"未知设备";
        }
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < _deviceArray.count) {
        [self airPlayDeviceClick:indexPath.row];
    }
}


// 选择投屏设备
- (void)airPlayDeviceClick:(NSInteger)index {
    if (self.deviceArray.count > index) {
        _currentDevice = [self.deviceArray objectAtIndex:index];
        NSString *playingUrlStr = [self.playerView.url absoluteString];
        if (playingUrlStr.length > 0) {
            [self airPlayWithVideoUrl:playingUrlStr];
        }else{
            [SVProgressHUD showWithStatus:@"没有视频地址"];
        }
    }
}



#pragma mark ——— Extend
-(BOOL)trimEmpty:(NSString *)str{
    NSString *trimStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return (trimStr == nil || trimStr.length <= 0);
}

-(NSString *)stringForKey:(id)aKey withDictionary:(NSDictionary *)dic{
    return [self objectForKey:aKey DefaultValue:@"" withDictionary:dic];
}

-(id)objectForKey:(id)aKey DefaultValue:(id)value withDictionary:(NSDictionary *)dic{
    id obj = [dic objectForKey:aKey];//指针已经被替换成了adjustObjectForKey
    if (!obj) {
        return value;
    }
    return obj;
}

@end
