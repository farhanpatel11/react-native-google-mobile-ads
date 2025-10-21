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

import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import {
  PreloadedBannerAd,
  PreloadedBannerAdView,
  BannerAdSize,
  TestIds,
} from 'react-native-google-mobile-ads';

export function PreloadedBannerExample() {
  const [preloadedAds, setPreloadedAds] = useState<PreloadedBannerAd[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Preload ads during component initialization
    const preloadAds = async () => {
      try {
        const ads = await PreloadedBannerAd.preload([
          {
            unitId: TestIds.BANNER,
            sizes: [BannerAdSize.BANNER],
            requestOptions: {
              requestAgent: 'PreloadedBannerExample',
            },
          },
          {
            unitId: TestIds.BANNER,
            sizes: [BannerAdSize.LARGE_BANNER],
            requestOptions: {
              requestAgent: 'PreloadedBannerExample',
            },
          },
        ]);
        setPreloadedAds(ads);
        setLoading(false);
      } catch (error) {
        console.error('Failed to preload ads:', error);
        setLoading(false);
      }
    };

    preloadAds();

    // Cleanup on unmount
    return () => {
      preloadedAds.forEach(ad => ad.destroy());
    };
  }, []);

  if (loading) {
    return (
      <View style={styles.container}>
        <Text>Preloading ads...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Preloaded Banner Ads</Text>

      {preloadedAds.map((ad, index) => (
        <PreloadedBannerAdView
          key={`${ad.unitId}-${index}`}
          preloadedAd={ad}
          onAdLoaded={event => {
            console.log(`Ad ${index} loaded:`, event.width, 'x', event.height);
          }}
          onAdFailedToLoad={event => {
            console.error(`Ad ${index} failed to load:`, event.message);
          }}
          onAdOpened={() => {
            console.log(`Ad ${index} opened`);
          }}
          onAdClosed={() => {
            console.log(`Ad ${index} closed`);
          }}
          onAdClicked={() => {
            console.log(`Ad ${index} clicked`);
          }}
          onPaid={event => {
            console.log(`Ad ${index} paid event:`, event.value, event.currency);
          }}
          style={styles.adContainer}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  adContainer: {
    marginVertical: 10,
    backgroundColor: '#fff',
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
});
