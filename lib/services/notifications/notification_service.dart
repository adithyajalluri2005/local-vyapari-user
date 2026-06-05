import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:local_vyapari_user/firebase_options.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/router/app_router.dart';
import 'package:local_vyapari_user/core/providers/notification_route_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/location/location_cache.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file in background isolate: $e");
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase already initialized or failed in background: $e");
  }

  if (message.notification == null && message.data.isNotEmpty) {
    final type = message.data['type'] ?? '';
    final isChat = type == 'chat';

    final title = message.data['title'] ?? (isChat ? 'New message' : 'New Offer!');
    final body = message.data['body'] ?? (isChat ? 'You have a new message.' : 'Check out the new offer nearby!');
    final channelId = isChat ? 'chat_channel_id' : 'offers_channel_id';
    final channelName = isChat ? 'Chat Messages' : 'Nearby Offers';
    final channelDesc = isChat
        ? 'Notifications for new messages from shops'
        : 'Notifications for new offers in nearby shops';

    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    try {
      await localNotifications.initialize(
        settings: const InitializationSettings(android: initSettings),
      );

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        color: const Color(0xFF112E51),
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: isChat ? 'chat:${message.data['shopId'] ?? ''}' : 'offers',
      );
    } catch (e) {
      debugPrint("Error displaying background notification: $e");
    }
  }
}

final notificationServiceProvider = Provider((ref) {
  final service = NotificationService(ref);
  service.init();

  ref.listen<AsyncValue<LocationResult?>>(activeBrowsingLocationProvider, (_, next) {
    next.whenData((location) {
      if (location != null) service.updateLocationSubscription(location);
    });
  });

  // Set up real-time offer listeners whenever the nearby-shops list changes.
  ref.listen<AsyncValue<List<Shop>>>(nearbyShopsProvider, (_, next) {
    next.whenData((shops) => service.updateNearbyShops(shops));
  });

  return service;
});

class NotificationService {
  bool _initialized = false;
  final Set<String> _seenOfferIds = {};
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<DatabaseEvent>? _chatSubscription;
  final Map<String, int> _lastChatNotifyTs = {};
  // Per-shop real-time offer listeners, keyed by shopId.
  final Map<String, StreamSubscription<DatabaseEvent>> _offerSubscriptions = {};

  final Ref _ref;
  NotificationService(this._ref);

