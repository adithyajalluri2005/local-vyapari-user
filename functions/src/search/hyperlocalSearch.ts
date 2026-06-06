import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAlgoliaClient, PRODUCTS_INDEX, SHOPS_INDEX } from "../lib/algolia";

interface SearchRequest {
  query?: string;
  category?: string;
  latitude: number;
  longitude: number;
  radiusKm?: number;
}

export const hyperlocalSearch = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to search");
    }

    const {
      query = "",
      category,
      latitude,
      longitude,
      radiusKm = 15,
    } = request.data as SearchRequest;

    if (typeof latitude !== "number" || typeof longitude !== "number") {
      throw new HttpsError("invalid-argument", "latitude and longitude are required numbers");
    }

    const aroundLatLng = `${latitude},${longitude}`;
    const aroundRadius = Math.round(Math.min(radiusKm, 50) * 1000); // cap at 50 km, convert to metres

    // Product filter: active + in-stock; add category when provided
    const productFilters = category
      ? `isActive:true AND isOutOfStock:false AND category:"${category}"`
      : "isActive:true AND isOutOfStock:false";

    const client = getAlgoliaClient();
    const { results } = await client.multipleQueries([
      {
        indexName: PRODUCTS_INDEX,
        query,
        params: {
          aroundLatLng,
          aroundRadius,
          filters: productFilters,
          hitsPerPage: 30,
          attributesToRetrieve: [
            "id", "shopId", "ownerId",
            "name", "description", "category", "searchKeywords",
            "actualPrice", "offerPrice", "stockQuantity",
            "isActive", "isOutOfStock", "isLowStock",
            "images", "avgRating", "totalReviews", "createdAt",
            "shopName", "shopIsOpen", "shopIsVerified",
          ],
        },
      },
      {
        indexName: SHOPS_INDEX,
        query,
        params: {
          aroundLatLng,
          aroundRadius,
          hitsPerPage: 10,
          attributesToRetrieve: [
            "id", "ownerId",
            "name", "shopName", "description", "phone",
            "logoUrl", "bannerUrl",
            "isOpen", "isVerified", "openingTime", "closingTime",
            "rating", "totalReviews", "createdAt",
            "latitude", "longitude", "geohash",
            "address", "city", "state", "pincode", "placeId",
            "_geoloc",
          ],
        },
      },
    ]);

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const productHits = (results[0] as any).hits as Record<string, unknown>[];
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const shopHits = (results[1] as any).hits as Record<string, unknown>[];

    // Shape must satisfy Product.fromRTDB() and Shop.fromRTDB() in the Flutter client
    const products = productHits.map((h) => ({
      id: h.id ?? h.objectID,
      shopId: h.shopId,
      ownerId: h.ownerId,
      name: h.name,
      description: h.description,
      category: h.category,
      searchKeywords: h.searchKeywords ?? [],
      actualPrice: h.actualPrice,
      offerPrice: h.offerPrice,
      stockQuantity: h.stockQuantity ?? 0,
      isActive: h.isActive,
      isOutOfStock: h.isOutOfStock,
      isLowStock: h.isLowStock,
      images: h.images ?? [],
      avgRating: h.avgRating ?? 0,
      totalReviews: h.totalReviews ?? 0,
      createdAt: h.createdAt ?? null,
      shopName: h.shopName,
      shopIsOpen: h.shopIsOpen,
      shopIsVerified: h.shopIsVerified,
    }));

    const shops = shopHits.map((h) => {
      const geoloc = h._geoloc as { lat: number; lng: number } | undefined;
      return {
        id: h.id ?? h.objectID,
        ownerId: h.ownerId,
        name: h.name ?? h.shopName,
        shopName: h.name ?? h.shopName,
        description: h.description,
        phone: h.phone,
        logoUrl: h.logoUrl ?? "",
        bannerUrl: h.bannerUrl ?? "",
        isOpen: h.isOpen,
        isVerified: h.isVerified,
        openingTime: h.openingTime ?? null,
        closingTime: h.closingTime ?? null,
        rating: h.rating ?? 0,
        totalReviews: h.totalReviews ?? 0,
        createdAt: h.createdAt ?? null,
        latitude: h.latitude ?? geoloc?.lat ?? 0,
        longitude: h.longitude ?? geoloc?.lng ?? 0,
        geohash: h.geohash ?? "",
        address: h.address ?? "",
        city: h.city ?? "",
        state: h.state ?? "",
        pincode: h.pincode ?? "",
        placeId: h.placeId ?? "",
      };
    });

    return {
      products,
      shops,
      isCapped: shopHits.length >= 10,
    };
  }
);
