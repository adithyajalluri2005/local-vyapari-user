import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";
import { getAlgoliaClient, PRODUCTS_INDEX } from "../lib/algolia";

export const indexProduct = onValueWritten(
  {
    ref: "/products/{shopId}/{productId}",
    region: "us-central1",
  },
  async (event) => {
    const { shopId, productId } = event.params;
    const objectID = `${shopId}_${productId}`;
    const index = getAlgoliaClient().initIndex(PRODUCTS_INDEX);

    if (!event.data.after.exists()) {
      await index.deleteObject(objectID);
      return;
    }

    const p = event.data.after.val() as Record<string, unknown>;
    if (!p || p.isActive === false) {
      await index.deleteObject(objectID);
      return;
    }

    // Fetch shop to get geo coordinates
    const shopSnap = await admin.database().ref(`/shop/${shopId}`).get();
    const shop = shopSnap.val() as Record<string, unknown> | null;

    const lat = Number(shop?.latitude ?? 0);
    const lng = Number(shop?.longitude ?? 0);

    // Normalize images (RTDB can store as array or keyed map)
    let images: string[] = [];
    if (Array.isArray(p.images)) {
      images = p.images as string[];
    } else if (p.images && typeof p.images === "object") {
      images = Object.values(p.images as Record<string, string>);
    } else if (typeof p.imageUrl === "string") {
      images = [p.imageUrl];
    }

    // Normalize searchKeywords
    let searchKeywords: string[] = [];
    if (Array.isArray(p.searchKeywords)) {
      searchKeywords = p.searchKeywords as string[];
    } else if (p.searchKeywords && typeof p.searchKeywords === "object") {
      searchKeywords = Object.values(p.searchKeywords as Record<string, string>);
    }

    await index.saveObject({
      objectID,
      // Fields returned to Flutter — must match Product.fromRTDB() expectations
      id: productId,
      shopId,
      ownerId: p.ownerId ?? p.vendorId ?? "",
      name: p.name ?? "",
      description: p.description ?? "",
      category: p.category ?? "",
      searchKeywords,
      actualPrice: Number(p.actualPrice ?? p.price ?? 0),
      offerPrice: Number(p.offerPrice ?? p.price ?? 0),
      stockQuantity: Number(p.stockQuantity ?? 0),
      isActive: Boolean(p.isActive ?? true),
      isOutOfStock: Boolean(p.isOutOfStock ?? false),
      isLowStock: Boolean(p.isLowStock ?? false),
      images,
      avgRating: Number(p.avgRating ?? p.rating ?? 0),
      totalReviews: Number(p.totalRatings ?? p.totalReviews ?? 0),
      createdAt: p.createdAt ?? null,
      // Geo — Algolia special field for geo-distance ranking
      _geoloc: { lat, lng },
      // Denormalised shop fields for display without extra fetch
      shopName: (shop?.name ?? shop?.shopName ?? "") as string,
      shopIsOpen: Boolean(shop?.isOpen ?? false),
      shopIsVerified: Boolean(shop?.isVerified ?? false),
    });
  }
);
