import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/repositories/product_repository.dart';

final productDetailsProvider = FutureProvider.family<Product?, String>((ref, key) async {
  final parts = key.split(':');
  if (parts.length != 2) return null;
  final shopId = parts[0];
  final productId = parts[1];
  
  return ref.read(productRepositoryProvider).getProductDetails(shopId, productId);
});

final productDetailsStreamProvider = StreamProvider.family<Product?, String>((ref, key) {
  final parts = key.split(':');
  if (parts.length != 2) return Stream.value(null);
  final shopId = parts[0];
  final productId = parts[1];

  return ref.read(productRepositoryProvider).streamProductDetails(shopId, productId);
});
