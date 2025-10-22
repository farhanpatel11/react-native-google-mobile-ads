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

import { EventSubscription, NativeEventEmitter, Platform } from 'react-native';
import EventEmitter from 'react-native/Libraries/vendor/emitter/EventEmitter';

import { AdEventType } from '../AdEventType';
import { isFunction, isOneOf, isString } from '../common';
import NativeGoogleMobileAdsBannerModule, {
  PreloadedBannerAdEventPayload,
  PreloadedBannerAdProps,
  PreloadedBannerAdRequest,
} from '../specs/modules/NativeGoogleMobileAdsBannerModule';
import { validateAdRequestOptions } from '../validateAdRequestOptions';

type PreloadedBannerAdListenerPayload<EventType extends AdEventType> =
  EventType extends AdEventType.PAID
    ? { value: number; precision: number; currency: string }
    : never;

/**
 * A class for preloading Banner Ads.
 */
export class PreloadedBannerAd {
  readonly unitId: string;
  readonly size: string;
  readonly width: number;
  readonly height: number;

  private nativeEventSubscription: EventSubscription;
  private eventEmitter: EventEmitter;

  private constructor(props: PreloadedBannerAdProps) {
    this.unitId = props.unitId;
    this.size = props.size;
    this.width = props.width;
    this.height = props.height;

    if ('onAdEvent' in NativeGoogleMobileAdsBannerModule) {
      this.nativeEventSubscription = NativeGoogleMobileAdsBannerModule.onAdEvent(
        this.onPreloadedBannerAdEvent.bind(this),
      );
    } else {
      let eventEmitter;
      if (Platform.OS === 'ios') {
        eventEmitter = new NativeEventEmitter(NativeGoogleMobileAdsBannerModule);
      } else {
        eventEmitter = new NativeEventEmitter();
      }
      this.nativeEventSubscription = eventEmitter.addListener(
        'RNGMABannerAdEvent',
        this.onPreloadedBannerAdEvent.bind(this),
      );
    }
    this.eventEmitter = new EventEmitter();
  }

  private onPreloadedBannerAdEvent({ unitId, size, type, ...data }: PreloadedBannerAdEventPayload) {
    if (this.unitId !== unitId || this.size !== size) {
      return;
    }
    console.log('onPreloadedBannerAdEvent', unitId, size, type, data);
    this.eventEmitter.emit(type, data);
  }

  addAdEventListener<EventType extends AdEventType>(
    type: EventType,
    listener: (payload: PreloadedBannerAdListenerPayload<EventType>) => void,
  ) {
    if (!isOneOf(type, Object.values(AdEventType))) {
      throw new Error(
        `PreloadedBannerAd.addAdEventListener(*) 'type' expected a valid event type value.`,
      );
    }
    if (!isFunction(listener)) {
      throw new Error(`PreloadedBannerAd.addAdEventListener(_, *) 'listener' expected a function.`);
    }

    return this.eventEmitter.addListener(type, listener);
  }

  removeAllAdEventListeners() {
    this.eventEmitter.removeAllListeners();
  }

  destroy() {
    NativeGoogleMobileAdsBannerModule.destroy(this.unitId, this.size);
    this.nativeEventSubscription.remove();
    this.removeAllAdEventListeners();
  }

  /**
   * Preloads banner ads for later instant display.
   *
   * #### Example
   *
   * ```js
   * import { PreloadedBannerAd, BannerAdSize, TestIds } from 'react-native-google-mobile-ads';
   *
   * const preloadedAds = await PreloadedBannerAd.preload([
   *   {
   *     unitId: TestIds.BANNER,
   *     sizes: [BannerAdSize.BANNER],
   *     requestOptions: {
   *       requestAgent: 'CoolAds',
   *     }
   *   }
   * ]);
   * ```
   *
   * @param adRequests Array of ad requests to preload
   */
  static async preload(adRequests: PreloadedBannerAdRequest[]): Promise<PreloadedBannerAd[]> {
    if (!Array.isArray(adRequests)) {
      throw new Error("PreloadedBannerAd.preload(*) 'adRequests' expected an array.");
    }

    const validatedRequests: PreloadedBannerAdRequest[] = [];

    for (const request of adRequests) {
      if (!isString(request.unitId)) {
        throw new Error("PreloadedBannerAd.preload(*) 'unitId' expected a string value.");
      }

      if (!Array.isArray(request.sizes)) {
        throw new Error("PreloadedBannerAd.preload(*) 'sizes' expected an array.");
      }

      let options = {};
      try {
        options = validateAdRequestOptions(request.requestOptions);
      } catch (e) {
        if (e instanceof Error) {
          throw new Error(`PreloadedBannerAd.preload(*) ${e.message}.`);
        }
      }

      validatedRequests.push({
        unitId: request.unitId,
        sizes: request.sizes,
        requestOptions: options,
        manualImpressionsEnabled: request.manualImpressionsEnabled || false,
      });
    }

    const props = await NativeGoogleMobileAdsBannerModule.preload(validatedRequests);
    console.log('Preloaded ads:', props);
    return props.map(prop => new PreloadedBannerAd(prop));
  }
}
