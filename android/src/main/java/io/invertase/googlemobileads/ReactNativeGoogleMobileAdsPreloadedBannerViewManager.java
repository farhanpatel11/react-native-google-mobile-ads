package io.invertase.googlemobileads;

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

import android.util.Log;
import android.view.ViewGroup;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIManagerHelper;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.events.EventDispatcher;
import com.google.android.gms.ads.BaseAdView;

import io.invertase.googlemobileads.common.ReactNativeAdView;

import java.util.Map;

import javax.annotation.Nonnull;
import javax.annotation.Nullable;

public class ReactNativeGoogleMobileAdsPreloadedBannerViewManager
  extends SimpleViewManager<ReactNativeAdView> {
  private static final String REACT_CLASS = "RNGoogleMobileAdsPreloadedBannerView";
  private final String EVENT_AD_LOADED = "onAdLoaded";
  private final String EVENT_AD_FAILED_TO_LOAD = "onAdFailedToLoad";

  @Nonnull
  @Override
  public String getName() {
    return REACT_CLASS;
  }

  @Nonnull
  @Override
  public ReactNativeAdView createViewInstance(@Nonnull ThemedReactContext themedReactContext) {
    Log.d("MyAppFarhan", "createViewInstance");
    return new ReactNativeAdView(themedReactContext);
  }

  @Override
  public Map<String, Object> getExportedCustomDirectEventTypeConstants() {
    MapBuilder.Builder<String, Object> builder = MapBuilder.builder();
    builder.put(OnNativeEvent.EVENT_NAME, MapBuilder.of("registrationName", "onNativeEvent"));
    return builder.build();
  }

  @ReactProp(name = "unitId")
  public void setUnitId(ReactNativeAdView reactViewGroup, String unitId) {
    ReactNativeGoogleMobileAdsBannerModule bannerModule =
      ((ReactContext) reactViewGroup.getContext())
        .getNativeModule(ReactNativeGoogleMobileAdsBannerModule.class);

    Log.d("MyAppFarhan", "setUnitId " + unitId + "viewgrp" + reactViewGroup);

    if (bannerModule != null) {
      BaseAdView cachedAdView = bannerModule.consumePreloadedAd(unitId);
      Log.d("MyAppFarhan", "setUnitId banner module" + cachedAdView);
      if (cachedAdView != null) {
        // Remove any existing ad view
        BaseAdView existingAdView = getAdView(reactViewGroup);
        if (existingAdView != null) {
          existingAdView.setAdListener(null);
          if (existingAdView instanceof com.google.android.gms.ads.admanager.AdManagerAdView) {
            ((com.google.android.gms.ads.admanager.AdManagerAdView) existingAdView).setAppEventListener(null);
          }
          existingAdView.destroy();
          reactViewGroup.removeView(existingAdView);
        }

        // Add the cached ad view
        reactViewGroup.addView(cachedAdView);

        // Send loaded event with dimensions
        double width = cachedAdView.getAdSize().getWidth();
        double height = cachedAdView.getAdSize().getHeight();
        WritableMap payload = Arguments.createMap();
        Log.d("MyAppFarhan", "setUnitId adsize width "+width + "height "+height );
        payload.putDouble("width", width);
        payload.putDouble("height", height);
        sendEvent(reactViewGroup, EVENT_AD_LOADED, payload);
      } else {
        // No cached ad available, send error event
        WritableMap payload = Arguments.createMap();
        payload.putInt("code", 1); // ERROR_CODE_NO_FILL
        payload.putString("message", "No preloaded ad available for unitId: " + unitId);
        sendEvent(reactViewGroup, EVENT_AD_FAILED_TO_LOAD, payload);
      }
    }
  }

  @Override
  public void onDropViewInstance(@NonNull ReactNativeAdView reactViewGroup) {
    Log.d("MyAppFarhan", "onDropViewInstance");
    BaseAdView adView = getAdView(reactViewGroup);
    if (adView != null) {
      Log.d("MyAppFarhan", "onDropViewInstance adview!null");
      adView.setAdListener(null);
      if (adView instanceof com.google.android.gms.ads.admanager.AdManagerAdView) {
        ((com.google.android.gms.ads.admanager.AdManagerAdView) adView).setAppEventListener(null);
      }
      adView.destroy();
      reactViewGroup.removeView(adView);
    }
    super.onDropViewInstance(reactViewGroup);
  }

  @Nullable
  private BaseAdView getAdView(ViewGroup reactViewGroup) {
    BaseAdView view = (BaseAdView) reactViewGroup.getChildAt(0);
    Log.d("MyAppFarhan", "getAdView baseview" + view);
    return view;
  }

  private void sendEvent(ReactNativeAdView reactViewGroup, String type, WritableMap payload) {
    Log.d("MyAppFarhan", "sendEvent " + type);
    WritableMap event = Arguments.createMap();
    event.putString("type", type);

    if (payload != null) {
      event.merge(payload);
    }

    ThemedReactContext themedReactContext = ((ThemedReactContext) reactViewGroup.getContext());
    EventDispatcher eventDispatcher =
      UIManagerHelper.getEventDispatcherForReactTag(themedReactContext, reactViewGroup.getId());
    if (eventDispatcher != null) {
      eventDispatcher.dispatchEvent(new OnNativeEvent(reactViewGroup.getId(), event));
    }
  }
}
