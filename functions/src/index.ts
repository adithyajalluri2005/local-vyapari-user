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