  void init() {
    if (_initialized) return;
    _initialized = true;

    _initLocalNotifications().then((_) => _handleLaunchFromLocalNotification());
    _initFirebaseMessaging();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncDeviceRegistration();
        _listenForChatMessages();
      } else {
        _chatSubscription?.cancel();
        _chatSubscription = null;
        _lastChatNotifyTs.clear();
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(android: initSettingsAndroid),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // App is in background (not terminated) — navigator is already mounted.
          final route = _routeForPayload(response.payload ?? '');
          if (route == null) return;
          final context = rootNavigatorKey.currentContext;
          if (context != null) GoRouter.of(context).push(route);
        },
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();

        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'offers_channel_id',
          'Nearby Offers',
          description: 'Notifications for new offers in nearby shops',
          importance: Importance.max,
          playSound: true,
        ));

        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'chat_channel_id',
          'Chat Messages',
          description: 'Notifications for new messages from shops',
          importance: Importance.high,
          playSound: true,
        ));
      }
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  String? _routeForPayload(String payload) {
    if (payload.startsWith('chat:')) return '/chats';
    if (payload == 'offers') return '/all_offers';
    return null;
  }

  // App was TERMINATED and user tapped a local notification.
  // onDidReceiveNotificationResponse does not fire in that scenario.
  // Store the route in the provider — MainNavigationScreen.initState consumes it.
  Future<void> _handleLaunchFromLocalNotification() async {
    try {
      final details = await _localNotifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        final route = _routeForPayload(details!.notificationResponse?.payload ?? '');
        if (route != null) {
          _ref.read(pendingNotificationRouteProvider.notifier).set(route);
        }
      }
    } catch (e) {
      debugPrint('getNotificationAppLaunchDetails error: $e');
    }
  }

  Future<void> _showNativeNotification(String title, String body, {String payload = 'offers'}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'offers_channel_id',
      'Nearby Offers',
      channelDescription: 'Notifications for new offers in nearby shops',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      color: Color(0xFF112E51),
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error displaying native notification: $e');
    }
  }

  Future<void> _showChatNativeNotification({
    required String shopId,
    required String shopName,
    required String messageText,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_channel_id',
      'Chat Messages',
      channelDescription: 'Notifications for new messages from shops',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      color: Color(0xFF112E51),
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      await _localNotifications.show(
        id: id,
        title: 'New message from $shopName',
        body: messageText.isEmpty ? 'Sent you a message' : messageText,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: 'chat:$shopId',
      );
    } catch (e) {
      debugPrint('Error displaying chat notification: $e');
    }
  }

  void _listenForChatMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    _chatSubscription?.cancel();
    _lastChatNotifyTs.clear();

    // Seed current timestamps so we don't re-fire for already-unread messages on startup
    FirebaseDatabase.instance.ref('chats/$userId').once().then((snapshot) {
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final map = snapshot.snapshot.value as Map<dynamic, dynamic>;
        map.forEach((key, value) {
          if (value is Map) {
            final lastMsg = value['lastMessage'] as Map?;
            if (lastMsg != null && lastMsg['timestamp'] is int) {
              _lastChatNotifyTs[key.toString()] = lastMsg['timestamp'] as int;
            }
          }
        });
      }

      // Subscribe to child changes after seeding
      _chatSubscription = FirebaseDatabase.instance
          .ref('chats/$userId')
          .onChildChanged
          .listen((event) async {
            final shopId = event.snapshot.key;
            if (shopId == null) return;

            final sessionValue = event.snapshot.value;
            if (sessionValue is! Map) return;

            final lastMsg = sessionValue['lastMessage'] as Map?;
            if (lastMsg == null) return;

            final unread = lastMsg['unread'] == true;
            final senderId = lastMsg['senderId']?.toString();
            final messageText = lastMsg['text']?.toString() ?? '';
            final timestamp = lastMsg['timestamp'] is int ? lastMsg['timestamp'] as int : 0;

            // Only notify for messages from vendor (not current user) that are unread
            if (!unread || senderId == userId) return;
            // Skip if already notified for this exact message
            if (_lastChatNotifyTs[shopId] == timestamp) return;

            _lastChatNotifyTs[shopId] = timestamp;

            final shopName = sessionValue['shopName']?.toString() ?? 'Shop';

            await _showChatNativeNotification(
              shopId: shopId,
              shopName: shopName,
              messageText: messageText,
            );
            _showForegroundNotification(
              'New message from $shopName',
              messageText.isEmpty ? 'Sent you a message' : messageText,
              icon: Icons.chat_bubble_rounded,
              gradientColors: const [AppColors.primary, AppColors.primaryLight],
              onTap: () {
                try {
                  final context = rootNavigatorKey.currentContext;
                  if (context != null) GoRouter.of(context).push('/chats');
                } catch (_) {}
              },
            );
          });
    }).catchError((e) {
      debugPrint('Error seeding chat notify timestamps: $e');
    });
  }

  // ── Real-time per-shop offer listeners ────────────────────────────────────

  /// Called whenever the nearby-shops list changes. Sets up / tears down
  /// per-shop RTDB `onChildAdded` listeners so new offers trigger a notification
  /// immediately — no polling required.
  void updateNearbyShops(List<Shop> shops) {
    final shopIds = shops.map((s) => s.id).toSet();
    _updateOfferListeners(shopIds);
  }

  Future<void> _updateOfferListeners(Set<String> newShopIds) async {
    // Cancel listeners for shops that are no longer nearby.
    final toRemove = Set<String>.from(_offerSubscriptions.keys).difference(newShopIds);
    for (final shopId in toRemove) {
      await _offerSubscriptions[shopId]?.cancel();
      _offerSubscriptions.remove(shopId);
    }

    // Set up listeners for newly nearby shops.
    for (final shopId in newShopIds.difference(_offerSubscriptions.keys.toSet())) {
      await _setupShopOfferListener(shopId);
    }
  }

  Future<void> _setupShopOfferListener(String shopId) async {
    // 1. Seed existing offer IDs so we never re-notify for offers that
    //    were already posted before the listener was attached.
    try {
      final snapshot = await FirebaseDatabase.instance.ref('offers/$shopId').get();
      if (snapshot.exists && snapshot.value is Map) {
        (snapshot.value as Map).forEach((key, _) => _seenOfferIds.add(key.toString()));
      }
    } catch (e) {
      debugPrint('Error seeding offer IDs for shop $shopId: $e');
    }

    // 2. Listen for new children. onChildAdded fires for all existing children
    //    first (they are already in _seenOfferIds from step 1 → skipped),
    //    then fires for every genuinely new offer.
    _offerSubscriptions[shopId] = FirebaseDatabase.instance
        .ref('offers/$shopId')
        .onChildAdded
        .listen((event) async {
          final offerId = event.snapshot.key;
          if (offerId == null || _seenOfferIds.contains(offerId)) return;
          _seenOfferIds.add(offerId);

          final raw = event.snapshot.value;
          if (raw is! Map) return;
          final offerData = Map<String, dynamic>.from(raw);

          if (offerData['isActive'] != true) return;

          final title = offerData['title']?.toString() ?? 'New Offer!';
          final storedName = offerData['shopName']?.toString();
          final shopName = (storedName != null && storedName.isNotEmpty)
              ? storedName
              : await _getShopName(shopId);
          final discount = (offerData['discountPercentage'] as num?)?.toInt() ?? 0;

          final titleStr = 'New Offer at $shopName!';
          final bodyStr = '$title - Get $discount% OFF!';
          // Native notifications for offers come from FCM (foreground: onMessage,
          // background: firebaseMessagingBackgroundHandler). Calling
          // _showNativeNotification here too would produce a duplicate whenever
          // the app is backgrounded, because both this RTDB listener and the FCM
          // background handler fire concurrently.
          // Only show the in-app foreground banner; it silently no-ops when the
          // app is not visible (overlay == null guard inside _showForegroundNotification).
          _showForegroundNotification(
            titleStr,
            bodyStr,
            icon: Icons.campaign,
            gradientColors: const [AppTheme.primaryColor, Color(0xFF673AB7)],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) GoRouter.of(context).push('/all_offers');
              } catch (_) {}
            },
          );
        }, onError: (Object e) {
          debugPrint('Offer listener error for shop $shopId: $e');
          _offerSubscriptions.remove(shopId);
        });
  }

  Future<String> _getShopName(String shopId) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('shop/$shopId/name').once();
      if (snap.snapshot.exists && snap.snapshot.value != null) {
        return snap.snapshot.value.toString();
      }
      final snap2 = await FirebaseDatabase.instance.ref('shop/$shopId/shopName').once();
      if (snap2.snapshot.exists && snap2.snapshot.value != null) {
        return snap2.snapshot.value.toString();
      }
    } catch (e) {
      debugPrint('Error fetching shop name: $e');
    }
    return 'Nearby Shop';
  }

  Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final isChat = message.data['type'] == 'chat';
      final shopId = message.data['shopId'] ?? '';

      // onMessage fires ONLY in the foreground. Offer notifications are already
      // handled by the per-shop RTDB onChildAdded listeners when those are active.
      // Showing them here too would produce a duplicate for every new offer.
      // Skip non-chat FCM notifications when RTDB listeners are live; fall back
      // to FCM only when no listeners exist yet (location not resolved).
      final rtdbListenersActive = _offerSubscriptions.isNotEmpty;

      // Notification-payload message (rare on Android when app is foreground)
      if (notification != null) {
        final title = notification.title ?? 'New Offer!';
        final body = notification.body ?? 'Check out the new offer nearby!';

        if (isChat) {
          _showNativeNotification(title, body);
          _showForegroundNotification(
            title,
            body,
            icon: Icons.chat_bubble_rounded,
            gradientColors: const [AppColors.primary, AppColors.primaryLight],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) GoRouter.of(context).push('/chats');
              } catch (_) {}
            },
          );
          if (shopId.isNotEmpty) {
            _lastChatNotifyTs[shopId] = DateTime.now().millisecondsSinceEpoch;
          }
        } else if (!rtdbListenersActive) {
          _showNativeNotification(title, body);
          _showForegroundNotification(
            title,
            body,
            icon: Icons.campaign,
            gradientColors: const [AppTheme.primaryColor, Color(0xFF673AB7)],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) GoRouter.of(context).push('/all_offers');
              } catch (_) {}
            },
          );
        }
        return;
      }

      // Data-only message — the common path for Cloud Function–sent notifications.
      if (message.data.isNotEmpty) {
        final title = message.data['title'] ?? (isChat ? 'New message' : 'New Offer!');
        final body = message.data['body'] ??
            (isChat ? 'You have a new message.' : 'Check out the new offer nearby!');

        if (isChat) {
          final shopName = message.data['shopName'] ?? 'Shop';
          _showChatNativeNotification(
            shopId: shopId.isNotEmpty ? shopId : 'unknown',
            shopName: shopName,
            messageText: body,
          );
          _showForegroundNotification(
            'New message from $shopName',
            body,
            icon: Icons.chat_bubble_rounded,
            gradientColors: const [AppColors.primary, AppColors.primaryLight],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) GoRouter.of(context).push('/chats');
              } catch (_) {}
            },
          );
          if (shopId.isNotEmpty) {
            _lastChatNotifyTs[shopId] = DateTime.now().millisecondsSinceEpoch;
          }
        } else if (!rtdbListenersActive) {
          // RTDB listeners not yet active — use FCM as the fallback.
          _showNativeNotification(title, body);
          _showForegroundNotification(
            title,
            body,
            icon: Icons.campaign,
            gradientColors: const [AppTheme.primaryColor, Color(0xFF673AB7)],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) GoRouter.of(context).push('/all_offers');
              } catch (_) {}
            },
          );
        }
      }
    });

    // onMessageOpenedApp and getInitialMessage are handled in main.dart before
    // runApp so they are never missed due to auth latency. See main.dart.

    messaging.onTokenRefresh.listen((_) => _syncDeviceRegistration());
  }

  Future<void> _syncDeviceRegistration({LocationResult? location}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final dbRef = FirebaseDatabase.instance.ref('users_devices/${user.uid}/customer');

      LocationResult? activeLoc = location ?? await LocationCache.getActiveLocation();

      final Map<String, dynamic> data = {
        'fcmToken': token,
        'updatedAt': ServerValue.timestamp,
      };

      if (activeLoc != null) {
        data['latitude'] = activeLoc.latitude;
        data['longitude'] = activeLoc.longitude;
        data['geohash'] = activeLoc.geohash;
        data['address'] = activeLoc.formattedAddress;
      }

      await dbRef.update(data);
    } catch (e) {
      debugPrint('Error syncing device registration: $e');
    }
  }

  Future<void> updateLocationSubscription(LocationResult location) async {
    try {
      final geohash = location.geohash;
      if (geohash.length < 5) return;
      final newPrefix = geohash.substring(0, 5);

      final lastPrefix = await _getLastSubscribedGeohash();
      if (lastPrefix == newPrefix) {
        await _syncDeviceRegistration(location: location);
        return;
      }

      final messaging = FirebaseMessaging.instance;

      if (lastPrefix != null) {
        await messaging.unsubscribeFromTopic('offers_geo_$lastPrefix');
      }

      await messaging.subscribeToTopic('offers_geo_$newPrefix');
      await _saveLastSubscribedGeohash(newPrefix);
      await _syncDeviceRegistration(location: location);
    } catch (e) {
      debugPrint('Error updating location subscription: $e');
    }
  }

  Future<File> _getSubscriptionCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/fcm_subscriptions.json');
  }

  Future<String?> _getLastSubscribedGeohash() async {
    try {
      final file = await _getSubscriptionCacheFile();
      if (await file.exists()) {
        final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
        return data['last_geohash'] as String?;
      }
    } catch (e) {
      debugPrint('Error reading last geohash from cache: $e');
    }
    return null;
  }

  Future<void> _saveLastSubscribedGeohash(String geohash) async {
    try {
      final file = await _getSubscriptionCacheFile();
      await file.writeAsString(json.encode({'last_geohash': geohash}));
    } catch (e) {
      debugPrint('Error saving last geohash to cache: $e');
    }
  }

  void _showForegroundNotification(
    String title,
    String body, {
    IconData icon = Icons.campaign,
    List<Color> gradientColors = const [AppTheme.primaryColor, Color(0xFF673AB7)],
    VoidCallback? onTap,
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => ForegroundNotificationBanner(
        title: title,
        body: body,
        icon: icon,
        gradientColors: gradientColors,
        // No default navigation: user is already in the app, just dismiss the banner.
        onTap: onTap ?? () {},
        onDismissed: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

// ── Foreground banner overlay ─────────────────────────────────────────────────

class ForegroundNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final IconData icon;
  final List<Color> gradientColors;

  const ForegroundNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismissed,
    this.icon = Icons.campaign,
    this.gradientColors = const [AppTheme.primaryColor, Color(0xFF673AB7)],
  });

  @override
  State<ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState extends State<ForegroundNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    if (mounted) {
      await _controller.reverse();
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              widget.onTap();
              _dismiss();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: _dismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
