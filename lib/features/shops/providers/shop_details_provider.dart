import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/repositories/shop_repository.dart';

final shopDetailsProvider = FutureProvider.family<Shop?, String>((ref, shopId) async {
  return ref.read(shopRepositoryProvider).getShopDetails(shopId);
});

final shopDetailsStreamProvider = StreamProvider.family<Shop?, String>((ref, shopId) {
  return ref.read(shopRepositoryProvider).streamShopDetails(shopId);
});
