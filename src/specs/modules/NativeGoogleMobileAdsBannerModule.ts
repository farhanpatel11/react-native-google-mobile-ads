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

import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { UnsafeObject, EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

export type PreloadedBannerAdRequest = {
  unitId: string;
  sizes: string[];
  requestOptions?: UnsafeObject;
  manualImpressionsEnabled?: boolean;
};

export type PreloadedBannerAdProps = {
  unitId: string;
  width: number;
  height: number;
};

export type PreloadedBannerAdEventPayload = {
  unitId: string;
  type: string;
  width?: number;
  height?: number;
  code?: number;
  message?: string;
  value?: number;
  precision?: number;
  currency?: string;
  name?: string;
  data?: string;
};

export interface Spec extends TurboModule {
  preload(adRequests: PreloadedBannerAdRequest[]): Promise<PreloadedBannerAdProps[]>;
  destroy(unitId: string): void;
  readonly onAdEvent: EventEmitter<PreloadedBannerAdEventPayload>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNGoogleMobileAdsBannerModule');
