import * as dotenv from "dotenv";
dotenv.config();

import * as admin from "firebase-admin";
admin.initializeApp();

export { indexProduct } from "./indexers/productIndexer";
export { indexShop } from "./indexers/shopIndexer";
export { hyperlocalSearch } from "./search/hyperlocalSearch";
