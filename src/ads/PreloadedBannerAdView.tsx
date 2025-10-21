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

import React, { useEffect, useRef } from 'react';
import { AdEventType } from '../AdEventType';
import { PreloadedBannerAd } from './PreloadedBannerAd';
import GoogleMobileAdsPreloadedBannerView from '../specs/components/GoogleMobileAdsPreloadedBannerViewNativeComponent';

export interface PreloadedBannerAdViewProps {
  preloadedAd: PreloadedBannerAd;
  onAdLoaded?: (event: { width: number; height: number }) => void;
  onAdFailedToLoad?: (event: { code: number; message: string }) => void;
  onAdOpened?: () => void;
  onAdClosed?: () => void;
  onAdImpression?: () => void;
  onAdClicked?: () => void;
  onPaid?: (event: { value: number; precision: number; currency: string }) => void;
  onSizeChange?: (event: { width: number; height: number }) => void;
  onAppEvent?: (event: { name: string; data: string }) => void;
}

export function PreloadedBannerAdView({
  preloadedAd,
  onAdLoaded,
  onAdFailedToLoad,
  onAdOpened,
  onAdClosed,
  onAdImpression,
  onAdClicked,
  onPaid,
  onSizeChange,
  onAppEvent,
}: PreloadedBannerAdViewProps) {
  const ref = useRef<React.ElementRef<typeof GoogleMobileAdsPreloadedBannerView>>(null);

  useEffect(() => {
    const subscriptions = [
      onAdLoaded && preloadedAd.addAdEventListener(AdEventType.LOADED, onAdLoaded),
      onAdFailedToLoad && preloadedAd.addAdEventListener(AdEventType.ERROR, onAdFailedToLoad),
      onAdOpened && preloadedAd.addAdEventListener(AdEventType.OPENED, onAdOpened),
      onAdClosed && preloadedAd.addAdEventListener(AdEventType.CLOSED, onAdClosed),
      onAdImpression && preloadedAd.addAdEventListener(AdEventType.IMPRESSION, onAdImpression),
      onAdClicked && preloadedAd.addAdEventListener(AdEventType.CLICKED, onAdClicked),
      onPaid && preloadedAd.addAdEventListener(AdEventType.PAID, onPaid),
      onSizeChange && preloadedAd.addAdEventListener(AdEventType.SIZE_CHANGE, onSizeChange),
      onAppEvent && preloadedAd.addAdEventListener(AdEventType.APP_EVENT, onAppEvent),
    ].filter(Boolean);

    return () => {
      subscriptions.forEach(subscription => subscription?.remove());
    };
  }, [
    preloadedAd,
    onAdLoaded,
    onAdFailedToLoad,
    onAdOpened,
    onAdClosed,
    onAdImpression,
    onAdClicked,
    onPaid,
    onSizeChange,
    onAppEvent,
  ]);

  return (
    <GoogleMobileAdsPreloadedBannerView
      ref={ref}
      unitId={preloadedAd.unitId}
      onNativeEvent={() => {}} // Events are handled through PreloadedBannerAd event listeners
      style={{
        width: preloadedAd.width,
        height: preloadedAd.height,
      }}
    />
  );
}
