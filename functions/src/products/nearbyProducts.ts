import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

interface NearbyProductsRequest {
  shopIds: string[];
}

export const getNearbyProductsAggregated = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to fetch products");
    }

    const { shopIds } = request.data as NearbyProductsRequest;
    if (!Array.isArray(shopIds) || shopIds.length === 0) {
      return { products: [] };
    }

    // Restrict processing to the top 15 shops to optimize database reads
    const targetShopIds = shopIds.slice(0, 15);
    const db = admin.database();

    const fetchPromises = targetShopIds.map(async (shopId) => {
      const snapshot = await db.ref(`products/${shopId}`).once("value");
      const val = snapshot.val();
      if (!val || typeof val !== "object") return [];

      const shopProducts: any[] = [];
      Object.entries(val).forEach(([productId, rawProductVal]) => {
        const productVal = rawProductVal as any;
        if (productVal && typeof productVal === "object" && productVal.isActive && !productVal.isOutOfStock) {
          shopProducts.push({
            id: productId,
            shopId: shopId,
            ownerId: productVal.ownerId ?? "",
            name: productVal.name ?? "",
            description: productVal.description ?? "",
            category: productVal.category ?? "",
            searchKeywords: productVal.searchKeywords ?? [],
            actualPrice: productVal.actualPrice ?? 0,
            offerPrice: productVal.offerPrice ?? 0,
            stockQuantity: productVal.stockQuantity ?? 0,
            isActive: productVal.isActive ?? false,
            isOutOfStock: productVal.isOutOfStock ?? false,
            isLowStock: productVal.isLowStock ?? false,
            images: productVal.images ?? [],
            avgRating: productVal.avgRating ?? 0,
            totalReviews: productVal.totalReviews ?? 0,
            createdAt: productVal.createdAt ?? null,
            shopName: productVal.shopName ?? "",
            shopIsOpen: productVal.shopIsOpen ?? false,
            shopIsVerified: productVal.shopIsVerified ?? false,
          });
        }
      });
      return shopProducts;
    });

    const results = await Promise.all(fetchPromises);
    const products = results.flat();

    return { products };
  }
);
