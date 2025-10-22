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

#import "RNGoogleMobileAdsBannerModule.h"
#import "RNGoogleMobileAdsCommon.h"

@implementation PreloadedBannerHolder

- (instancetype)initWithUnitId:(NSString *)unitId
                         sizes:(NSArray *)sizes
                 requestOptions:(NSDictionary *)requestOptions
       manualImpressionsEnabled:(BOOL)manualImpressionsEnabled
                   loadedCallback:(void (^)(BOOL success))loadedCallback
                   bannerModule:(RNGoogleMobileAdsBannerModule *)bannerModule {
  if (self = [super init]) {
    _unitId = unitId;
    _loadedCallback = loadedCallback;
    _bannerModule = bannerModule;
    
    // Use the first size as the primary size
    if (sizes.count > 0) {
      _size = sizes[0];
    }
    
    // Create banner view
    GADAdSize adSize = [RNGoogleMobileAdsCommon stringToAdSize:_size withMaxHeight:-1 andWidth:-1];
    _bannerView = [[GADBannerView alloc] initWithAdSize:adSize];
    _bannerView.delegate = self;
    _bannerView.adUnitID = unitId;
    _bannerView.rootViewController = [RNGoogleMobileAdsCommon currentViewController];
    
    // Set up paid event handler
    __weak PreloadedBannerHolder *weakSelf = self;
    _bannerView.paidEventHandler = ^(GADAdValue *_Nonnull value) {
      PreloadedBannerHolder *strongSelf = weakSelf;
      if (strongSelf) {
        [strongSelf emitEvent:@"paid" data:@{
          @"value": @(value.value.doubleValue),
          @"precision": @(value.precision),
          @"currency": value.currencyCode
        }];
      }
    };
    
    // Build and load ad request
    GAMRequest *request = [RNGoogleMobileAdsCommon buildAdRequest:requestOptions];
    [_bannerView loadRequest:request];
  }
  return self;
}

- (void)loadAd {
  // Ad loading is handled in init
}

- (void)destroy {
  _bannerView.delegate = nil;
  _bannerView = nil;
  _loadedCallback = nil;
}

- (void)emitEvent:(NSString *)type data:(NSDictionary *)data {
  NSMutableDictionary *payload = [@{
    @"unitId": _unitId,
    @"size": _size,
    @"type": type
  } mutableCopy];
  
  if (data) {
    [payload addEntriesFromDictionary:data];
  }
  
  // Use the banner module instance to emit the event
  if (_bannerModule) {
    [_bannerModule sendEventWithName:@"RNGMABannerAdEvent" body:payload];
  }
}

#pragma mark - GADBannerViewDelegate

- (void)bannerViewDidReceiveAd:(GADBannerView *)bannerView {
  _width = bannerView.bounds.size.width;
  _height = bannerView.bounds.size.height;
  
  [self emitEvent:@"loaded" data:@{
    @"width": @(_width),
    @"height": @(_height)
  }];
  
  if (_loadedCallback) {
    _loadedCallback(YES);
  }
}

- (void)bannerView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(NSError *)error {
  NSDictionary *errorData = [RNGoogleMobileAdsCommon getCodeAndMessageFromAdError:error];
  [self emitEvent:@"failed_to_load" data:errorData];
  
  if (_loadedCallback) {
    _loadedCallback(NO);
  }
}

- (void)bannerViewWillPresentScreen:(GADBannerView *)bannerView {
  [self emitEvent:@"opened" data:nil];
}

- (void)bannerViewDidDismissScreen:(GADBannerView *)bannerView {
  [self emitEvent:@"closed" data:nil];
}

- (void)bannerViewDidRecordImpression:(GADBannerView *)bannerView {
  [self emitEvent:@"impression" data:nil];
}

- (void)bannerViewDidRecordClick:(GADBannerView *)bannerView {
  [self emitEvent:@"clicked" data:nil];
}

@end

@implementation RNGoogleMobileAdsBannerModule {
  NSMutableDictionary *_preloadedAds;
}

RCT_EXPORT_MODULE()

- (instancetype)init {
  if (self = [super init]) {
    _preloadedAds = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  // Clean up all preloaded ads
  for (PreloadedBannerHolder *holder in _preloadedAds.allValues) {
    [holder destroy];
  }
  [_preloadedAds removeAllObjects];
}

- (NSArray<NSString *> *)supportedEvents {
  return @[@"RNGMABannerAdEvent"];
}

RCT_EXPORT_METHOD(preload:(NSArray *)adRequests
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  
  if (adRequests.count == 0) {
    resolve(@[]);
    return;
  }
  
  dispatch_group_t group = dispatch_group_create();
  NSMutableArray *results = [[NSMutableArray alloc] init];
  NSMutableArray *errors = [[NSMutableArray alloc] init];
  
  for (NSDictionary *adRequest in adRequests) {
    NSString *unitId = adRequest[@"unitId"];
    NSArray *sizes = adRequest[@"sizes"];
    NSDictionary *requestOptions = adRequest[@"requestOptions"];
    BOOL manualImpressionsEnabled = [adRequest[@"manualImpressionsEnabled"] boolValue];
    
    if (!unitId || !sizes || sizes.count == 0) {
      continue;
    }
    
    dispatch_group_enter(group);
    
    PreloadedBannerHolder *holder = [[PreloadedBannerHolder alloc] initWithUnitId:unitId
                                                                           sizes:sizes
                                                                   requestOptions:requestOptions
                                                         manualImpressionsEnabled:manualImpressionsEnabled
                                                                   loadedCallback:^(BOOL success) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (success) {
          NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", unitId, holder.size];
          _preloadedAds[cacheKey] = holder;
          
          NSDictionary *result = @{
            @"unitId": unitId,
            @"size": holder.size,
            @"width": @(holder.width),
            @"height": @(holder.height)
          };
          [results addObject:result];
        } else {
          [errors addObject:[NSString stringWithFormat:@"Failed to load ad for unitId: %@", unitId]];
        }
        dispatch_group_leave(group);
      });
    }
                                                                   bannerModule:self];
  }
  
  dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    resolve(results);
  });
}

RCT_EXPORT_METHOD(destroy:(NSString *)unitId size:(NSString *)size) {
  NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", unitId, size];
  PreloadedBannerHolder *holder = _preloadedAds[cacheKey];
  if (holder) {
    [holder destroy];
    [_preloadedAds removeObjectForKey:cacheKey];
  }
}

- (GADBannerView *)consumePreloadedAd:(NSString *)unitId size:(NSString *)size {
  NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", unitId, size];
  PreloadedBannerHolder *holder = _preloadedAds[cacheKey];
  if (holder) {
    GADBannerView *bannerView = holder.bannerView;
    [_preloadedAds removeObjectForKey:cacheKey];
    return bannerView;
  }
  return nil;
}

@end
