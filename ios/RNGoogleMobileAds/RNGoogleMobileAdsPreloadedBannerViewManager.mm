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

#ifndef RCT_NEW_ARCH_ENABLED
#import "RNGoogleMobileAdsPreloadedBannerViewManager.h"
#import "RNGoogleMobileAdsBannerModule.h"
#import <React/RCTView.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTEventDispatcher.h>

@interface RNGoogleMobileAdsPreloadedBannerView : RCTView

@property (nonatomic, copy) NSString *unitId;
@property (nonatomic, copy) NSString *size;
@property (nonatomic, strong) id bannerView;
@property (nonatomic, copy) RCTBubblingEventBlock onNativeEvent;
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
RCT_EXPORT_VIEW_PROPERTY(onNativeEvent, RCTBubblingEventBlock)

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
    NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Missing unitId or size");
    return;
  }
  
  NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Updating banner view for unitId: %@, size: %@", self.unitId, self.size);
  
  // Remove existing banner view
  if (self.bannerView) {
    [self.bannerView removeFromSuperview];
    self.bannerView = nil;
  }
  
  // Get the banner module and consume the preloaded ad
  RNGoogleMobileAdsBannerModule *bannerModule = [self.bridge moduleForClass:[RNGoogleMobileAdsBannerModule class]];
  
  if (!bannerModule) {
    NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Banner module not found");
    if (self.onNativeEvent) {
      self.onNativeEvent(@{
        @"type": @"onAdFailedToLoad",
        @"code": @1,
        @"message": @"Banner module not found"
      });
    }
    return;
  }
  
  @try {
    id bannerView = [bannerModule consumePreloadedAd:self.unitId size:self.size];
    if (bannerView) {
      NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Successfully consumed preloaded ad");
      self.bannerView = bannerView;
      [self addSubview:bannerView];
      
      // Send loaded event with dimensions
      if ([bannerView respondsToSelector:@selector(bounds)]) {
        CGRect bounds = [bannerView bounds];
        
        // Send event to React Native
        if (self.onNativeEvent) {
          self.onNativeEvent(@{
            @"type": @"onAdLoaded",
            @"width": @(bounds.size.width),
            @"height": @(bounds.size.height)
          });
        }
      }
    } else {
      NSLog(@"RNGoogleMobileAdsPreloadedBannerView: No preloaded ad available for unitId: %@ size: %@", self.unitId, self.size);
      // Send error event if no preloaded ad available
      if (self.onNativeEvent) {
        self.onNativeEvent(@{
          @"type": @"onAdFailedToLoad",
          @"code": @1,
          @"message": [NSString stringWithFormat:@"No preloaded ad available for unitId: %@ size: %@", self.unitId, self.size]
        });
      }
    }
  } @catch (NSException *exception) {
    NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Exception in updateBannerView: %@", exception.reason);
    if (self.onNativeEvent) {
      self.onNativeEvent(@{
        @"type": @"onAdFailedToLoad",
        @"code": @1,
        @"message": [NSString stringWithFormat:@"Exception: %@", exception.reason ?: @"Unknown error"]
      });
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

#endif // RCT_NEW_ARCH_ENABLED

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNGoogleMobileAdsPreloadedBannerView.h"
#import "RNGoogleMobileAdsBannerModule.h"
#import "RNGoogleMobileAdsCommon.h"

#import <react/renderer/components/RNGoogleMobileAdsSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNGoogleMobileAdsSpec/EventEmitters.h>
#import <react/renderer/components/RNGoogleMobileAdsSpec/Props.h>
#import <react/renderer/components/RNGoogleMobileAdsSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@interface RCTBridge (Private)
+ (RCTBridge *)currentBridge;
@end

@interface RNGoogleMobileAdsPreloadedBannerView () <RCTRNGoogleMobileAdsPreloadedBannerViewViewProtocol>
@end

@implementation RNGoogleMobileAdsPreloadedBannerView

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<RNGoogleMobileAdsPreloadedBannerViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNGoogleMobileAdsPreloadedBannerViewProps>();
    _props = defaultProps;
  }
  
  return self;
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  static const auto defaultProps = std::make_shared<const RNGoogleMobileAdsPreloadedBannerViewProps>();
  _props = defaultProps;
  
  if (_bannerView) {
    [_bannerView removeFromSuperview];
    _bannerView = nil;
  }
  _unitId = nil;
  _size = nil;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &oldViewProps =
      *std::static_pointer_cast<RNGoogleMobileAdsPreloadedBannerViewProps const>(_props);
  const auto &newViewProps =
      *std::static_pointer_cast<RNGoogleMobileAdsPreloadedBannerViewProps const>(props);
  
  BOOL shouldUpdate = false;
  
  if (oldViewProps.unitId != newViewProps.unitId) {
    _unitId = [[NSString alloc] initWithUTF8String:newViewProps.unitId.c_str()];
    shouldUpdate = true;
  }
  
  if (oldViewProps.size != newViewProps.size) {
    _size = [[NSString alloc] initWithUTF8String:newViewProps.size.c_str()];
    shouldUpdate = true;
  }
  
  if (shouldUpdate && _unitId && _size) {
    [self consumeAndDisplayAd];
  }
  
  [super updateProps:props oldProps:oldProps];
}

