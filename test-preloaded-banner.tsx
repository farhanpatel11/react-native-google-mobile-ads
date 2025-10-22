import React, { useState } from 'react';
import { View, Button, Text } from 'react-native';
import { PreloadedBannerAd, PreloadedBannerAdView, BannerAdSize, TestIds } from './src';

export function TestPreloadedBanner() {
  const [preloadedAds, setPreloadedAds] = useState<PreloadedBannerAd[]>([]);
  const [loading, setLoading] = useState(false);

  const preloadAds = async () => {
    console.log('Preloading ads test...', PreloadedBannerAd);
    setLoading(true);
    try {
      const ads = await PreloadedBannerAd.preload([
        {
          unitId: TestIds.BANNER,
          sizes: [BannerAdSize.BANNER],
          requestOptions: {
            requestNonPersonalizedAdsOnly: true,
          },
        },
      ]);
      console.log('Preloaded ads finished:', ads);
      setPreloadedAds(ads);
    } catch (e) {
      console.error('Preload error:', e);
    } finally {
      setLoading(false);
    }
  };

  const destroyAds = () => {
    preloadedAds.forEach(ad => ad.destroy());
    setPreloadedAds([]);
  };

  console.log('PreloadedBannerAd test', PreloadedBannerAd);

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 18, fontWeight: 'bold', marginBottom: 10 }}>
        Preloaded Banner Ads Test
      </Text>

      <Button
        title={loading ? 'Preloading...' : 'Preload Ads'}
        disabled={loading}
        onPress={preloadAds}
      />

      <Button title="Destroy All Ads" disabled={preloadedAds.length === 0} onPress={destroyAds} />

      <Text>Preloaded: {preloadedAds.length} ads</Text>

      {preloadedAds.map((ad, index) => (
        <View
          key={`${ad.unitId}-${index}`}
          style={{ marginVertical: 10, padding: 10, backgroundColor: '#f0f0f0', borderRadius: 5 }}
        >
          <Text>
            Ad {index + 1}: {ad.size} ({ad.width}x{ad.height})
          </Text>
          <PreloadedBannerAdView
            preloadedAd={ad}
            onAdLoaded={event => {
              console.log(`Ad ${index} loaded:`, event.width, 'x', event.height);
            }}
            onAdFailedToLoad={event => {
              console.error(`Ad ${index} failed:`, event.message);
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
              console.log(`Ad ${index} paid:`, event.value, event.currency);
            }}
            style={{
              backgroundColor: '#fff',
              borderRadius: 4,
              marginTop: 5,
            }}
          />
        </View>
      ))}
    </View>
  );
}
