//
//  AirControlMaskView.m
//  XAAirplayDemo
//
//  Created by Yangshuang on 2020/8/31.
//  Copyright © 2020 Yangshuang. All rights reserved.
//

#import "AirControlMaskView.h"
#import "Masonry.h"
#import "CLImageHelper.h"
#import "CLGCDTimerManager.h"
#import <MediaPlayer/MediaPlayer.h>


#define Padding        10

#define MJWeakSelf __weak typeof(self) weakSelf = self;

@interface AirControlMaskView (){
    
}

@end

@implementation AirControlMaskView

-(instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        [self configureVolume];
        [self initViews];
    }
        return self;
}


-(void)initViews{
    self.backgroundColor = [UIColor blackColor];
    
    MJWeakSelf
    _airPlayStateLab = [[UILabel alloc] init];
    _airPlayStateLab.font = [UIFont systemFontOfSize:18.0];
    _airPlayStateLab.textColor = [UIColor whiteColor];
    _airPlayStateLab.text = @"正在投屏中";
    _airPlayStateLab.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_airPlayStateLab];
    [_airPlayStateLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(weakSelf);
        make.top.equalTo(weakSelf).offset(30);
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(30);
    }];
    
    _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_playBtn setImage:[CLImageHelper imageWithName:@"CLPauseBtn"] forState:UIControlStateNormal];
    [_playBtn setImage:[CLImageHelper imageWithName:@"CLPlayBtn"] forState:UIControlStateSelected];
    [_playBtn addTarget:self action:@selector(playButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_playBtn];
    [_playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(weakSelf);
        make.centerY.equalTo(weakSelf);
        make.width.mas_equalTo(80);
        make.height.mas_equalTo(80);
    }];
    
    _currentTimeLab = [[UILabel alloc] init];
    _currentTimeLab.font = [UIFont systemFontOfSize:14];
    _currentTimeLab.textColor = [UIColor whiteColor];
    _currentTimeLab.adjustsFontSizeToFitWidth = YES;
    _currentTimeLab.text = @"00:00";
    _currentTimeLab.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_currentTimeLab];
    [_currentTimeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(weakSelf).mas_offset(Padding);
        make.width.mas_equalTo(45);
        make.height.mas_equalTo(30);
        make.bottom.mas_equalTo(weakSelf).offset(-40);
    }];
    
    _totalTimeLab = [[UILabel alloc] init];
    _totalTimeLab.font = [UIFont systemFontOfSize:14];
    _totalTimeLab.textColor = [UIColor whiteColor];
    _totalTimeLab.adjustsFontSizeToFitWidth = YES;
    _totalTimeLab.text = @"00:00";
    _totalTimeLab.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_totalTimeLab];
    [_totalTimeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(weakSelf).mas_offset(-Padding);
        make.width.mas_equalTo(45);
        make.height.mas_equalTo(30);
        make.bottom.mas_equalTo(weakSelf).offset(-40);
    }];
    
    _slider = [[CLSlider alloc] init];
    // slider开始滑动事件
    [_slider addTarget:self action:@selector(progressSliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    // slider滑动中事件
    [_slider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    // slider结束滑动事件
    [_slider addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
    //右边颜色
    _slider.maximumTrackTintColor = [UIColor whiteColor];
    [self addSubview:_slider];
    [self.slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(weakSelf.currentTimeLab.mas_right).mas_offset(Padding).priority(50);
        make.right.mas_equalTo(weakSelf.totalTimeLab.mas_left).mas_offset(-Padding);
        make.height.mas_equalTo(2);
        make.centerY.mas_equalTo(weakSelf.totalTimeLab);
    }];
    
}



#pragma mark ——— 获取系统音量
- (void)configureVolume {
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(self.frame.size.width - 100, 120, 120, 30)];
    _volumeViewSlider        = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    _volumeViewSlider.frame = volumeView.frame;
    _volumeViewSlider.transform = CGAffineTransformMakeRotation(-M_PI/2);
    [self addSubview:_volumeViewSlider];
}


#pragma mark ——— action
//播放按钮
- (void)playButtonAction:(UIButton *)button{
    if (_delegate && [_delegate respondsToSelector:@selector(xa_playButtonAction:)]) {
        [_delegate xa_playButtonAction:button];
    }else{
        NSLog(@"没有实现代理或者没有设置代理人");
    }
    button.selected = !button.selected;
}


#pragma mark - 滑杆
//开始滑动
- (void)progressSliderTouchBegan:(CLSlider *)slider{
    if (_delegate && [_delegate respondsToSelector:@selector(xa_progressSliderTouchBegan:)]) {
        [_delegate xa_progressSliderTouchBegan:slider];
    }else{
        NSLog(@"没有实现代理或者没有设置代理人");
    }
}
//滑动中
- (void)progressSliderValueChanged:(CLSlider *)slider{
    //计算出拖动的当前秒数
    CGFloat total           = (CGFloat)_playerItem.duration.value / _playerItem.duration.timescale;
    CGFloat dragedSeconds   = total * slider.value;
    _sliderValue = slider.value;
    //转换成CMTime才能给player来控制播放进度
    CMTime dragedCMTime     = CMTimeMake(dragedSeconds, 1);
    NSInteger proMin                    = (NSInteger)CMTimeGetSeconds(dragedCMTime) / 60;//当前秒
    NSInteger proSec                    = (NSInteger)CMTimeGetSeconds(dragedCMTime) % 60;//当前分钟
    self.currentTimeLab.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)proMin, (long)proSec];
    
    if (_delegate && [_delegate respondsToSelector:@selector(xa_progressSliderValueChanged:)]) {
        [_delegate xa_progressSliderValueChanged:slider];
    }else{
        NSLog(@"没有实现代理或者没有设置代理人");
    }
}
//滑动结束
- (void)progressSliderTouchEnded:(CLSlider *)slider{
    
    CGFloat total           = (CGFloat)_playerItem.duration.value / _playerItem.duration.timescale;
    CGFloat dragedSeconds   = total * slider.value;
    _sliderValue = slider.value;
    //转换成CMTime才能给player来控制播放进度
    CMTime dragedCMTime     = CMTimeMake(dragedSeconds, 1);
    CGFloat drageSeconds    = (CGFloat)CMTimeGetSeconds(dragedCMTime);
    if (_delegate && [_delegate respondsToSelector:@selector(xa_progressSliderTouchEnded: position:)]) {
        [_delegate xa_progressSliderTouchEnded:slider position:drageSeconds];
    }else{
        NSLog(@"没有实现代理或者没有设置代理人");
    }
}


