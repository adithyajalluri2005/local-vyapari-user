/**
 * One-time backfill script — reads all shops and products from RTDB
 * and indexes them into Algolia AND Firestore (searchable_shops collection).
 *
 * Usage:
 *   cd functions
 *   npx ts-node scripts/backfill.ts
 *
 * Requires ALGOLIA_APP_ID and ALGOLIA_ADMIN_API_KEY in functions/.env
 * Requires GOOGLE_APPLICATION_CREDENTIALS pointing to a service account JSON,
 * OR run inside the project directory where firebase login is active.
 */

import * as fs from "fs";
import * as path from "path";

// Manually parse .env to avoid third-party dotenv interceptors
const envFile = path.resolve(__dirname, "../.env");
if (fs.existsSync(envFile)) {
  fs.readFileSync(envFile, "utf-8")
    .split(/\r?\n/)
    .forEach((line) => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) return;
      const eqIdx = trimmed.indexOf("=");
      if (eqIdx === -1) return;
      const key = trimmed.slice(0, eqIdx).trim();
      const val = trimmed.slice(eqIdx + 1).trim().replace(/^["']|["']$/g, "");
      if (key && !(key in process.env)) process.env[key] = val;
    });
}

import * as admin from "firebase-admin";
import algoliasearch from "algoliasearch";

const serviceAccount = require(path.resolve(__dirname, "../service-account.json"));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://local-vyapari-437e0-default-rtdb.firebaseio.com",
});

const algoliaAppId = process.env.ALGOLIA_APP_ID;
const algoliaApiKey = process.env.ALGOLIA_ADMIN_API_KEY;
if (!algoliaAppId || !algoliaApiKey) {
  console.error("Missing ALGOLIA_APP_ID or ALGOLIA_ADMIN_API_KEY in functions/.env");
  process.exit(1);
}
const client = algoliasearch(algoliaAppId, algoliaApiKey);
const productsIndex = client.initIndex("localvyapari_products");
const shopsIndex = client.initIndex("localvyapari_shops");

async function backfillShops() {
  console.log("Fetching shops from RTDB...");
  const snap = await admin.database().ref("/shop").get();
  if (!snap.exists()) { console.log("No shops found."); return; }

  const records: object[] = [];
  snap.forEach((child) => {
    const shopId = child.key!;
    const s = child.val() as Record<string, unknown>;

    let city = (s.city as string) ?? "";
    if (!city && typeof s.address === "string") {
      const parts = s.address.split(",").map((p: string) => p.trim());
      city = parts.length >= 3 ? parts[2] : (parts[parts.length - 1] ?? "");
    }

    records.push({
      objectID: shopId,
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
      _geoloc: { lat: Number(s.latitude ?? 0), lng: Number(s.longitude ?? 0) },
      latitude: Number(s.latitude ?? 0),
      longitude: Number(s.longitude ?? 0),
      geohash: s.geohash ?? "",
      address: s.address ?? "",
      city,
      state: s.state ?? "",
      pincode: s.pincode ?? "",
      placeId: s.placeId ?? "",
    });
  });

  await shopsIndex.saveObjects(records);
  console.log(`Indexed ${records.length} shops into Algolia.`);
}

async function backfillFirestoreShops() {
  console.log("Backfilling Firestore searchable_shops...");
  const snap = await admin.database().ref("/shop").get();
  if (!snap.exists()) { console.log("No shops found."); return; }

  // Collect all entries first so we can batch-write with proper awaits
  type Entry = { shopId: string; s: Record<string, unknown> };
  const entries: Entry[] = [];
  snap.forEach((child) => {
    entries.push({ shopId: child.key!, s: child.val() as Record<string, unknown> });
  });

  const db = admin.firestore();
  const BATCH_SIZE = 400; // Firestore limit is 500 writes per batch

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const slice = entries.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const { shopId, s } of slice) {
      let city = (s.city as string) ?? "";
      if (!city && typeof s.address === "string") {
        const parts = s.address.split(",").map((p: string) => p.trim());
        city = parts.length >= 3 ? parts[2] : (parts[parts.length - 1] ?? "");
      }

      const lat = Number(s.latitude ?? 0);
      const lng = Number(s.longitude ?? 0);
      const geohash = String(s.geohash ?? "");
      const shopName = String(s.name ?? s.shopName ?? "");

      batch.set(db.collection("searchable_shops").doc(shopId), {
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
          ? admin.firestore.Timestamp.fromMillis(Number(s.createdAt))
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
          geopoint: new admin.firestore.GeoPoint(lat, lng),
          geohash,
        },
      });
    }

    await batch.commit();
    console.log(`  Committed ${slice.length} shops (${i + slice.length}/${entries.length})`);
  }

  console.log(`Firestore backfill complete: ${entries.length} shops written to searchable_shops.`);
}

async function backfillProducts() {
  console.log("Fetching shops for geo lookup...");
  const shopsSnap = await admin.database().ref("/shop").get();
  const shopMap: Record<string, Record<string, unknown>> = {};
  shopsSnap.forEach((c) => { shopMap[c.key!] = c.val(); });

  console.log("Fetching products from RTDB...");
  const snap = await admin.database().ref("/products").get();
  if (!snap.exists()) { console.log("No products found."); return; }

  const records: object[] = [];
  snap.forEach((shopChild) => {
    const shopId = shopChild.key!;
    const shop = shopMap[shopId] ?? {};
    const lat = Number(shop.latitude ?? 0);
    const lng = Number(shop.longitude ?? 0);
    const shopName = String(shop.name ?? shop.shopName ?? "");

    shopChild.forEach((productChild) => {
      const productId = productChild.key!;
      const p = productChild.val() as Record<string, unknown>;
      if (!p || p.isActive === false) return;

      let images: string[] = [];
      if (Array.isArray(p.images)) images = p.images as string[];
      else if (p.images && typeof p.images === "object")
        images = Object.values(p.images as Record<string, string>);
      else if (typeof p.imageUrl === "string") images = [p.imageUrl];

      let searchKeywords: string[] = [];
      if (Array.isArray(p.searchKeywords)) searchKeywords = p.searchKeywords as string[];
      else if (p.searchKeywords && typeof p.searchKeywords === "object")
        searchKeywords = Object.values(p.searchKeywords as Record<string, string>);

      records.push({
        objectID: `${shopId}_${productId}`,
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
        shopName,
        shopIsOpen: Boolean(shop.isOpen ?? false),
        shopIsVerified: Boolean(shop.isVerified ?? false),
      });
    });
  });

  // Algolia batch limit is 1000 objects per call
  for (let i = 0; i < records.length; i += 1000) {
    await productsIndex.saveObjects(records.slice(i, i + 1000));
    console.log(`Indexed products ${i + 1}–${Math.min(i + 1000, records.length)}`);
  }
  console.log(`Indexed ${records.length} products total.`);
}

(async () => {
  try {
    await backfillShops();
    await backfillFirestoreShops();
    await backfillProducts();
    console.log("Backfill complete.");
    process.exit(0);
  } catch (e) {
    console.error("Backfill failed:", e);
    process.exit(1);
  }
})();
