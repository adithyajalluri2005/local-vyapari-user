import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/location/location_cache.dart';
import 'package:local_vyapari_user/core/router/app_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

final notificationServiceProvider = Provider((ref) {
  final service = NotificationService(ref);
  service.init();
  
  // Listen to active browsing location changes to update topics and DB registry
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
  final Ref _ref;
  bool _initialized = false;
  final Set<String> _seenOfferIds = {};
  bool _firstLoadDone = false;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService(this._ref);

  void init() {
    if (_initialized) return;
    _initialized = true;

    _initLocalNotifications();
    _initFirebaseMessaging();
    _listenForNewOffers();

    // Sync device registration whenever the auth state changes (e.g. login/logout)
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncDeviceRegistration();
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            final context = rootNavigatorKey.currentContext;
            if (context != null) {
              GoRouter.of(context).go('/home');
            }
          } catch (e) {
            debugPrint('Error handling local notification click: $e');
          }
        },
      );

      // Request permissions for Android 13+
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<void> _showNativeNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'offers_channel_id',
      'Nearby Offers',
      channelDescription: 'Notifications for new offers in nearby shops',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );
      debugPrint('Triggered native notification: $title');
    } catch (e) {
      debugPrint('Error displaying native notification: $e');
    }
  }

  void _listenForNewOffers() {
    final dbRef = FirebaseDatabase.instance.ref('offers');

    dbRef.onValue.listen((event) async {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        _firstLoadDone = true;
        return;
      }

      try {
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
                  if (_firstLoadDone) {
                    newOffers.add(MapEntry(shopId, offerData));
                  }
                  _seenOfferIds.add(offerId);
                }
              }
            });
          }
        });

        _firstLoadDone = true;

        // Process any new offers detected
        for (final entry in newOffers) {
          final shopId = entry.key;
          final offerData = entry.value;
          final title = offerData['title'] ?? 'New Offer!';
          debugPrint('Detected new offer added in DB: $title (Shop ID: $shopId)');

          final isNearby = await _isShopNearby(shopId);
          if (isNearby) {
            final shopName = await _getShopName(shopId);
            final discount = offerData['discountPercentage'] ?? 0;
            final titleStr = 'New Offer at $shopName!';
            final bodyStr = '$title - Get ${discount.toInt()}% OFF!';
            
            await _showNativeNotification(titleStr, bodyStr);
            _showForegroundNotification(titleStr, bodyStr);
          } else {
            debugPrint('Offer "$title" was ignored because Shop ID $shopId is outside the 15km radius of the user\'s active location.');
          }
        }
      } catch (e) {
        debugPrint('Error listening for new offers: $e');
      }
    });
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

      return distanceInMeters <= 15000; // 15 km radius
    } catch (e) {
      debugPrint('Error checking nearby shop for notification: $e');
      return false;
    }
  }

  Future<String> _getShopName(String shopId) async {
    try {
      final shopSnapshot = await FirebaseDatabase.instance.ref('shop/$shopId/name').once();
      if (shopSnapshot.snapshot.exists && shopSnapshot.snapshot.value != null) {
        return shopSnapshot.snapshot.value.toString();
      }
      final shopNameSnapshot = await FirebaseDatabase.instance.ref('shop/$shopId/shopName').once();
      if (shopNameSnapshot.snapshot.exists && shopNameSnapshot.snapshot.value != null) {
        return shopNameSnapshot.snapshot.value.toString();
      }
    } catch (e) {
      debugPrint('Error fetching shop name for notification: $e');
    }
    return 'Nearby Shop';
  }

  Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions for iOS and Android 13+
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }

    // Listen to foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground notification received: ${message.messageId}');
      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? 'New Offer!';
        final body = notification.body ?? 'Check out the new offer nearby!';
        _showNativeNotification(title, body);
        _showForegroundNotification(title, body);
      }
    });

    // Listen to token refresh
    messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM Token refreshed: $token');
      _syncDeviceRegistration();
    });
  }

  Future<void> _syncDeviceRegistration({LocationResult? location}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final dbRef = FirebaseDatabase.instance.ref('users_devices/${user.uid}');

      // If location is null, attempt to read from cache
      LocationResult? activeLoc = location;
      if (activeLoc == null) {
        activeLoc = await LocationCache.getActiveLocation();
      }

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
      debugPrint('Device registration synced to RTDB for user: ${user.uid}');
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
        // Already subscribed to this hyperlocal zone
        await _syncDeviceRegistration(location: location);
        return;
      }

      final messaging = FirebaseMessaging.instance;

      // Unsubscribe from the old zone topic
      if (lastPrefix != null) {
        final oldTopic = 'offers_geo_$lastPrefix';
        await messaging.unsubscribeFromTopic(oldTopic);
        debugPrint('Unsubscribed from old topic: $oldTopic');
      }

      // Subscribe to the new zone topic
      final newTopic = 'offers_geo_$newPrefix';
      await messaging.subscribeToTopic(newTopic);
      debugPrint('Subscribed to new topic: $newTopic');

      // Update cache
      await _saveLastSubscribedGeohash(newPrefix);

      // Sync registration with the new location details
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
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
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

  void _showForegroundNotification(String title, String body) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => ForegroundNotificationBanner(
        title: title,
        body: body,
        onTap: () {
          // Route the user to the offers screen when the notification is tapped
          try {
            GoRouter.of(context).go('/home'); // Or appropriate navigation path
          } catch (_) {}
        },
        onDismissed: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class ForegroundNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const ForegroundNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  State<ForegroundNotificationBanner> createState() => _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState extends State<ForegroundNotificationBanner> with SingleTickerProviderStateMixin {
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismiss();
      }
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
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      top: mediaQuery.padding.top + 12,
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
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    Color(0xFF673AB7), // Sleek indigo/violet
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: Colors.white,
                      size: 24,
                    ),
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
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: _dismiss,
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