// 更新进度条
- (void)updateSliderWithCurrentTime:(double)currentTime totalTime:(double)totalTime{
    
    CGFloat sliderValue = currentTime / totalTime;
    if (sliderValue >= 1) {
        sliderValue = 1;
    }
    self.slider.value = sliderValue;
    _sliderValue = self.slider.value;
    //当前时长
    NSInteger proMin                    = (NSInteger)(currentTime / 60);//当前秒
    NSInteger proSec                    = (NSInteger)(currentTime) % 60;//当前分钟
    self.currentTimeLab.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)proMin, (long)proSec];
//    //总时长
//    NSInteger durMin                    = (NSInteger)_playerItem.asset.duration.value / _playerItem.asset.duration.timescale / 60;//总分钟
//    NSInteger durSec                    = (NSInteger)_playerItem.asset.duration.value / _playerItem.asset.duration.timescale % 60;//总秒
//    self.totalTimeLab.text   = [NSString stringWithFormat:@"%02ld:%02ld", (long)durMin, (long)durSec];
}



// 配置进度条
- (void)configSlider{
    if (_playerItem.asset.duration.timescale != 0){
        //设置进度条
        self.slider.maximumValue   = 1;
        self.slider.value          = CMTimeGetSeconds([_playerItem currentTime]) / (_playerItem.asset.duration.value / _playerItem.asset.duration.timescale);
        _sliderValue = self.slider.value;
        //当前时长
        NSInteger proMin                    = (NSInteger)CMTimeGetSeconds([_playerItem currentTime]) / 60;//当前秒
        NSInteger proSec                    = (NSInteger)CMTimeGetSeconds([_playerItem currentTime]) % 60;//当前分钟
        self.currentTimeLab.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)proMin, (long)proSec];
        //总时长
        NSInteger durMin                    = (NSInteger)_playerItem.asset.duration.value / _playerItem.asset.duration.timescale / 60;//总分钟
        NSInteger durSec                    = (NSInteger)_playerItem.asset.duration.value / _playerItem.asset.duration.timescale % 60;//总秒
        self.totalTimeLab.text   = [NSString stringWithFormat:@"%02ld:%02ld", (long)durMin, (long)durSec];
    }
}


// 重置进度条
- (void)resetSlider{
    self.slider.value = 0.0;
    self.currentTimeLab.text = @"00:00";
    self.totalTimeLab.text = @"00:00";
    [self.playBtn setSelected:YES];
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
