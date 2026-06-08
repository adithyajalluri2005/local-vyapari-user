import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotifSvc-BG] Background message received — id=${message.messageId} type=${message.data['type']} hasNotification=${message.notification != null} dataKeys=${message.data.keys.toList()}');

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[NotifSvc-BG] Failed to load .env: $e');
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[NotifSvc-BG] Firebase initialized');
  } catch (e) {
    debugPrint('[NotifSvc-BG] Firebase init skipped or failed: $e');
  }

  if (message.notification != null) {
    debugPrint('[NotifSvc-BG] Has notification payload — Android will show it automatically; skipping local show');
    return;
  }

  if (message.data.isEmpty) {
    debugPrint('[NotifSvc-BG] No data payload — nothing to show');
    return;
  }

  final type = message.data['type'] ?? '';
  final isChat = type == 'chat';
  debugPrint('[NotifSvc-BG] Data-only message — type=$type isChat=$isChat');

  final title = message.data['title'] ?? (isChat ? 'New message' : 'New Offer!');
  final body = message.data['body'] ?? (isChat ? 'You have a new message.' : 'Check out the new offer nearby!');
  final channelId = isChat ? 'chat_channel_id' : 'offers_channel_id';
  final channelName = isChat ? 'Chat Messages' : 'Nearby Offers';
  final channelDesc = isChat
      ? 'Notifications for new messages from shops'
      : 'Notifications for new offers in nearby shops';

  debugPrint('[NotifSvc-BG] Showing local notification — channel=$channelId title="$title"');

  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  try {
    await localNotifications.initialize(
      settings: const InitializationSettings(android: initSettings),
    );
    debugPrint('[NotifSvc-BG] FlutterLocalNotifications initialized');

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
      payload: isChat
          ? json.encode({'type': 'chat', 'shopId': message.data['shopId'] ?? '', 'shopName': message.data['shopName'] ?? ''})
          : json.encode({'type': 'offer', 'shopId': message.data['shopId'] ?? ''}),
    );
    debugPrint('[NotifSvc-BG] Local notification shown — id=$id');
  } catch (e) {
    debugPrint('[NotifSvc-BG] Error displaying background notification: $e');
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

  // Set up real-time offer listeners whenever the nearby shop ID SET changes.
  // nearbyShopIdsProvider only emits on membership changes (not on shop data
  // updates), so _updateOfferListeners is never called spuriously.
  ref.listen<AsyncValue<String>>(nearbyShopIdsProvider, (_, next) {
    next.whenData((idsString) {
      final ids = idsString.isEmpty ? <String>{} : idsString.split(',').toSet();
      service.updateNearbyShopIds(ids);
    });
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

  // App startup timestamp to filter out historical notifications
  final int _appStartupTime = DateTime.now().millisecondsSinceEpoch;
  // In-memory cache for shop names to avoid redundant Firestore reads
  final Map<String, String> _shopNameCache = {};

  final Ref _ref;
  NotificationService(this._ref);

  void init() {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[NotifSvc] init() called');

    _initLocalNotifications().then((_) {
      debugPrint('[NotifSvc] Local notifications initialized');
      _handleLaunchFromLocalNotification();
    });
    _initFirebaseMessaging();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('[NotifSvc] Auth state: signed in uid=${user.uid}');
        _syncDeviceRegistration();
        _listenForChatMessages();
      } else {
        debugPrint('[NotifSvc] Auth state: signed out — cancelling chat and offer listeners');
        _chatSubscription?.cancel();
        _chatSubscription = null;
        _lastChatNotifyTs.clear();
        for (final sub in _offerSubscriptions.values) {
          sub.cancel();
        }
        _offerSubscriptions.clear();
        _seenOfferIds.clear();
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
          final rawPayload = response.payload ?? '';
          debugPrint('[NotifSvc] onDidReceiveNotificationResponse — payload=$rawPayload');
          _handleLocalNotificationTap(rawPayload);
        },
      );
      debugPrint('[NotifSvc] FlutterLocalNotifications plugin initialized');

      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        debugPrint('[NotifSvc] Notification permission granted=$granted');

        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'offers_channel_id',
          'Nearby Offers',
          description: 'Notifications for new offers in nearby shops',
          importance: Importance.max,
          playSound: true,
        ));
        debugPrint('[NotifSvc] offers_channel_id created');

        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'chat_channel_id',
          'Chat Messages',
          description: 'Notifications for new messages from shops',
          importance: Importance.high,
          playSound: true,
        ));
        debugPrint('[NotifSvc] chat_channel_id created');
      } else {
        debugPrint('[NotifSvc] androidImpl is null — not on Android?');
      }
    } catch (e) {
      debugPrint('[NotifSvc] Error initializing local notifications: $e');
    }
  }

  /// Decodes a JSON notification payload into a [PendingNotification].
  /// Falls back gracefully for legacy `chat:shopId` / `offers` string payloads.
  PendingNotification _pendingFromPayload(String payload) {
    if (payload.isEmpty) return const PendingNotification('/all_offers');
    try {
      final data = Map<String, dynamic>.from(json.decode(payload) as Map);
      final type = data['type'] as String? ?? '';
      final shopId = data['shopId'] as String? ?? '';
      if (type == 'chat') {
        final shopName = data['shopName'] as String? ?? 'Shop';
        if (shopId.isNotEmpty) {
          return PendingNotification('/chat', extra: {'shopId': shopId, 'shopName': shopName, 'shopLogo': ''});
        }
        return const PendingNotification('/chats');
      }
      if (type == 'offer' || data.isNotEmpty) {
        if (shopId.isNotEmpty) {
          return PendingNotification('/shop_details?shopId=$shopId');
        }
        return const PendingNotification('/all_offers');
      }
      return const PendingNotification('/all_offers');
    } catch (_) {
      // Legacy fallback for plain-string payloads written by previous builds.
      if (payload.startsWith('chat:')) return const PendingNotification('/chats');
      return const PendingNotification('/all_offers');
    }
  }

  /// Navigates immediately when the navigator is available (app foregrounded),
  /// or stashes into the provider for MainNavigationScreen to consume.
  void _handleLocalNotificationTap(String payload) {
    debugPrint('[NotifSvc] _handleLocalNotificationTap — payload=$payload');
    final pending = _pendingFromPayload(payload);
    debugPrint('[NotifSvc] Resolved → route=${pending.route} extra=${pending.extra}');
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).push(pending.route, extra: pending.extra);
    } else {
      debugPrint('[NotifSvc] Navigator not ready — storing pending notification');
      _ref.read(pendingNotificationRouteProvider.notifier).set(pending);
    }
  }

  // App was TERMINATED and user tapped a local notification.
  // onDidReceiveNotificationResponse does not fire in that scenario.
  // Store the resolved route+extra in the provider — MainNavigationScreen.initState consumes it.
  Future<void> _handleLaunchFromLocalNotification() async {
    try {
      final details = await _localNotifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        final rawPayload = details!.notificationResponse?.payload ?? '';
        debugPrint('[NotifSvc] _handleLaunchFromLocalNotification — payload=$rawPayload');
        final pending = _pendingFromPayload(rawPayload);
        debugPrint('[NotifSvc] Resolved → route=${pending.route} extra=${pending.extra}');
        _ref.read(pendingNotificationRouteProvider.notifier).set(pending);
      }
    } catch (e) {
      debugPrint('[NotifSvc] getNotificationAppLaunchDetails error: $e');
    }
  }

  Future<void> _showNativeNotification(String title, String body, {String payload = '{"type":"offer"}'}) async {
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

    debugPrint('[NotifSvc] _showNativeNotification — id=$id channel=offers_channel_id title="$title" payload="$payload"');
    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: payload,
      );
      debugPrint('[NotifSvc] _showNativeNotification shown — id=$id');
    } catch (e) {
      debugPrint('[NotifSvc] Error displaying native notification: $e');
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

    final chatPayload = json.encode({'type': 'chat', 'shopId': shopId, 'shopName': shopName});
    debugPrint('[NotifSvc] _showChatNativeNotification — id=$id shopId=$shopId shopName="$shopName" msg="${messageText.isEmpty ? '<empty>' : messageText}"');
    try {
      await _localNotifications.show(
        id: id,
        title: 'New message from $shopName',
        body: messageText.isEmpty ? 'Sent you a message' : messageText,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: chatPayload,
      );
      debugPrint('[NotifSvc] _showChatNativeNotification shown — id=$id');
    } catch (e) {
      debugPrint('[NotifSvc] Error displaying chat notification: $e');
    }
  }

  void _listenForChatMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[NotifSvc] _listenForChatMessages: no current user — aborting');
      return;
    }

    final userId = user.uid;
    debugPrint('[NotifSvc] _listenForChatMessages: uid=$userId');
    _chatSubscription?.cancel();
    _lastChatNotifyTs.clear();

    debugPrint('[NotifSvc] Subscribing to chats/$userId onChildChanged');
    _chatSubscription = FirebaseDatabase.instance
        .ref('chats/$userId')
        .onChildChanged
        .listen((event) async {
          final shopId = event.snapshot.key;
          debugPrint('[NotifSvc] Chat onChildChanged — shopId=$shopId snapshotType=${event.snapshot.value?.runtimeType}');

          if (shopId == null) {
            debugPrint('[NotifSvc] Chat event has null key — skipping');
            return;
          }

          final sessionValue = event.snapshot.value;
          if (sessionValue is! Map) {
            debugPrint('[NotifSvc] Chat event value is not a Map (got ${sessionValue?.runtimeType}) — skipping');
            return;
          }

          final lastMsg = sessionValue['lastMessage'] as Map?;
          if (lastMsg == null) {
            debugPrint('[NotifSvc] No lastMessage in chat session — skipping');
            return;
          }

          final unread = lastMsg['unread'] == true;
          final senderId = lastMsg['senderId']?.toString();
          final messageText = lastMsg['text']?.toString() ?? '';
          final timestamp = lastMsg['timestamp'] is int ? lastMsg['timestamp'] as int : 0;

          debugPrint('[NotifSvc] Chat message — shopId=$shopId unread=$unread senderId=$senderId timestamp=$timestamp text="${messageText.isEmpty ? '<empty>' : messageText}"');

          if (!unread) {
            debugPrint('[NotifSvc] Message is not unread — skipping');
            return;
          }
          if (senderId == userId) {
            debugPrint('[NotifSvc] Message sent by current user — skipping');
            return;
          }
          if (timestamp < _appStartupTime) {
            debugPrint('[NotifSvc] Message is older than app startup — skipping');
            return;
          }
          if (_lastChatNotifyTs[shopId] == timestamp) {
            debugPrint('[NotifSvc] Already notified for timestamp=$timestamp shopId=$shopId — skipping');
            return;
          }

          _lastChatNotifyTs[shopId] = timestamp;
          final shopName = sessionValue['shopName']?.toString() ?? 'Shop';
          debugPrint('[NotifSvc] Firing chat notification — shopId=$shopId shopName="$shopName"');

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
        }, onError: (Object e) {
          debugPrint('[NotifSvc] Chat onChildChanged error: $e');
        });
    debugPrint('[NotifSvc] Chat listener active for uid=$userId');
  }

  // ── Real-time per-shop offer listeners ────────────────────────────────────

  /// Called whenever the nearby-shops list changes. Sets up / tears down
  /// per-shop RTDB `onChildAdded` listeners so new offers trigger a notification
  /// immediately — no polling required.
  void updateNearbyShopIds(Set<String> shopIds) {
    debugPrint('[NotifSvc] updateNearbyShopIds — ${shopIds.length} shops: $shopIds');
    _updateOfferListeners(shopIds);
  }

  Future<void> _updateOfferListeners(Set<String> newShopIds) async {
    final toRemove = Set<String>.from(_offerSubscriptions.keys).difference(newShopIds);
    for (final shopId in toRemove) {
      debugPrint('[NotifSvc] Cancelling offer listener for removed shop=$shopId');
      await _offerSubscriptions[shopId]?.cancel();
      _offerSubscriptions.remove(shopId);
    }

    final toAdd = newShopIds.difference(_offerSubscriptions.keys.toSet());
    debugPrint('[NotifSvc] Setting up offer listeners for ${toAdd.length} new shops: $toAdd');
    for (final shopId in toAdd) {
      await _setupShopOfferListener(shopId);
    }
  }

  Future<void> _setupShopOfferListener(String shopId) async {
    debugPrint('[NotifSvc] _setupShopOfferListener — shopId=$shopId');
    debugPrint('[NotifSvc] Subscribing to offers/$shopId onChildAdded');
    
    _offerSubscriptions[shopId] = FirebaseDatabase.instance
        .ref('offers/$shopId')
        .orderByChild('createdAt')
        .startAt(_appStartupTime)
        .onChildAdded
        .listen((event) async {
          final offerId = event.snapshot.key;
          if (offerId == null || _seenOfferIds.contains(offerId)) return;

          final raw = event.snapshot.value;
          if (raw is! Map) {
            debugPrint('[NotifSvc] Offer value is not a Map (${raw?.runtimeType}) — skipping');
            return;
          }
          final offerData = Map<String, dynamic>.from(raw);

          final createdAt = offerData['createdAt'] as int?;
          if (createdAt != null && createdAt < _appStartupTime) {
            _seenOfferIds.add(offerId);
            return;
          }

          _seenOfferIds.add(offerId);

          if (offerData['isActive'] != true) {
            debugPrint('[NotifSvc] Offer not active — skipping notification');
            return;
          }

          final title = offerData['title']?.toString() ?? 'New Offer!';
          final storedName = offerData['shopName']?.toString();
          final shopName = (storedName != null && storedName.isNotEmpty)
              ? storedName
              : await _getShopName(shopId);
          final discount = (offerData['discountPercentage'] as num?)?.toInt() ?? 0;

          final titleStr = 'New Offer at $shopName!';
          final bodyStr = '$title - Get $discount% OFF!';
          debugPrint('[NotifSvc] Showing offer foreground notification — "$titleStr" | "$bodyStr"');
          _showForegroundNotification(
            titleStr,
            bodyStr,
            icon: Icons.campaign,
            gradientColors: const [AppTheme.primaryColor, Color(0xFF673AB7)],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) GoRouter.of(context).push('/shop_details?shopId=$shopId');
              } catch (_) {}
            },
          );
        }, onError: (Object e) {
          debugPrint('[NotifSvc] Offer listener error for shop $shopId: $e');
          _offerSubscriptions.remove(shopId);
        });
    debugPrint('[NotifSvc] Offer listener active for shopId=$shopId');
  }

  Future<String> _getShopName(String shopId) async {
    if (_shopNameCache.containsKey(shopId)) {
      return _shopNameCache[shopId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('searchable_shops')
          .doc(shopId)
          .get();
      if (doc.exists) {
        final name = doc.data()?['shopName'] as String?;
        if (name != null && name.isNotEmpty) {
          _shopNameCache[shopId] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('Error fetching shop name: $e');
    }
    return 'Nearby Shop';
  }

  Future<void> _initFirebaseMessaging() async {
    debugPrint('[NotifSvc] _initFirebaseMessaging start');
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[NotifSvc] FCM permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[NotifSvc] Error requesting FCM permissions: $e');
    }

    try {
      final token = await messaging.getToken();
      debugPrint('[NotifSvc] FCM token: $token');
    } catch (e) {
      debugPrint('[NotifSvc] Error fetching FCM token: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NotifSvc] onMessage (foreground) — messageId=${message.messageId} type=${message.data['type']} hasNotification=${message.notification != null} dataKeys=${message.data.keys.toList()}');

      final notification = message.notification;
      final isChat = message.data['type'] == 'chat';
      final shopId = message.data['shopId'] ?? '';
      final rtdbListenersActive = _offerSubscriptions.isNotEmpty;

      debugPrint('[NotifSvc] onMessage — isChat=$isChat shopId=$shopId rtdbListenersActive=$rtdbListenersActive');

      if (notification != null) {
        debugPrint('[NotifSvc] onMessage has notification payload — title="${notification.title}"');
        final title = notification.title ?? 'New Offer!';
        final body = notification.body ?? 'Check out the new offer nearby!';

        if (isChat) {
          debugPrint('[NotifSvc] onMessage: showing chat notification (notification payload)');
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
          debugPrint('[NotifSvc] onMessage: showing offer notification via FCM (no RTDB listeners yet)');
          _showNativeNotification(
            title,
            body,
            payload: json.encode({
              'type': 'offer',
              'shopId': shopId,
            }),
          );
          _showForegroundNotification(
            title,
            body,
            icon: Icons.campaign,
            gradientColors: const [AppTheme.primaryColor, Color(0xFF673AB7)],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) {
                  if (shopId.isNotEmpty) {
                    GoRouter.of(context).push('/shop_details?shopId=$shopId');
                  } else {
                    GoRouter.of(context).push('/all_offers');
                  }
                }
              } catch (_) {}
            },
          );
        } else {
          debugPrint('[NotifSvc] onMessage: non-chat FCM notification skipped — RTDB listeners are active');
        }
        return;
      }

      // Data-only message
      if (message.data.isNotEmpty) {
        debugPrint('[NotifSvc] onMessage: data-only message — isChat=$isChat');
        final title = message.data['title'] ?? (isChat ? 'New message' : 'New Offer!');
        final body = message.data['body'] ??
            (isChat ? 'You have a new message.' : 'Check out the new offer nearby!');

        if (isChat) {
          final shopName = message.data['shopName'] ?? 'Shop';
          debugPrint('[NotifSvc] onMessage: showing chat notification (data-only) shopId=$shopId shopName="$shopName"');
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
          debugPrint('[NotifSvc] onMessage: showing offer notification via FCM fallback (data-only)');
          _showNativeNotification(
            title,
            body,
            payload: json.encode({
              'type': 'offer',
              'shopId': shopId,
            }),
          );
          _showForegroundNotification(
            title,
            body,
            icon: Icons.campaign,
            gradientColors: const [AppTheme.primaryColor, Color(0xFF673AB7)],
            onTap: () {
              try {
                final context = rootNavigatorKey.currentContext;
                if (context != null) {
                  if (shopId.isNotEmpty) {
                    GoRouter.of(context).push('/shop_details?shopId=$shopId');
                  } else {
                    GoRouter.of(context).push('/all_offers');
                  }
                }
              } catch (_) {}
            },
          );
        } else {
          debugPrint('[NotifSvc] onMessage: non-chat data-only FCM skipped — RTDB listeners active');
        }
      } else {
        debugPrint('[NotifSvc] onMessage: empty data and no notification — nothing to show');
      }
    });

    messaging.onTokenRefresh.listen((token) {
      debugPrint('[NotifSvc] FCM token refreshed: $token');
      _syncDeviceRegistration();
    });

    debugPrint('[NotifSvc] _initFirebaseMessaging complete');
  }

  Future<void> _syncDeviceRegistration({LocationResult? location}) async {
    debugPrint('[NotifSvc] _syncDeviceRegistration start');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[NotifSvc] _syncDeviceRegistration: no user — skipping');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[NotifSvc] _syncDeviceRegistration: uid=${user.uid} token=${token ?? '<null>'}');
      if (token == null) {
        debugPrint('[NotifSvc] _syncDeviceRegistration: FCM token is null — cannot register');
        return;
      }

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
      debugPrint('[NotifSvc] _syncDeviceRegistration: wrote to users_devices/${user.uid}/customer — lat=${data['latitude']} lon=${data['longitude']} geohash=${data['geohash']}');
    } catch (e) {
      debugPrint('[NotifSvc] Error syncing device registration: $e');
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
    debugPrint('[NotifSvc] _showForegroundNotification — overlayAvailable=${overlay != null} title="$title"');
    if (overlay == null) {
      debugPrint('[NotifSvc] Overlay is null — app not in foreground or navigator not ready; skipping banner');
      return;
    }

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
