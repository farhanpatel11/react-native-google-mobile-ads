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
import android.util.Log
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
import java.util.concurrent.CountDownLatch

@ReactModule(ReactNativeGoogleMobileAdsBannerModule.NAME)
class ReactNativeGoogleMobileAdsBannerModule(
  val reactContext: ReactApplicationContext
) : NativeGoogleMobileAdsBannerModuleSpec(reactContext) {
  private val preloadedAds = HashMap<String, PreloadedBannerHolder>()

  override fun getName() = NAME

   // <-- Add this import at the top of the file

// ... inside the ReactNativeGoogleMobileAdsBannerModule class

  @ReactMethod
  override fun preload(
    adRequests: ReadableArray,
    promise: Promise
  ) {
    val results = Arguments.createArray()
    // Use a CountDownLatch to wait for all ad loading callbacks to complete
    // without blocking the thread in a busy-wait loop.
    val latch = CountDownLatch(adRequests.size())

    reactContext.runOnUiQueueThread {
      if (adRequests.size() == 0) {
        promise.resolve(results)
        return@runOnUiQueueThread
      }

      for (i in 0 until adRequests.size()) {
        val adRequest = adRequests.getMap(i)
        val unitId = adRequest.getString("unitId") ?: run {
          latch.countDown() // Decrement latch for this request and continue
          return@runOnUiQueueThread
        }
        val sizes = adRequest.getArray("sizes")
        val requestOptions = adRequest.getMap("requestOptions")
        val manualImpressionsEnabled = adRequest.getBoolean("manualImpressionsEnabled")

        val holder = PreloadedBannerHolder(unitId, sizes, requestOptions, manualImpressionsEnabled)
        holder.loadAd { success ->
          if (success) {
            // Synchronize access to preloadedAds and results to ensure thread safety,
            // as callbacks may execute concurrently.
            synchronized(this) {
              Log.d("MyAppFarhan", "preload success $unitId and size ${holder.size}")
              preloadedAds[unitId] = holder
              val result = Arguments.createMap()
              result.putString("unitId", unitId)
              result.putString("size", holder.size)
              result.putDouble("width", holder.width)
              result.putDouble("height", holder.height)
              results.pushMap(result)
            }
          }
          // Signal that this ad load has finished, regardless of success or failure.
          latch.countDown()
        }
      }
    }

    // This thread will wait here efficiently until the latch count reaches zero.
    // It is better to use a background thread for this to avoid blocking the main JS thread.
    Thread {
      try {
        latch.await() // Wait for all ad loads to complete
        promise.resolve(results)
      } catch (e: InterruptedException) {
        Thread.currentThread().interrupt()
        promise.resolve(Arguments.createArray())
        Log.d("MyAppFarhan", "preload interrupted")
        //promise.reject("E_PRELOAD_INTERRUPTED", "Ad preloading was interrupted.", e)
      }
    }.start()
  }

  @ReactMethod
  override fun destroy(unitId: String) {
    reactContext.runOnUiQueueThread {
      preloadedAds[unitId]?.destroy()
      preloadedAds.remove(unitId)
    }
  }

  override fun invalidate() {
    super.invalidate()
    reactContext.runOnUiQueueThread {
      preloadedAds.values.forEach { it.destroy() }
      preloadedAds.clear()
    }
  }

  fun getPreloadedAdView(unitId: String): BaseAdView? {
    return preloadedAds[unitId]?.adView
  }

  fun consumePreloadedAd(unitId: String): BaseAdView? {

    val holder = preloadedAds.remove(unitId)
    Log.d(
      "MyAppFarhan",
      "consumePreloadedAd $unitId and view ${holder?.adView}"
    )
    return holder?.adView
  }

  private inner class PreloadedBannerHolder(
    private val unitId: String,
    private val sizes: ReadableArray?,
    private val requestOptions: ReadableMap?,
    private val manualImpressionsEnabled: Boolean
  ) {
    private var loadedListener: ((Boolean) -> Unit)? = null
    var adView: BaseAdView? = null
      private set
    var size: String = ""
    var width: Double = 0.0
    var height: Double = 0.0

    private val adListener: AdListener = object : AdListener() {
      override fun onAdLoaded() {

        val adSize = adView?.adSize
        if (adSize != null) {
          width = adSize.width.toDouble()
          height = adSize.height.toDouble()
          Log.d("MyAppFarhan", "onAdLoaded adsize w:$width and h:$height")
        }
        loadedListener?.let { it(true) }
        emitAdEvent("loaded", Arguments.createMap().apply {
          putDouble("width", width)
          putDouble("height", height)
        })
      }

      override fun onAdFailedToLoad(loadAdError: LoadAdError) {
        loadedListener?.let { it(false) }
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
        adView.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        adView.onPaidEventListener = paidEventListener
        adView.adListener = adListener
        this.loadedListener = loadedListener

        if (adView is AdManagerAdView) {
          adView.appEventListener = appEventListener
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
              // Store the first size string as the primary size
              if (i == 0) {
                this.size = sizeString
              }
            }
          }
        }

        if (sizeList.isNotEmpty()) {
          if (adView is AdManagerAdView) {
            // Create a Java array directly
            val javaArray = sizeList.toTypedArray()
            adView.setAdSizes(*javaArray)
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
      } ?: run {
        loadedListener(false)
      }
    }

    fun destroy() {
      adView?.destroy()
      adView = null
      loadedListener = null
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
