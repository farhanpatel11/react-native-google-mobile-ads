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
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>

@interface RNGoogleMobileAdsPreloadedBannerView : RCTView

@property (nonatomic, copy) NSString *unitId;
@property (nonatomic, copy) NSString *size;
@property (nonatomic, strong) id bannerView;

@end

@implementation RNGoogleMobileAdsPreloadedBannerViewManager

RCT_EXPORT_MODULE(RNGoogleMobileAdsPreloadedBannerView)

- (UIView *)view {
  return [[RNGoogleMobileAdsPreloadedBannerView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(unitId, NSString)
RCT_EXPORT_VIEW_PROPERTY(size, NSString)

@end

@implementation RNGoogleMobileAdsPreloadedBannerView

- (void)setUnitId:(NSString *)unitId {
  _unitId = unitId;
  [self updateBannerView];
}

- (void)setSize:(NSString *)size {
  _size = size;
  [self updateBannerView];
}

- (void)updateBannerView {
  if (!self.unitId || !self.size) {
    return;
  }
  
  // Remove existing banner view
  if (self.bannerView) {
    [self.bannerView removeFromSuperview];
    self.bannerView = nil;
  }
  
  // Get the banner module and consume the preloaded ad
  RNGoogleMobileAdsBannerModule *bannerModule = [self.bridge moduleForClass:[RNGoogleMobileAdsBannerModule class]];
  if (bannerModule) {
    id bannerView = [bannerModule consumePreloadedAd:self.unitId size:self.size];
    if (bannerView) {
      self.bannerView = bannerView;
      [self addSubview:bannerView];
      
      // Send loaded event with dimensions
      if ([bannerView respondsToSelector:@selector(bounds)]) {
        CGRect bounds = [bannerView bounds];
        NSDictionary *eventData = @{
          @"width": @(bounds.size.width),
          @"height": @(bounds.size.height)
        };
        
        // Send event to React Native
        if (self.onNativeEvent) {
          self.onNativeEvent(@{
            @"type": @"onAdLoaded",
            @"width": @(bounds.size.width),
            @"height": @(bounds.size.height)
          });
        }
      }
    }
  }
}

- (void)dealloc {
  if (self.bannerView) {
    [self.bannerView removeFromSuperview];
    self.bannerView = nil;
  }
}

@end
