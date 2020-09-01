//
//  AirControlMaskView.h
//  XAAirplayDemo
//
//  Created by Yangshuang on 2020/8/31.
//  Copyright © 2020 Yangshuang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CLSlider.h"
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol AirControlMaskViewDelegate <NSObject>
@optional
/**播放按钮代理*/
- (void)xa_playButtonAction:(UIButton *)button;
/**重新播放*/
- (void)xa_resetPlay;
/**开始滑动*/
- (void)xa_progressSliderTouchBegan:(CLSlider *)slider;
/**滑动中*/
- (void)xa_progressSliderValueChanged:(CLSlider *)slider;
/**滑动结束*/
- (void)xa_progressSliderTouchEnded:(CLSlider *)slider position:(CGFloat)position;

@end



@interface AirControlMaskView : UIView


/* 代理 */
@property (nonatomic, weak) id<AirControlMaskViewDelegate> delegate;

/* 进度条 */
@property (nonatomic, strong) CLSlider *slider;

/* 总时长 */
@property (nonatomic, strong) UILabel *totalTimeLab;

/* 当前时间 */
@property (nonatomic, strong) UILabel *currentTimeLab;

/* 播放键 */
@property (nonatomic, strong) UIButton *playBtn;

/*音量滑杆*/
@property (nonatomic, strong) UISlider *volumeViewSlider;

/* 投屏状态 */
@property (nonatomic, strong) UILabel *airPlayStateLab;

/*播放器item*/
@property (nonatomic, strong) AVPlayerItem     *playerItem;

/* 播放进度 */
@property (nonatomic, assign) CGFloat sliderValue;


// 重置进度条
- (void)resetSlider;
// 配置进度条
- (void)configSlider;
// 更新进度条
- (void)updateSliderWithCurrentTime:(double)currentTime totalTime:(double)totalTime;

@end



NS_ASSUME_NONNULL_END
