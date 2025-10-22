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

import { ViewStyle } from 'react-native';
import { PreloadedBannerAd } from '../ads/PreloadedBannerAd';

export interface PreloadedBannerAdViewProps {
  preloadedAd: PreloadedBannerAd;
  style?: ViewStyle;
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

export interface PreloadedBannerAdRequest {
  unitId: string;
  sizes: string[];
  requestOptions?: Record<string, unknown>;
  manualImpressionsEnabled?: boolean;
}