- (void)consumeAndDisplayAd {
  // Remove existing banner view
  if (_bannerView) {
    [_bannerView removeFromSuperview];
    _bannerView = nil;
  }
  
  // Get the banner module using the current bridge
  RCTBridge *bridge = [RCTBridge currentBridge];
  if (!bridge) {
    NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Bridge not found");
    [self emitFailedToLoadEvent:@"Bridge not found"];
    return;
  }
  
  RNGoogleMobileAdsBannerModule *bannerModule = [bridge moduleForClass:[RNGoogleMobileAdsBannerModule class]];
  
  if (!bannerModule) {
    NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Banner module not found");
    [self emitFailedToLoadEvent:@"Banner module not found"];
    return;
  }
  
  @try {
    id bannerView = [bannerModule consumePreloadedAd:_unitId size:_size];
    if (bannerView) {
      NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Successfully consumed preloaded ad");
      _bannerView = bannerView;
      [self addSubview:bannerView];
      
      // Send loaded event with dimensions
      if ([bannerView respondsToSelector:@selector(bounds)]) {
        CGRect bounds = [bannerView bounds];
        
        if (_eventEmitter != nullptr) {
          std::dynamic_pointer_cast<const facebook::react::RNGoogleMobileAdsPreloadedBannerViewEventEmitter>(
              _eventEmitter)
              ->onNativeEvent(facebook::react::RNGoogleMobileAdsPreloadedBannerViewEventEmitter::OnNativeEvent{
                  .type = "onAdLoaded",
                  .width = bounds.size.width,
                  .height = bounds.size.height});
        }
      }
    } else {
      NSLog(@"RNGoogleMobileAdsPreloadedBannerView: No preloaded ad available for unitId: %@ size: %@", _unitId, _size);
      [self emitFailedToLoadEvent:[NSString stringWithFormat:@"No preloaded ad available for unitId: %@ size: %@", _unitId, _size]];
    }
  } @catch (NSException *exception) {
    NSLog(@"RNGoogleMobileAdsPreloadedBannerView: Exception in consumeAndDisplayAd: %@", exception.reason);
    [self emitFailedToLoadEvent:[NSString stringWithFormat:@"Exception: %@", exception.reason ?: @"Unknown error"]];
  }
}

- (void)emitFailedToLoadEvent:(NSString *)message {
  if (_eventEmitter != nullptr) {
    std::dynamic_pointer_cast<const facebook::react::RNGoogleMobileAdsPreloadedBannerViewEventEmitter>(
        _eventEmitter)
        ->onNativeEvent(facebook::react::RNGoogleMobileAdsPreloadedBannerViewEventEmitter::OnNativeEvent{
            .type = "onAdFailedToLoad",
            .code = "1",
            .message = std::string([message UTF8String])});
  }
}

- (void)dealloc {
  if (_bannerView) {
    [_bannerView removeFromSuperview];
    _bannerView = nil;
  }
}

@end

#pragma mark - RNGoogleMobileAdsPreloadedBannerViewCls

Class<RCTComponentViewProtocol> RNGoogleMobileAdsPreloadedBannerViewCls(void) {
  return RNGoogleMobileAdsPreloadedBannerView.class;
}

#endif
