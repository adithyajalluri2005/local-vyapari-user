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
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:local_vyapari_user/firebase_options.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/router/app_router.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/location/location_cache.dart';

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
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: isChat ? 'chat:${message.data['shopId'] ?? ''}' : null,
      );
    } catch (e) {
      debugPrint("Error displaying background notification: $e");
    }
  }
}

final notificationServiceProvider = Provider((ref) {
  final service = NotificationService(ref);
  service.init();

  ref.listen<AsyncValue<LocationResult?>>(activeBrowsingLocationProvider, (previous, next) {
    next.whenData((location) {
      if (location != null) {
        service.updateLocationSubscription(location);
      }
    });
  });

  return service;
});

class NotificationService {
  bool _initialized = false;
  final Set<String> _seenOfferIds = {};
  bool _firstLoadDone = false;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<DatabaseEvent>? _chatSubscription;
  final Map<String, int> _lastChatNotifyTs = {};

  NotificationService(Ref _);

  void init() {
    if (_initialized) return;
    _initialized = true;

    _initLocalNotifications();
    _initFirebaseMessaging();
    _listenForNewOffers();

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
        AndroidInitializationSettings('@mipmap/ic_launcher');

    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(android: initSettingsAndroid),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            final context = rootNavigatorKey.currentContext;
            if (context == null) return;

            final payload = response.payload ?? '';
            if (payload.startsWith('chat:')) {
              GoRouter.of(context).go('/chats');
            } else {
              GoRouter.of(context).go('/home');
            }
          } catch (e) {
            debugPrint('Error handling local notification click: $e');
          }
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

  Future<void> _showNativeNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'offers_channel_id',
      'Nearby Offers',
      channelDescription: 'Notifications for new offers in nearby shops',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
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
                  if (context != null) GoRouter.of(context).go('/chats');
                } catch (_) {}
              },
            );
          });
    }).catchError((e) {
      debugPrint('Error seeding chat notify timestamps: $e');
    });
  }

  void _listenForNewOffers() {
    // Check immediately on startup, then every 10 minutes.
    // Using periodic .get() instead of onValue avoids a 24/7 persistent connection
    // to the entire offers tree.
    _checkNewOffers();
    Timer.periodic(const Duration(minutes: 10), (_) => _checkNewOffers());
  }

  Future<void> _checkNewOffers() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('offers').get();
      if (!snapshot.exists || snapshot.value == null) {
        _firstLoadDone = true;
        return;
      }

      final Map<dynamic, dynamic> shopsOffersMap = snapshot.value as Map<dynamic, dynamic>;
      final List<MapEntry<String, Map<String, dynamic>>> newOffers = [];

      shopsOffersMap.forEach((shopIdKey, offersValue) {
        final shopId = shopIdKey.toString();
        if (offersValue is Map) {
          offersValue.forEach((offerIdKey, offerValue) {
            if (offerValue is Map) {
              final offerId = offerIdKey.toString();
              final offerData = Map<String, dynamic>.from(offerValue);
              if (!_seenOfferIds.contains(offerId)) {
                if (_firstLoadDone) newOffers.add(MapEntry(shopId, offerData));
                _seenOfferIds.add(offerId);
              }
            }
          });
        }
      });

      _firstLoadDone = true;

      for (final entry in newOffers) {
        final shopId = entry.key;
        final offerData = entry.value;
        final title = offerData['title'] ?? 'New Offer!';

        final isNearby = await _isShopNearby(shopId);
        if (isNearby) {
          final shopName = await _getShopName(shopId);
          final discount = offerData['discountPercentage'] ?? 0;
          final titleStr = 'New Offer at $shopName!';
          final bodyStr = '$title - Get ${discount.toInt()}% OFF!';
          await _showNativeNotification(titleStr, bodyStr);
          _showForegroundNotification(titleStr, bodyStr);
        }
      }
    } catch (e) {
      debugPrint('Error checking for new offers: $e');
    }
  }

  Future<bool> _isShopNearby(String shopId) async {
    try {
      final activeLoc = await LocationCache.getActiveLocation();
      if (activeLoc == null) return false;

      final shopSnapshot = await FirebaseDatabase.instance.ref('shop/$shopId').once();
      if (!shopSnapshot.snapshot.exists || shopSnapshot.snapshot.value == null) return false;

      final shopData = Map<dynamic, dynamic>.from(shopSnapshot.snapshot.value as Map);
      final lat = (shopData['latitude'] ?? 0.0).toDouble();
      final lng = (shopData['longitude'] ?? 0.0).toDouble();
      if (lat == 0.0 && lng == 0.0) return false;

      final distanceInMeters = Geolocator.distanceBetween(
        activeLoc.latitude,
        activeLoc.longitude,
        lat,
        lng,
      );

      return distanceInMeters <= 15000;
    } catch (e) {
      debugPrint('Error checking nearby shop for notification: $e');
      return false;
    }
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
      if (notification != null) {
        final title = notification.title ?? 'New Offer!';
        final body = notification.body ?? 'Check out the new offer nearby!';
        final isChat = message.data['type'] == 'chat';
        final shopId = message.data['shopId'] ?? '';

        _showNativeNotification(title, body);
        _showForegroundNotification(
          title,
          body,
          icon: isChat ? Icons.chat_bubble_rounded : Icons.campaign,
          gradientColors: isChat
              ? const [AppColors.primary, AppColors.primaryLight]
              : const [AppTheme.primaryColor, Color(0xFF673AB7)],
          onTap: isChat
              ? () {
                  try {
                    final context = rootNavigatorKey.currentContext;
                    if (context != null) GoRouter.of(context).go('/chats');
                  } catch (_) {}
                }
              : null,
        );
        if (isChat && shopId.isNotEmpty) {
          _lastChatNotifyTs[shopId] = DateTime.now().millisecondsSinceEpoch;
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationClick(message);
        });
      }
    });

    messaging.onTokenRefresh.listen((_) => _syncDeviceRegistration());
  }

  void _handleNotificationClick(RemoteMessage message) {
    try {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;

      if (message.data['type'] == 'chat') {
        GoRouter.of(context).go('/chats');
      } else {
        GoRouter.of(context).go('/home');
      }
    } catch (e) {
      debugPrint('Error handling FCM notification click: $e');
    }
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
        onTap: onTap ??
            () {
              try {
                final ctx = rootNavigatorKey.currentContext;
                if (ctx != null) GoRouter.of(ctx).go('/home');
              } catch (_) {}
            },
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
