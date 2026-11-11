import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Push Notification Service
///
/// Handles:
/// - Notification display
/// - Background/foreground notifications
/// - Notification actions
class PushNotificationService {
  static PushNotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AuthService _authService = AuthService();
  
  bool _isInitialized = false;
  
  // Notification callbacks
  Function(Map<String, dynamic>)? onNotificationTap;
  Function(Map<String, dynamic>)? onNotificationReceived;
  
  PushNotificationService._();
  
  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }
  
  /// Initialize push notifications
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      _isInitialized = true;
      print('✅ Push Notifications: Initialized successfully');
      return true;
    } catch (e) {
      print('❌ Push Notifications: Initialization failed: $e');
      return false;
    }
  }
  
  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Fixed: Using named parameter 'settings' as required by the compiler error
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = json.decode(details.payload!) as Map<String, dynamic>;
            onNotificationTap?.call(data);
          } catch (e) {
            print('⚠️ Push Notifications: Error parsing payload: $e');
          }
        }
      },
    );
  }
  
  /// Dispose resources
  void dispose() {
    // FCM doesn't need explicit disposal
  }
}