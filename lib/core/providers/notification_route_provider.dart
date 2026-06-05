import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingNotificationRouteNotifier extends Notifier<String?> {
  final String? _initial;
  PendingNotificationRouteNotifier([this._initial]);

  @override
  String? build() => _initial;

  void set(String? route) => state = route;
}

final pendingNotificationRouteProvider =
    NotifierProvider<PendingNotificationRouteNotifier, String?>(
  PendingNotificationRouteNotifier.new,
);
