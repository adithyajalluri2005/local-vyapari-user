import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/repositories/offer_repository.dart';

final offerDetailsProvider = FutureProvider.family<Offer?, String>((ref, key) async {
  final parts = key.split(':');
  if (parts.length != 2) return null;
  final shopId = parts[0];
  final offerId = parts[1];
  
  return ref.read(offerRepositoryProvider).getOfferDetails(shopId, offerId);
});

final offerDetailsStreamProvider = StreamProvider.family<Offer?, String>((ref, key) {
  final parts = key.split(':');
  if (parts.length != 2) return Stream.value(null);
  final shopId = parts[0];
  final offerId = parts[1];

  return ref.read(offerRepositoryProvider).streamOfferDetails(shopId, offerId);
});
