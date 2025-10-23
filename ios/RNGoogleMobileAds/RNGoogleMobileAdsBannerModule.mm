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
#import <GoogleMobileAds/GoogleMobileAds.h>

@interface PreloadedBannerHolder : NSObject <GADBannerViewDelegate, GADAppEventDelegate>

@property (nonatomic, strong) NSString *unitId;
@property (nonatomic, strong) NSString *size;
@property (nonatomic, strong) id bannerView; // GADBannerView or GAMBannerView
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong) void (^loadedCallback)(BOOL success);
@property (nonatomic, weak) RNGoogleMobileAdsBannerModule *module;

- (void)loadAdWithSizes:(NSArray *)sizes 
         requestOptions:(NSDictionary *)requestOptions
manualImpressionsEnabled:(BOOL)manualImpressionsEnabled
             completion:(void (^)(BOOL success))completion;
- (void)destroy;

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

- (NSArray<NSString *> *)supportedEvents {
  return @[@"RNGMABannerAdEvent"];
}

RCT_EXPORT_METHOD(preload:(NSArray *)adRequests
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  if (![adRequests isKindOfClass:[NSArray class]]) {
    reject(@"INVALID_ARGUMENT", @"adRequests must be an array", nil);
    return;
  }
  
  if (adRequests.count == 0) {
    resolve(@[]);
    return;
  }
  
  dispatch_group_t group = dispatch_group_create();
  NSMutableArray *results = [[NSMutableArray alloc] init];
  NSMutableArray *holders = [[NSMutableArray alloc] init];
  
  for (NSDictionary *adRequest in adRequests) {
    NSString *unitId = adRequest[@"unitId"];
    NSArray *sizes = adRequest[@"sizes"];
    NSDictionary *requestOptions = adRequest[@"requestOptions"];
    BOOL manualImpressionsEnabled = [adRequest[@"manualImpressionsEnabled"] boolValue];
    
    if (!unitId || !sizes) {
      continue;
    }
    
    PreloadedBannerHolder *holder = [[PreloadedBannerHolder alloc] init];
    holder.unitId = unitId;
    holder.module = self;
    
    dispatch_group_enter(group);
    [holder loadAdWithSizes:sizes 
             requestOptions:requestOptions 
    manualImpressionsEnabled:manualImpressionsEnabled
                 completion:^(BOOL success) {
      if (success) {
        NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", unitId, holder.size];
        self->_preloadedAds[cacheKey] = holder;
        
        NSDictionary *result = @{
          @"unitId": unitId,
          @"size": holder.size,
          @"width": @(holder.width),
          @"height": @(holder.height)
        };
        [results addObject:result];
      }
      dispatch_group_leave(group);
    }];
    
    [holders addObject:holder];
  }
  
  dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    resolve(results);
  });
}

RCT_EXPORT_METHOD(destroy:(NSString *)unitId
                  size:(NSString *)size) {
  NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", unitId, size];
  PreloadedBannerHolder *holder = _preloadedAds[cacheKey];
  if (holder) {
    [holder destroy];
    [_preloadedAds removeObjectForKey:cacheKey];
  }
}

- (id)consumePreloadedAd:(NSString *)unitId size:(NSString *)size {
  NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", unitId, size];
  PreloadedBannerHolder *holder = _preloadedAds[cacheKey];
  if (holder) {
    id bannerView = holder.bannerView;
    [_preloadedAds removeObjectForKey:cacheKey];
    return bannerView;
  }
  return nil;
}

- (void)emitAdEvent:(NSString *)type
             unitId:(NSString *)unitId
               size:(NSString *)size
               data:(NSDictionary *)data {
  NSMutableDictionary *payload = [@{
    @"type": type,
    @"unitId": unitId,
    @"size": size
  } mutableCopy];
  
  if (data) {
    [payload addEntriesFromDictionary:data];
  }
  
  [self sendEventWithName:@"RNGMABannerAdEvent" body:payload];
}

// Add the emitOnAdEvent method that the TypeScript spec expects
- (void)emitOnAdEvent:(NSDictionary *)payload {
  [self sendEventWithName:@"RNGMABannerAdEvent" body:payload];
}

@end

@implementation PreloadedBannerHolder

- (instancetype)init {
  if (self = [super init]) {
    _width = 0;
    _height = 0;
  }
  return self;
}

- (void)loadAdWithSizes:(NSArray *)sizes 
         requestOptions:(NSDictionary *)requestOptions
