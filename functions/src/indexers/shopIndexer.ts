import { onValueWritten } from "firebase-functions/v2/database";
import { getFirestore, GeoPoint, Timestamp } from "firebase-admin/firestore";
import { getAlgoliaClient, SHOPS_INDEX } from "../lib/algolia";

export const indexShop = onValueWritten(
  {
    ref: "/shop/{shopId}",
    region: "us-central1",
  },
  async (event) => {
    const { shopId } = event.params;
    const index = getAlgoliaClient().initIndex(SHOPS_INDEX);
    const shopDoc = getFirestore().collection("searchable_shops").doc(shopId);

    if (!event.data.after.exists()) {
      await Promise.all([
        index.deleteObject(shopId),
        shopDoc.delete(),
      ]);
      return;
    }

    const s = event.data.after.val() as Record<string, unknown>;
    if (!s) {
      await Promise.all([
        index.deleteObject(shopId),
        shopDoc.delete(),
      ]);
      return;
    }

    // Parse city the same way Shop.fromRTDB() does
    let city = (s.city as string) ?? "";
    if (!city && typeof s.address === "string" && s.address) {
      const parts = s.address.split(",").map((p: string) => p.trim());
      city = parts.length >= 3 ? parts[2] : (parts[parts.length - 1] ?? "");
    }

    const lat = Number(s.latitude ?? 0);
    const lng = Number(s.longitude ?? 0);
    const geohash = (s.geohash as string) ?? "";
    const shopName = String(s.name ?? s.shopName ?? "");

    // Run Algolia and Firestore writes in parallel.
    await Promise.all([
      index.saveObject({
        objectID: shopId,
        id: shopId,
        ownerId: s.ownerId ?? "",
        name: shopName,
        shopName,
        description: s.description ?? "",
        phone: s.phone ?? "",
        logoUrl: s.logoUrl ?? s.shopLogo ?? "",
        bannerUrl: s.bannerUrl ?? s.shopBanner ?? "",
        isOpen: Boolean(s.isOpen ?? false),
        isVerified: Boolean(s.isVerified ?? false),
        openingTime: s.openingTime ?? null,
        closingTime: s.closingTime ?? null,
        rating: Number(s.rating ?? 0),
        totalReviews: Number(s.totalReviews ?? 0),
        createdAt: s.createdAt ?? null,
        _geoloc: { lat, lng },
        latitude: lat,
        longitude: lng,
        geohash,
        address: s.address ?? "",
        city,
        state: s.state ?? "",
        pincode: s.pincode ?? "",
        placeId: s.placeId ?? "",
      }),

      // Full metadata written to Firestore so the customer app can drive the
      // home-feed from a single geoRef.within() stream instead of 1 Firestore
      // geo-query + N individual RTDB onValue listeners.
      shopDoc.set({
        shopName,
        ownerId: String(s.ownerId ?? ""),
        description: String(s.description ?? ""),
        phone: String(s.phone ?? ""),
        shopLogo: String(s.logoUrl ?? s.shopLogo ?? ""),
        shopBanner: String(s.bannerUrl ?? s.shopBanner ?? ""),
        isVerified: Boolean(s.isVerified ?? false),
        isOpen: Boolean(s.isOpen ?? false),
        openingTime: (s.openingTime as string) ?? null,
        closingTime: (s.closingTime as string) ?? null,
        rating: Number(s.rating ?? 0),
        totalReviews: Number(s.totalReviews ?? 0),
        // Convert RTDB integer timestamp to a Firestore Timestamp so
        // Shop.fromFirestore can cast it with (data['createdAt'] as Timestamp?)
        createdAt: s.createdAt != null
          ? Timestamp.fromMillis(Number(s.createdAt))
          : null,
        location: {
          latitude: lat,
          longitude: lng,
          geohash,
          address: String(s.address ?? ""),
          city,
          state: String(s.state ?? ""),
          pincode: String(s.pincode ?? ""),
          placeId: String(s.placeId ?? ""),
        },
        // geo field consumed by geoflutterfire_plus for radius queries
        geo: {
          geopoint: new GeoPoint(lat, lng),
          geohash,
        },
      }),
    ]);
  }
);
