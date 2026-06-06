import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/repositories/product_repository.dart';

const kProductPageSize = 10;

final shopProductsProvider = StreamProvider.family<List<Product>, String>((ref, shopId) {
  return ref.read(productRepositoryProvider).getShopProducts(shopId);
});
