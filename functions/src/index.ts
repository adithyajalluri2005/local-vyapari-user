import * as dotenv from "dotenv";
dotenv.config();

import * as admin from "firebase-admin";
admin.initializeApp();

export { indexProduct } from "./indexers/productIndexer";
export { indexShop } from "./indexers/shopIndexer";
export { hyperlocalSearch } from "./search/hyperlocalSearch";
export { getNearbyProductsAggregated } from "./products/nearbyProducts";
export { getNearbyOffersAggregated } from "./offers/nearbyOffers";
export {
  validateSession,
  listMyDevices,
  revokeDevice,
  signOutEverywhere,
  assertRecentAuth,
  resolvePhoneLoginEmail,
} from "./security/sessionManagement";

import * as functions from "firebase-functions/v1";

export const initializeUser = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  if (!uid) return;
  
  try {
    await admin.database().ref(`/users/${uid}/roles`).set({
      customer: true,
    });
  } catch (error) {
    console.error(`Failed to initialize roles for user ${uid}:`, error);
  }
});
