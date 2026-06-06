import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/repositories/offer_repository.dart';

final shopOffersProvider = FutureProvider.family<List<Offer>, String>((ref, shopId) async {
  return ref.read(offerRepositoryProvider).getShopOffers(shopId);
});
