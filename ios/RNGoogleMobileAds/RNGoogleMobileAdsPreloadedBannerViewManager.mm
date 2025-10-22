/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "RNGoogleMobileAdsPreloadedBannerViewManager.h"
#import "RNGoogleMobileAdsBannerModule.h"
#import <React/RCTView.h>
#import <React/RCTUIManager.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTBridge.h>
#import <GoogleMobileAds/GoogleMobileAds.h>

@interface RNGoogleMobileAdsPreloadedBannerView : RCTView

@property (nonatomic, strong) NSString *unitId;
@property (nonatomic, strong) NSString *size;
@property (nonatomic, strong) GADBannerView *bannerView;
@property (nonatomic, copy) RCTDirectEventBlock onNativeEvent;
@property (nonatomic, weak) RCTBridge *bridge;

@end

@implementation RNGoogleMobileAdsPreloadedBannerViewManager

RCT_EXPORT_MODULE(RNGoogleMobileAdsPreloadedBannerView)

- (UIView *)view {
  RNGoogleMobileAdsPreloadedBannerView *view = [[RNGoogleMobileAdsPreloadedBannerView alloc] init];
  view.bridge = self.bridge;
  return view;
}

RCT_EXPORT_VIEW_PROPERTY(unitId, NSString)
RCT_EXPORT_VIEW_PROPERTY(size, NSString)
RCT_EXPORT_VIEW_PROPERTY(onNativeEvent, RCTDirectEventBlock)

@end

@implementation RNGoogleMobileAdsPreloadedBannerView

- (instancetype)init {
  if (self = [super init]) {
    self.backgroundColor = [UIColor clearColor];
  }
  return self;
}

- (void)setUnitId:(NSString *)unitId {
  _unitId = unitId;
  [self loadPreloadedAd];
}

- (void)setSize:(NSString *)size {
  _size = size;
  [self loadPreloadedAd];
}

- (void)loadPreloadedAd {
  if (!_unitId || !_size) {
    return;
  }
  
  // Get the banner module from the bridge
  RNGoogleMobileAdsBannerModule *bannerModule = [self.bridge moduleForClass:[RNGoogleMobileAdsBannerModule class]];
  if (!bannerModule) {
    [self sendErrorEvent:@"Banner module not found"];
    return;
  }
  
  // Consume the preloaded ad
  GADBannerView *preloadedBanner = [bannerModule consumePreloadedAd:_unitId size:_size];
  if (preloadedBanner) {
    // Remove any existing banner view
    if (_bannerView) {
      [_bannerView removeFromSuperview];
    }
    
    // Add the preloaded banner view
    _bannerView = preloadedBanner;
    [self addSubview:_bannerView];
    
    // Set up constraints
    _bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_bannerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
      [_bannerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_bannerView.widthAnchor constraintEqualToConstant:_bannerView.bounds.size.width],
      [_bannerView.heightAnchor constraintEqualToConstant:_bannerView.bounds.size.height]
    ]];
    
    // Send loaded event
    [self sendEvent:@"onAdLoaded" data:@{
      @"width": @(_bannerView.bounds.size.width),
      @"height": @(_bannerView.bounds.size.height)
    }];
  } else {
    // No preloaded ad available
    [self sendErrorEvent:[NSString stringWithFormat:@"No preloaded ad available for unitId: %@ size: %@", _unitId, _size]];
  }
}

- (void)sendEvent:(NSString *)type data:(NSDictionary *)data {
  if (!self.onNativeEvent) {
    return;
  }
  
  NSMutableDictionary *event = [@{
    @"type": type
  } mutableCopy];
  
  if (data) {
    [event addEntriesFromDictionary:data];
  }
  
  self.onNativeEvent(event);
}

- (void)sendErrorEvent:(NSString *)message {
  [self sendEvent:@"onAdFailedToLoad" data:@{
    @"code": @(1), // ERROR_CODE_NO_FILL
    @"message": message
  }];
}

- (void)dealloc {
  if (_bannerView) {
    [_bannerView removeFromSuperview];
    _bannerView = nil;
  }
}

@end
