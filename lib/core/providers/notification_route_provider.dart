import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pending navigation triggered by a notification tap before the navigator
/// was ready. [extra] carries GoRouter route extras (e.g. shopId/shopName for
/// the chat screen) so the caller can do context.push(route, extra: extra).
class PendingNotification {
  final String route;
  final Map<String, dynamic>? extra;

  const PendingNotification(this.route, {this.extra});
}

class PendingNotificationRouteNotifier extends Notifier<PendingNotification?> {
  final PendingNotification? _initial;
  PendingNotificationRouteNotifier([this._initial]);

  @override
  PendingNotification? build() => _initial;

  void set(PendingNotification? notification) => state = notification;
}

final pendingNotificationRouteProvider =
    NotifierProvider<PendingNotificationRouteNotifier, PendingNotification?>(
  PendingNotificationRouteNotifier.new,
);
