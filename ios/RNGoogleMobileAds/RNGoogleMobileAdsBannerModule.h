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

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <GoogleMobileAds/GoogleMobileAds.h>

@class RNGoogleMobileAdsBannerModule;

@interface PreloadedBannerHolder : NSObject <GADBannerViewDelegate, GADAdSizeDelegate>

@property (nonatomic, strong) NSString *unitId;
@property (nonatomic, strong) NSString *size;
@property (nonatomic, assign) double width;
@property (nonatomic, assign) double height;
@property (nonatomic, strong) GADBannerView *bannerView;
@property (nonatomic, copy) void (^loadedCallback)(BOOL success);
@property (nonatomic, weak) RNGoogleMobileAdsBannerModule *bannerModule;

- (instancetype)initWithUnitId:(NSString *)unitId
                         sizes:(NSArray *)sizes
                 requestOptions:(NSDictionary *)requestOptions
       manualImpressionsEnabled:(BOOL)manualImpressionsEnabled
                   loadedCallback:(void (^)(BOOL success))loadedCallback
                   bannerModule:(RNGoogleMobileAdsBannerModule *)bannerModule;

- (void)loadAd;
- (void)destroy;

@end

@interface RNGoogleMobileAdsBannerModule : RCTEventEmitter <RCTBridgeModule>

- (GADBannerView *)consumePreloadedAd:(NSString *)unitId size:(NSString *)size;

@end
