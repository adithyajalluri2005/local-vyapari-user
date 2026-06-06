import { onValueWritten } from "firebase-functions/v2/database";
import { getAlgoliaClient, SHOPS_INDEX } from "../lib/algolia";

export const indexShop = onValueWritten(
  {
    ref: "/shop/{shopId}",
    region: "us-central1",
  },
  async (event) => {
    const { shopId } = event.params;
    const index = getAlgoliaClient().initIndex(SHOPS_INDEX);

    if (!event.data.after.exists()) {
      await index.deleteObject(shopId);
      return;
    }

    const s = event.data.after.val() as Record<string, unknown>;
    if (!s) {
      await index.deleteObject(shopId);
      return;
    }

    // Parse city the same way Shop.fromRTDB() does
    let city = (s.city as string) ?? "";
    if (!city && typeof s.address === "string" && s.address) {
      const parts = s.address.split(",").map((p: string) => p.trim());
      city = parts.length >= 3 ? parts[2] : (parts[parts.length - 1] ?? "");
    }

    await index.saveObject({
      objectID: shopId,
      // Fields must match Shop.fromRTDB() expectations
      id: shopId,
      ownerId: s.ownerId ?? "",
      name: s.name ?? s.shopName ?? "",
      shopName: s.name ?? s.shopName ?? "",
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
      // Location
      _geoloc: {
        lat: Number(s.latitude ?? 0),
        lng: Number(s.longitude ?? 0),
      },
      latitude: Number(s.latitude ?? 0),
      longitude: Number(s.longitude ?? 0),
      geohash: s.geohash ?? "",
      address: s.address ?? "",
      city,
      state: s.state ?? "",
      pincode: s.pincode ?? "",
      placeId: s.placeId ?? "",
    });
  }
);
