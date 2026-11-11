import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

/// Local Notification Service
/// 
/// Handles local notifications triggered by WebSocket events from backend
class LocalNotificationService {
  static LocalNotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  
  // Notification callbacks
  Function(Map<String, dynamic>)? onNotificationTap;
  
  LocalNotificationService._();
  
  static LocalNotificationService get instance {
    _instance ??= LocalNotificationService._();
    return _instance!;
  }
  
  /// Initialize local notifications
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Request notification permission for Android 13+ (API 33+)
      if (await Permission.notification.isDenied) {
        print('🔔 LocalNotificationService: Requesting notification permission...');
        final result = await Permission.notification.request();
        if (result.isGranted) {
          print('✅ LocalNotificationService: Notification permission granted');
        } else {
          print('⚠️ LocalNotificationService: Notification permission denied: $result');
          print('⚠️ Notifications may not appear in notification bar');
        }
      } else {
        print('✅ LocalNotificationService: Notification permission already granted');
      }
      
      // Request location permission at startup
      if (await Permission.location.isDenied) {
        print('📍 LocalNotificationService: Requesting location permission...');
        final locationResult = await Permission.location.request();
        if (locationResult.isGranted) {
          print('✅ LocalNotificationService: Location permission granted');
        } else {
          print('⚠️ LocalNotificationService: Location permission denied: $locationResult');
        }
      } else {
        print('✅ LocalNotificationService: Location permission already granted');
      }
      
      // Initialize Android settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Initialize iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      // Initialize with notification tap handler
      await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            _handleNotificationTap(response);
          },
        );
      
      // Create notification channel for Android (required for showing notifications)
      try {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          const androidChannel = AndroidNotificationChannel(
            'car_auction_notifications',
            'Car Auction Notifications',
            description: 'Notifications for bids, auctions, and messages',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );
          
          await androidImplementation.createNotificationChannel(androidChannel);
          print('✅ LocalNotificationService: Notification channel created: car_auction_notifications');
        } else {
          print('⚠️ LocalNotificationService: Android notification implementation not available');
        }
      } catch (e) {
        print('⚠️ LocalNotificationService: Error creating notification channel: $e');
      }
      
      _isInitialized = true;
      print('✅ LocalNotificationService: Initialized successfully');
      return true;
    } catch (e) {
      print('❌ LocalNotificationService: Failed to initialize: $e');
      return false;
    }
  }
  
  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    try {
      print('🔔 LocalNotificationService: Notification tapped');
      print('   📱 Notification ID: ${response.id}');
      
      if (response.payload != null) {
        try {
          final data = json.decode(response.payload!) as Map<String, dynamic>;
          print('   📦 Payload: $data');
          onNotificationTap?.call(data);
        } catch (e) {
          print('   ⚠️ Error parsing notification payload: $e');
        }
      } else {
        print('   ⚠️ No payload in notification');
      }
    } catch (e) {
      print('   ❌ Error handling notification tap: $e');
    }
  }
  
  /// Show local notification
  /// 
  /// [title] - Notification title
  /// [body] - Notification body/message
  /// [type] - Notification type (e.g., 'bid_received', 'outbid', etc.)
  /// [data] - Additional data to pass with notification
  Future<void> showNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (!_isInitialized) {
        print('⚠️ LocalNotificationService: Not initialized, initializing now...');
        await initialize();
      }
      
      // Ensure permission is granted
      if (await Permission.notification.isDenied) {
        print('⚠️ LocalNotificationService: Notification permission denied - notification will not show');
        return;
      }
      
      // Get icon based on notification type
      final icon = _getNotificationIcon(type);

      // Android: use colorized white background so title/body read as dark text on light
      // (avoids dark charcoal system-style shade from accent-only `color` tinting).
      const androidLightSurface = Color(0xFFFFFFFF);
      final androidDetails = AndroidNotificationDetails(
        'car_auction_notifications',
        'Car Auction Notifications',
        channelDescription: 'Notifications for bids, auctions, and messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: icon,
        color: androidLightSurface,
        colorized: true,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      );
      
      // Create iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Generate unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      // Prepare payload
      final payload = json.encode({
        'type': type,
        'data': data ?? {},
      });
      
      print('🔔 LocalNotificationService: Showing notification');
      print('   📱 ID: $notificationId');
      print('   📝 Title: $title');
      print('   📄 Body: $body');
      print('   🏷️ Type: $type');
      
      // Show notification
      await _localNotifications.show(
        id: notificationId, // `id` is now a named parameter
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      
      print('✅ LocalNotificationService: Notification shown successfully');
    } catch (e) {
      print('❌ LocalNotificationService: Failed to show notification: $e');
    }
  }
  
  /// Get notification icon based on type
  String _getNotificationIcon(String type) {
    switch (type) {
      // Buyer notifications
      case 'bid_placed':
        return '@mipmap/ic_launcher';
      case 'outbid':
        return '@mipmap/ic_launcher';
      case 'buy_now':
      case 'buy_now_accepted':
        return '@mipmap/ic_launcher';
      case 'purchase_confirmed':
        return '@mipmap/ic_launcher';
      case 'swap_offer':
      case 'swap_offer_accepted':
        return '@mipmap/ic_launcher';
      case 'auction_ending_soon':
        return '@mipmap/ic_launcher';
      case 'transport_update':
        return '@mipmap/ic_launcher';
      case 'inspection_complete':
        return '@mipmap/ic_launcher';
      // Seller notifications
      case 'bid_received':
        return '@mipmap/ic_launcher';
      case 'bid_accepted':
      case 'bid_rejected':
        return '@mipmap/ic_launcher';
      case 'auction_ended':
      case 'auction_finalized':
        return '@mipmap/ic_launcher';
      case 'vehicle_sold':
        return '@mipmap/ic_launcher';
      case 'swap_offer_received':
        return '@mipmap/ic_launcher';
      case 'payment_received':
        return '@mipmap/ic_launcher';
      case 'transport_scheduled':
        return '@mipmap/ic_launcher';
      case 'buy_now_received':
        return '@mipmap/ic_launcher';
      default:
        return '@mipmap/ic_launcher';
    }
  }
  
  /// Cancel all notifications
  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
      print('✅ LocalNotificationService: All notifications cancelled');
    } catch (e) {
      print('❌ LocalNotificationService: Failed to cancel notifications: $e');
    }
  }
  
  /// Cancel specific notification
  Future<void> cancel(int notificationId) async {
    try {
      await _localNotifications.cancel(id: notificationId);
      print('✅ LocalNotificationService: Notification $notificationId cancelled');
    } catch (e) {
      print('❌ LocalNotificationService: Failed to cancel notification: $e');
    }
  }
}
