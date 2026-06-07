import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

interface NearbyOffersRequest {
  shopIds: string[];
}

export const getNearbyOffersAggregated = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to fetch offers");
    }

    const { shopIds } = request.data as NearbyOffersRequest;
    if (!Array.isArray(shopIds) || shopIds.length === 0) {
      return { offers: [] };
    }

    // Process top 20 shops as done in the client-side repository fallback
    const targetShopIds = shopIds.slice(0, 20);
    const db = admin.database();
    const now = new Date();

    const fetchPromises = targetShopIds.map(async (shopId) => {
      const snapshot = await db.ref(`offers/${shopId}`).once("value");
      const val = snapshot.val();
      if (!val || typeof val !== "object") return [];

      const shopOffers: any[] = [];
      Object.entries(val).forEach(([offerId, rawOfferVal]) => {
        const offerVal = rawOfferVal as any;
        if (offerVal && typeof offerVal === "object" && offerVal.isActive) {
          const startDate = offerVal.startDate ? new Date(offerVal.startDate) : null;
          const endDate = offerVal.endDate ? new Date(offerVal.endDate) : null;
          
          const active = (!endDate || endDate > now) && (!startDate || startDate < now);

          if (active) {
            shopOffers.push({
              id: offerId,
              shopId: shopId,
              productId: offerVal.productId ?? "",
              ownerId: offerVal.ownerId ?? "",
              title: offerVal.title ?? "",
              description: offerVal.description ?? "",
              discountPercentage: offerVal.discountPercentage ?? 0,
              startDate: offerVal.startDate ?? null,
              endDate: offerVal.endDate ?? null,
              isActive: offerVal.isActive ?? false,
              isFeatured: offerVal.isFeatured ?? false,
              createdAt: offerVal.createdAt ?? null,
              shopName: offerVal.shopName ?? "",
            });
          }
        }
      });
      return shopOffers;
    });

    const results = await Promise.all(fetchPromises);
    const offers = results.flat();

    return { offers };
  }
);
