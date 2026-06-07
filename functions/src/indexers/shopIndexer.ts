import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";
import { getFirestore, GeoPoint, Timestamp } from "firebase-admin/firestore";
import { getAlgoliaClient, SHOPS_INDEX, PRODUCTS_INDEX } from "../lib/algolia";

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
      const productIndex = getAlgoliaClient().initIndex(PRODUCTS_INDEX);
      await Promise.all([
        index.deleteObject(shopId),
        shopDoc.delete(),
        productIndex.deleteBy({ filters: `shopId:${shopId}` }).catch(() => {}),
      ]);
      return;
    }

    const s = event.data.after.val() as Record<string, unknown>;
    if (!s) {
      const productIndex = getAlgoliaClient().initIndex(PRODUCTS_INDEX);
      await Promise.all([
        index.deleteObject(shopId),
        shopDoc.delete(),
        productIndex.deleteBy({ filters: `shopId:${shopId}` }).catch(() => {}),
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

    const beforeS = event.data.before.val() as Record<string, unknown> | null;
    const isNew = !event.data.before.exists();
    const geoOrStatusChanged = isNew ||
      beforeS?.latitude !== s.latitude ||
      beforeS?.longitude !== s.longitude ||
      beforeS?.isOpen !== s.isOpen ||
      beforeS?.isVerified !== s.isVerified ||
      beforeS?.name !== s.name ||
      beforeS?.shopName !== s.shopName;

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

      // Full metadata written to Firestore
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
        geo: {
          geopoint: new GeoPoint(lat, lng),
          geohash,
        },
      }),
    ]);

    // If coordinates, display status, or verification changed, cascade updates to all products in Algolia
    if (geoOrStatusChanged) {
      try {
        const productsSnap = await admin.database().ref(`/products/${shopId}`).get();
        if (productsSnap.exists()) {
          const productsMap = productsSnap.val() as Record<string, Record<string, unknown>>;
          const productIndex = getAlgoliaClient().initIndex(PRODUCTS_INDEX);
          const objectsToSave: Record<string, unknown>[] = [];
          const objectsToDelete: string[] = [];

          for (const [productId, p] of Object.entries(productsMap)) {
            const objectID = `${shopId}_${productId}`;
            if (!p || p.isActive === false) {
              objectsToDelete.push(objectID);
              continue;
            }

            // Normalize images
            let images: string[] = [];
            if (Array.isArray(p.images)) {
              images = p.images as string[];
            } else if (p.images && typeof p.images === "object") {
              images = Object.values(p.images as Record<string, string>);
            } else if (typeof p.imageUrl === "string") {
              images = [p.imageUrl];
            }

            // Normalize keywords
            let searchKeywords: string[] = [];
            if (Array.isArray(p.searchKeywords)) {
              searchKeywords = p.searchKeywords as string[];
            } else if (p.searchKeywords && typeof p.searchKeywords === "object") {
              searchKeywords = Object.values(p.searchKeywords as Record<string, string>);
            }

            objectsToSave.push({
              objectID,
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
              _geoloc: { lat, lng },
              shopName: shopName,
              shopIsOpen: Boolean(s.isOpen ?? false),
              shopIsVerified: Boolean(s.isVerified ?? false),
            });
          }

          const productSyncPromises: Promise<unknown>[] = [];
          if (objectsToSave.length > 0) {
            productSyncPromises.push(productIndex.saveObjects(objectsToSave));
          }
          if (objectsToDelete.length > 0) {
            productSyncPromises.push(productIndex.deleteObjects(objectsToDelete));
          }
          if (productSyncPromises.length > 0) {
            await Promise.all(productSyncPromises);
          }
        }
      } catch (err) {
        console.error(`Failed to cascade shop changes to products in Algolia for shop ${shopId}:`, err);
      }
    }
  }
);
