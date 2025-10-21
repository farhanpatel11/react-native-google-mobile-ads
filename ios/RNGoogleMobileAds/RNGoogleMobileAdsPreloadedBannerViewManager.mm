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
#import <React/RCTView.h>

@interface RNGoogleMobileAdsPreloadedBannerView : RCTView

@end

@implementation RNGoogleMobileAdsPreloadedBannerViewManager

RCT_EXPORT_MODULE(RNGoogleMobileAdsPreloadedBannerView)

- (UIView *)view {
  return [[RNGoogleMobileAdsPreloadedBannerView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(unitId, NSString)

@end

@implementation RNGoogleMobileAdsPreloadedBannerView

- (instancetype)init {
  if (self = [super init]) {
    UILabel *label = [[UILabel alloc] init];
    label.text = @"PreloadedBannerAd not implemented on iOS";
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor lightGrayColor];
    label.textColor = [UIColor darkGrayColor];
    [self addSubview:label];
    
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
      [label.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [label.widthAnchor constraintEqualToConstant:300],
      [label.heightAnchor constraintEqualToConstant:50]
    ]];
  }
  return self;
}

@end