manualImpressionsEnabled:(BOOL)manualImpressionsEnabled
             completion:(void (^)(BOOL success))completion {
  self.loadedCallback = completion;
  
  if (sizes.count == 0) {
    completion(NO);
    return;
  }
  
  // Use first size as primary size
  NSString *sizeString = sizes[0];
  GADAdSize adSize = [RNGoogleMobileAdsCommon stringToAdSize:sizeString withMaxHeight:-1 andWidth:-1];
  
  if (GADAdSizeEqualToSize(adSize, GADAdSizeInvalid)) {
    completion(NO);
    return;
  }
  
  self.size = sizeString;
  
  // Create banner view
  if ([RNGoogleMobileAdsCommon isAdManagerUnit:self.unitId]) {
    GAMBannerView *banner = [[GAMBannerView alloc] initWithAdSize:adSize];
    banner.validAdSizes = [self convertSizesToGADAdSizeArray:sizes];
    banner.appEventDelegate = self;
    banner.enableManualImpressions = manualImpressionsEnabled;
    self.bannerView = banner;
  } else {
    GADBannerView *banner = [[GADBannerView alloc] initWithAdSize:adSize];
    self.bannerView = banner;
  }
  
  GADBannerView *banner = (GADBannerView *)self.bannerView;
  banner.delegate = self;
  banner.adUnitID = self.unitId;
  banner.rootViewController = [RNGoogleMobileAdsCommon currentViewController];
  
  // Set up paid event handler
  banner.paidEventHandler = ^(GADAdValue *value) {
    NSDictionary *payload = @{
      @"type": @"paid",
      @"unitId": self.unitId,
      @"size": self.size,
      @"value": @(value.value.doubleValue),
      @"precision": @(value.precision),
      @"currency": value.currencyCode
    };
    [self.module emitOnAdEvent:payload];
  };
  
  // Build and load request
  GAMRequest *request = [RNGoogleMobileAdsCommon buildAdRequest:requestOptions ?: @{}];
  [banner loadRequest:request];
}

- (NSArray *)convertSizesToGADAdSizeArray:(NSArray *)sizes {
  NSMutableArray *adSizes = [[NSMutableArray alloc] init];
  for (NSString *sizeString in sizes) {
    GADAdSize adSize = [RNGoogleMobileAdsCommon stringToAdSize:sizeString withMaxHeight:-1 andWidth:-1];
    if (!GADAdSizeEqualToSize(adSize, GADAdSizeInvalid)) {
      [adSizes addObject:NSValueFromGADAdSize(adSize)];
    }
  }
  return adSizes;
}

- (void)destroy {
  if (self.bannerView) {
    GADBannerView *banner = (GADBannerView *)self.bannerView;
    banner.delegate = nil;
    if ([banner isKindOfClass:[GAMBannerView class]]) {
      ((GAMBannerView *)banner).appEventDelegate = nil;
    }
    [banner removeFromSuperview];
    self.bannerView = nil;
  }
  self.loadedCallback = nil;
}

#pragma mark - GADBannerViewDelegate

- (void)bannerViewDidReceiveAd:(GADBannerView *)bannerView {
  self.width = bannerView.bounds.size.width;
  self.height = bannerView.bounds.size.height;
  
  NSMutableDictionary *payload = [@{
    @"type": @"loaded",
    @"unitId": self.unitId,
    @"size": self.size,
    @"width": @(self.width),
    @"height": @(self.height)
  } mutableCopy];
  [self.module emitOnAdEvent:payload];
  
  if (self.loadedCallback) {
    self.loadedCallback(YES);
  }
}

- (void)bannerView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(NSError *)error {
  NSDictionary *errorData = [RNGoogleMobileAdsCommon getCodeAndMessageFromAdError:error];
  NSMutableDictionary *payload = [@{
    @"type": @"failed_to_load",
    @"unitId": self.unitId,
    @"size": self.size
  } mutableCopy];
  [payload addEntriesFromDictionary:errorData];
  [self.module emitOnAdEvent:payload];
  
  if (self.loadedCallback) {
    self.loadedCallback(NO);
  }
}

- (void)bannerViewWillPresentScreen:(GADBannerView *)bannerView {
  NSDictionary *payload = @{
    @"type": @"opened",
    @"unitId": self.unitId,
    @"size": self.size
  };
  [self.module emitOnAdEvent:payload];
}

- (void)bannerViewDidDismissScreen:(GADBannerView *)bannerView {
  NSDictionary *payload = @{
    @"type": @"closed",
    @"unitId": self.unitId,
    @"size": self.size
  };
  [self.module emitOnAdEvent:payload];
}

- (void)bannerViewDidRecordImpression:(GADBannerView *)bannerView {
  NSDictionary *payload = @{
    @"type": @"impression",
    @"unitId": self.unitId,
    @"size": self.size
  };
  [self.module emitOnAdEvent:payload];
}

- (void)bannerViewDidRecordClick:(GADBannerView *)bannerView {
  NSDictionary *payload = @{
    @"type": @"clicked",
    @"unitId": self.unitId,
    @"size": self.size
  };
  [self.module emitOnAdEvent:payload];
}

#pragma mark - GADAppEventDelegate

- (void)adView:(nonnull GADBannerView *)banner didReceiveAppEvent:(nonnull NSString *)name withInfo:(nullable NSString *)info {
  NSDictionary *payload = @{
    @"type": @"app_event",
    @"unitId": self.unitId,
    @"size": self.size,
    @"name": name,
    @"data": info ?: @""
  };
  [self.module emitOnAdEvent:payload];
}

@end
