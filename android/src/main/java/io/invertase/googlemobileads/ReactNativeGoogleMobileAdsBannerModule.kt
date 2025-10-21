package io.invertase.googlemobileads

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

import android.app.Activity
import android.view.ViewGroup
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdValue
import com.google.android.gms.ads.BaseAdView
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.OnPaidEventListener
import com.google.android.gms.ads.admanager.AdManagerAdView
import com.google.android.gms.ads.admanager.AppEventListener
import io.invertase.googlemobileads.common.SharedUtils
import java.util.ArrayList
import java.util.HashMap
import java.util.List

@ReactModule(ReactNativeGoogleMobileAdsBannerModule.NAME)
class ReactNativeGoogleMobileAdsBannerModule(
  reactContext: ReactApplicationContext
) : NativeGoogleMobileAdsBannerModuleSpec(reactContext) {
  private val preloadedAds = HashMap<String, PreloadedBannerHolder>()

  override fun getName() = NAME

  @ReactMethod
  override fun preload(
    adRequests: ReadableArray,
    promise: Promise
  ) {
    val results = Arguments.createArray()
    
    for (i in 0 until adRequests.size()) {
      val adRequest = adRequests.getMap(i)
      val unitId = adRequest?.getString("unitId") ?: continue
      val sizes = adRequest.getArray("sizes")
      val requestOptions = adRequest.getMap("requestOptions")
      val manualImpressionsEnabled = adRequest.getBoolean("manualImpressionsEnabled")
      
      val holder = PreloadedBannerHolder(unitId, sizes, requestOptions, manualImpressionsEnabled)
      holder.loadAd { success ->
        if (success) {
          preloadedAds[unitId] = holder
          val result = Arguments.createMap()
          result.putString("unitId", unitId)
          result.putDouble("width", holder.width)
          result.putDouble("height", holder.height)
          results.pushMap(result)
        }
      }
    }
    
    promise.resolve(results)
  }

  @ReactMethod
  override fun destroy(unitId: String) {
    preloadedAds[unitId]?.destroy()
    preloadedAds.remove(unitId)
  }

  override fun invalidate() {
    super.invalidate()
    preloadedAds.values.forEach { it.destroy() }
    preloadedAds.clear()
  }

  fun getPreloadedAdView(unitId: String): BaseAdView? {
    return preloadedAds[unitId]?.adView
  }

  fun consumePreloadedAd(unitId: String): BaseAdView? {
    val holder = preloadedAds.remove(unitId)
    return holder?.adView
  }

  private inner class PreloadedBannerHolder(
    private val unitId: String,
    private val sizes: ReadableArray?,
    private val requestOptions: ReadableMap?,
    private val manualImpressionsEnabled: Boolean
  ) {
    var adView: BaseAdView? = null
      private set
    var width: Double = 0.0
    var height: Double = 0.0

    private val adListener: AdListener = object : AdListener() {
      override fun onAdLoaded() {
        val adSize = adView?.adSize
        if (adSize != null) {
          width = adSize.width.toDouble()
          height = adSize.height.toDouble()
        }
        emitAdEvent("loaded", Arguments.createMap().apply {
          putDouble("width", width)
          putDouble("height", height)
        })
      }

      override fun onAdFailedToLoad(loadAdError: LoadAdError) {
        emitAdEvent("failed_to_load", Arguments.createMap().apply {
          putInt("code", loadAdError.code)
          putString("message", loadAdError.message)
        })
      }

      override fun onAdOpened() {
        emitAdEvent("opened", null)
      }

      override fun onAdClosed() {
        emitAdEvent("closed", null)
      }

      override fun onAdImpression() {
        emitAdEvent("impression", null)
      }

      override fun onAdClicked() {
        emitAdEvent("clicked", null)
      }
    }

    private val paidEventListener: OnPaidEventListener = OnPaidEventListener { adValue ->
      emitAdEvent("paid", Arguments.createMap().apply {
        putDouble("value", 1e-6 * adValue.valueMicros)
        putInt("precision", adValue.precisionType)
        putString("currency", adValue.currencyCode)
      })
    }

    private val appEventListener: AppEventListener = AppEventListener { name, data ->
      emitAdEvent("app_event", Arguments.createMap().apply {
        putString("name", name)
        putString("data", data)
      })
    }

    fun loadAd(loadedListener: (Boolean) -> Unit) {
      val currentActivity = reactApplicationContext.currentActivity
      if (currentActivity == null) {
        loadedListener(false)
        return
      }

      adView = if (ReactNativeGoogleMobileAdsCommon.isAdManagerUnit(unitId)) {
        AdManagerAdView(currentActivity)
      } else {
        com.google.android.gms.ads.AdView(currentActivity)
      }

      adView?.let { adView ->
        adView.setDescendantFocusability(ViewGroup.FOCUS_BLOCK_DESCENDANTS)
        adView.setOnPaidEventListener(paidEventListener)
        adView.setAdListener(adListener)

        if (adView is AdManagerAdView) {
          adView.setAppEventListener(appEventListener)
        }

        // Set ad unit ID
        adView.adUnitId = unitId

        // Handle sizes
        val sizeList = ArrayList<AdSize>()
        sizes?.let { sizesArray ->
          for (i in 0 until sizesArray.size()) {
            val sizeString = sizesArray.getString(i)
            if (sizeString != null) {
              val adSize = ReactNativeGoogleMobileAdsCommon.getAdSize(sizeString, null)
              sizeList.add(adSize)
            }
          }
        }

        if (sizeList.isNotEmpty()) {
          if (adView is AdManagerAdView) {
            adView.setAdSizes(sizeList.toTypedArray())
            if (manualImpressionsEnabled) {
              adView.setManualImpressionsEnabled(true)
            }
          } else {
            adView.setAdSize(sizeList[0])
          }
        }

        // Build and load ad request
        val adRequest = requestOptions?.let { 
          ReactNativeGoogleMobileAdsCommon.buildAdRequest(it)
        } ?: AdRequest.Builder().build()

        adView.loadAd(adRequest)
        loadedListener(true)
      } ?: run {
        loadedListener(false)
      }
    }

    fun destroy() {
      adView?.let { adView ->
        adView.setAdListener(null)
        if (adView is AdManagerAdView) {
          adView.setAppEventListener(null)
        }
        adView.destroy()
      }
      adView = null
    }

    private fun emitAdEvent(type: String, eventData: ReadableMap?) {
      val payload = Arguments.createMap()
      payload.putString("unitId", unitId)
      payload.putString("type", type)
      eventData?.let { payload.merge(it) }
      this@ReactNativeGoogleMobileAdsBannerModule.emitOnAdEvent(payload)
    }
  }

  companion object {
    const val NAME = "RNGoogleMobileAdsBannerModule"
  }
}
