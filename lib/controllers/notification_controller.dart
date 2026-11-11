import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/services/notification_service.dart';
import 'package:carauction/services/local_notification_service.dart';
import 'package:carauction/services/websocket_service.dart';
import 'package:carauction/controllers/app_state_controller.dart';
import 'package:carauction/screens/notifications_screen.dart';
import 'package:carauction/utils/preferences_helper.dart';

class NotificationController extends GetxController {
  final NotificationService _notificationService = NotificationService();
  final LocalNotificationService _localNotificationService = LocalNotificationService.instance;
  final WebSocketService _webSocketService = WebSocketService.instance;

  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;
  final RxString currentRole = ''.obs;
  final RxBool showUpcomingOnly = false.obs;

  // Track last notification ID to detect new notifications
  int? _lastNotificationId;
  bool _isPolling = false;
  /// Defensive: hide "new listing" if it references own seller_id (same account listed the car).
  String? _currentUserId;

  bool _isNotificationAuthFailure(Object e) {
    final s = e.toString();
    return s.contains('Authentication failed') || s.contains('Unauthenticated');
  }

  /// Seller-side inbox (your listing, bids you receive, etc.) — hide when Buyer switch is active.
  /// Note: `bid_accepted` / `bid_rejected` are buyer-targeted (win/reject); do not list here or buyers never see them.
  static const Set<String> _sellerNotificationTypes = {
    'vehicle_listed',
    'bid_received',
    'bid_accepted_seller',
    'buy_now_accepted_seller',
    'auction_ended',
    'auction_finalized',
    'auction_ended_early',
    'vehicle_sold',
    'swap_offer_received',
    'payment_received',
    'transport_scheduled',
  };

  /// Buyer-side feed — hide when Seller switch is active (optional separation).
  static const Set<String> _buyerNotificationTypes = {
    'new_listing',
    'bid_placed',
    'outbid',
    'buy_now',
    'bid_accepted',
    'buy_now_accepted',
    'buy_now_rejected',
    'purchase_confirmed',
    'swap_offer',
    'swap_offer_accepted',
    'auction_ending_soon',
    'new_match',
    'transport_update',
    'inspection_complete',
    'auction_won',
    'bid_rejected',
  };

  @override
  void onInit() {
    super.onInit();
    _loadCurrentRole();
    _initializeLocalNotifications();
    _trySetupWebSocketListener(); // Try WebSocket, but don't fail if unavailable
    fetchNotifications();
    // Refresh notifications every 10 seconds (faster polling for shared hosting)
    _startPeriodicRefresh();
  }

  Future<void> _loadCurrentRole() async {
    final role = (await PreferencesHelper.getEffectiveRoleForNotifications()).toLowerCase();
    currentRole.value = role;
  }

  /// Call when user toggles Buyer/Seller (seller/buyer account) so badge + API `role` query + inbox filter match mode.
  Future<void> onBuyerSellerModeChanged() async {
    _currentUserId = await PreferencesHelper.getUserId();
    await fetchNotifications();
  }

  /// After login/register — reload role, user id, then pull inbox from API (fixes empty list after auth).
  Future<void> refreshAfterAuth() async {
    await _loadCurrentRole();
    _currentUserId = await PreferencesHelper.getUserId();
    await fetchNotifications();
  }
  
  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      await _localNotificationService.initialize();
      // Set up notification tap handler
      _localNotificationService.onNotificationTap = (data) {
        _handleNotificationTap(data);
      };
      print('✅ NotificationController: Local notifications initialized');
    } catch (e) {
      print('❌ NotificationController: Failed to initialize local notifications: $e');
    }
  }
  
  /// Try to set up WebSocket listener (optional - works without it)
  void _trySetupWebSocketListener() {
    try {
      // Subscribe to notification events from WebSocket
      _webSocketService.subscribe('notification', (data) {
        _handleWebSocketNotification(data);
      });
      print('✅ NotificationController: WebSocket listener set up');
    } catch (e) {
      print('⚠️ NotificationController: WebSocket not available, using polling: $e');
      // Continue with polling - WebSocket is optional
    }
  }
  
  /// Handle notification received from WebSocket (if available)
  void _handleWebSocketNotification(Map<String, dynamic> data) {
    try {
      print('🔔 NotificationController: Received notification from WebSocket');
      print('   📦 Data: $data');
      
      final notification = data['notification'] as Map<String, dynamic>?;
      if (notification == null) {
        print('   ⚠️ No notification data in WebSocket message');
        return;
      }
      
      _processNewNotification(notification);
    } catch (e) {
      print('❌ NotificationController: Error handling WebSocket notification: $e');
    }
  }
  
  /// Process a new notification (from WebSocket or polling)
  void _processNewNotification(Map<String, dynamic> notification) {
    try {
      final notificationId = notification['id'];
      final type = notification['type'] as String? ?? 'unknown';
      final title = notification['title'] as String? ?? 'New Notification';
      final message = notification['message'] as String? ?? '';
      final notificationData = notification['data'] as Map<String, dynamic>?;
      
      // Check if this is a new notification (not already in list)
      final existingIndex = notifications.indexWhere((n) => n['id'].toString() == notificationId.toString());
      if (existingIndex != -1) {
        // Already exists, skip
        return;
      }
      
      // Add notification to local list
      notifications.insert(0, {
        'id': notificationId,
        'type': type,
        'title': title,
        'message': message,
        'data': notificationData,
        'is_read': false,
        'created_at': notification['created_at'] ?? DateTime.now().toIso8601String(),
      });
      
      // Update unread count
      unreadCount.value++;
      
      // Show local notification
      _localNotificationService.showNotification(
        title: title,
        body: message,
        type: type,
        data: {
          'notification_id': notificationId,
          'type': type,
          'related_type': notification['related_type'],
          'related_id': notification['related_id'],
          ...?notificationData,
        },
      );
      
      print('✅ NotificationController: New notification processed and shown');
    } catch (e) {
      print('❌ NotificationController: Error processing notification: $e');
    }
  }
  
  /// Handle notification tap (from local notification)
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      print('👆 NotificationController: Notification tapped from notification bar');
      print('   📦 Data: $data');
      
      final notificationId = data['notification_id'];
      
      // Mark notification as read if ID is available
      if (notificationId != null) {
        markAsRead(notificationId.toString());
      }
      
      // Navigate to notifications screen
      // User can tap the notification there to open the related page
      try {
        final context = Get.context;
        if (context != null) {
          // Navigate to notifications screen using GetX
          Get.to(() => const NotificationsScreen());
        } else {
          print('⚠️ No context available for navigation');
          fetchNotifications();
        }
      } catch (e) {
        print('⚠️ Error navigating to notifications screen: $e');
        fetchNotifications();
      }
    } catch (e) {
      print('❌ NotificationController: Error handling notification tap: $e');
    }
  }

  Timer? _refreshTimer;

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForNewNotifications();
    });
    print('✅ Notification periodic refresh started (10s)');
  }
  
  /// Check for new notifications (polling-based approach for shared hosting)
  Future<void> _checkForNewNotifications() async {
    if (_isPolling) {
      return; // Already polling, skip
    }
    
    try {
      _isPolling = true;
      await _loadCurrentRole();
      _currentUserId = await PreferencesHelper.getUserId();
      final response = await _notificationService.getNotifications();
      
      if (response['notifications'] != null) {
        final newNotifications = List<Map<String, dynamic>>.from(response['notifications']);
        
        // Find new notifications (not in current list)
        for (var newNotif in newNotifications) {
          if (!_isNotificationVisibleForCurrentRole(newNotif)) {
            continue;
          }
          final newId = newNotif['id'];
          final exists = notifications.any((n) => n['id'].toString() == newId.toString());
          
          if (!exists) {
            // This is a new notification - show it
            _processNewNotification(newNotif);
          }
        }
        
        // Update unread count
        if (response['unread_count'] != null) {
          unreadCount.value = response['unread_count'] as int;
        }
      }
    } catch (e) {
      if (!_isNotificationAuthFailure(e)) {
        print('❌ NotificationController: Error checking for new notifications: $e');
      }
    } finally {
      _isPolling = false;
    }
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  Future<void> fetchNotifications() async {
    try {
      isLoading.value = true;
      await _loadCurrentRole();
      final response = await _notificationService.getNotifications();
      
      if (response['notifications'] != null) {
        final fetchedNotifications = List<Map<String, dynamic>>.from(response['notifications'])
            .where(_isNotificationVisibleForCurrentRole)
            .toList();
        
        // Store last notification ID for comparison
        if (fetchedNotifications.isNotEmpty) {
          _lastNotificationId = fetchedNotifications.first['id'] as int?;
        }
        
        // Update notifications list
        notifications.assignAll(fetchedNotifications);
      }
      
      if (response['unread_count'] != null) {
        unreadCount.value = response['unread_count'] as int;
      }
    } catch (e) {
      if (!_isNotificationAuthFailure(e)) {
        print('❌ Error fetching notifications: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      // Update local state
      final index = notifications.indexWhere((n) => n['id'].toString() == notificationId);
      if (index != -1) {
        notifications[index]['is_read'] = true;
        if (unreadCount.value > 0) {
          unreadCount.value--;
        }
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  bool _isNotificationVisibleForCurrentRole(Map<String, dynamic> notification) {
    final role = currentRole.value;
    final type = (notification['type'] ?? '').toString().toLowerCase();
    final data = notification['data'];

    final notifUid = notification['user_id']?.toString();
    final isMine =
        notifUid != null && _currentUserId != null && notifUid == _currentUserId;

    // Personal rows still respect Buyer vs Seller mode (seller/buyer accounts).
    if (isMine) {
      if (role == 'buyer' && _sellerNotificationTypes.contains(type)) {
        return false;
      }
      if ((role == 'seller' || role == 'dealer') &&
          _buyerNotificationTypes.contains(type)) {
        return false;
      }
      return true;
    }

    if (type == 'new_listing' && data is Map) {
      final sid = data['seller_id']?.toString();
      final my = _currentUserId;
      if (sid != null && my != null && sid == my) {
        return false;
      }
    }
    if ((role == 'seller' || role == 'dealer') && type == 'new_listing') {
      return false;
    }

    if (role.isEmpty) return true;

    final targetRoles = notification['target_roles'];
    if (targetRoles is List && targetRoles.isNotEmpty) {
      final targets = targetRoles.map((e) => e.toString().toLowerCase()).toList();
      if (targets.contains('all') || targets.contains(role)) return true;
      // seller/buyer users should receive both buyer and seller events
      if (role == 'seller/buyer' && (targets.contains('seller') || targets.contains('buyer') || targets.contains('seller/buyer'))) {
        return true;
      }
      return false;
    }

    return _isTypeAllowedForRole(type, role);
  }

  bool _isTypeAllowedForRole(String type, String role) {
    const buyerTypes = {
      'bid_placed',
      'outbid',
      'buy_now',
      'bid_accepted',
      'buy_now_accepted',
      'buy_now_rejected',
      'bid_rejected',
      'purchase_confirmed',
      'swap_offer',
      'swap_offer_accepted',
      'auction_ending_soon',
      'new_match',
      'transport_update',
      'inspection_complete',
      'auction_won',
      'new_listing',
    };
    const sellerTypes = {
      'bid_received',
      'bid_accepted_seller',
      'buy_now_accepted_seller',
      'auction_ended',
      'auction_finalized',
      'auction_ended_early',
      'vehicle_sold',
      'swap_offer_received',
      'payment_received',
      'transport_scheduled',
      'vehicle_listed',
    };
    const inspectorTypes = {
      'inspection_requested',
      'inspection_assigned',
      'inspection_submitted',
      'inspection_cancelled',
      'inspection_rescheduled',
    };
    const transporterTypes = {
      'transport_assigned',
      'transport_pickup_due',
      'transport_in_transit',
      'transport_delivered',
      'transport_cancelled',
      'transport_update',
    };

    if (role == 'seller/buyer') {
      return buyerTypes.contains(type) || sellerTypes.contains(type);
    }
    if (role == 'buyer') return buyerTypes.contains(type);
    if (role == 'seller' || role == 'dealer') return sellerTypes.contains(type);
    if (role == 'inspector') return inspectorTypes.contains(type);
    if (role == 'transporter') return transporterTypes.contains(type);
    return true;
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      // Update local state
      for (var notification in notifications) {
        notification['is_read'] = true;
      }
      unreadCount.value = 0;
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Check if it was unread before deleting
      final notification = notifications.firstWhere(
        (n) => n['id'].toString() == notificationId,
        orElse: () => <String, dynamic>{},
      );
      final wasUnread = notification['is_read'] == false;
      
      await _notificationService.deleteNotification(notificationId);
      // Update local state
      notifications.removeWhere((n) => n['id'].toString() == notificationId);
      
      // Decrement unread count if it was unread
      if (wasUnread && unreadCount.value > 0) {
        unreadCount.value--;
      }
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  List<Map<String, dynamic>> get visibleNotifications {
    if (!showUpcomingOnly.value) {
      return notifications;
    }
    return notifications.where(_isUpcomingNotification).toList();
  }

  void setShowUpcomingOnly(bool value) {
    showUpcomingOnly.value = value;
  }

  bool _isUpcomingNotification(Map<String, dynamic> notification) {
    final type = (notification['type'] ?? '').toString().toLowerCase();
    const upcomingTypes = {
      'auction_ending_soon',
      'inspection_rescheduled',
      'transport_pickup_due',
      'transport_assigned',
      'transport_scheduled',
    };
    if (upcomingTypes.contains(type)) {
      return true;
    }

    final data = notification['data'];
    if (data is Map<String, dynamic>) {
      final dateKeys = ['scheduled_at', 'pickup_at', 'inspection_at', 'event_at', 'due_at'];
      for (final key in dateKeys) {
        final raw = data[key];
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null && parsed.isAfter(DateTime.now())) {
          return true;
        }
      }
    }
    return false;
  }

  String getNotificationIcon(String type) {
    switch (type) {
      // Buyer notifications
      case 'bid_placed':
        return 'gavel';
      case 'outbid':
        return 'trending_down';
      case 'buy_now':
        return 'shopping_cart';
      case 'buy_now_accepted':
      case 'buy_now_accepted_seller':
        return 'shopping_cart';
      case 'buy_now_rejected':
        return 'cancel';
      case 'purchase_confirmed':
        return 'check_circle';
      case 'swap_offer':
        return 'swap_horiz';
      case 'swap_offer_accepted':
        return 'check_circle_outline';
      case 'auction_ending_soon':
        return 'schedule';
      case 'new_listing':
        return 'directions_car';
      case 'vehicle_listed':
        return 'check_circle';
      case 'new_match':
        return 'search';
      case 'transport_update':
        return 'local_shipping';
      case 'inspection_complete':
        return 'assignment';
      // Seller notifications
      case 'bid_received':
        return 'gavel';
      case 'bid_accepted':
      case 'bid_accepted_seller':
        return 'check_circle';
      case 'bid_rejected':
        return 'cancel';
      case 'auction_ended':
      case 'auction_finalized':
        return 'event_busy';
      case 'auction_ended_early':
        return 'event_available';
      case 'vehicle_sold':
        return 'monetization_on';
      case 'swap_offer_received':
        return 'swap_horiz';
      case 'payment_received':
        return 'payment';
      case 'transport_scheduled':
        return 'local_shipping';
      case 'auction_won':
        return 'emoji_events';
      // Inspector notifications
      case 'inspection_requested':
        return 'assignment_late';
      case 'inspection_assigned':
        return 'assignment_ind';
      case 'inspection_submitted':
      case 'inspection_complete':
        return 'fact_check';
      case 'inspection_cancelled':
        return 'cancel';
      case 'inspection_rescheduled':
        return 'update';
      // Transporter notifications
      case 'transport_assigned':
        return 'inventory_2';
      case 'transport_pickup_due':
        return 'schedule_send';
      case 'transport_in_transit':
        return 'local_shipping';
      case 'transport_delivered':
        return 'task_alt';
      case 'transport_cancelled':
        return 'cancel_schedule_send';
      default:
        return 'notifications';
    }
  }

  Color getNotificationColor(String type) {
    switch (type) {
      // Buyer notifications
      case 'bid_placed':
      case 'buy_now':
      case 'buy_now_accepted':
      case 'buy_now_accepted_seller':
      case 'purchase_confirmed':
        return Colors.green;
      case 'buy_now_rejected':
        return Colors.red;
      case 'outbid':
        return Colors.orange;
      case 'auction_ending_soon':
        return Colors.red;
      case 'new_listing':
        return Colors.green;
      case 'vehicle_listed':
        return Colors.teal;
      case 'swap_offer':
      case 'swap_offer_accepted':
        return Colors.blue;
      // Seller notifications
      case 'bid_received':
      case 'bid_accepted':
      case 'bid_accepted_seller':
      case 'vehicle_sold':
      case 'payment_received':
      case 'auction_finalized':
        return Colors.green;
      case 'bid_rejected':
        return Colors.red;
      case 'auction_ended':
      case 'auction_ended_early':
        return Colors.orange;
      case 'swap_offer_received':
      case 'transport_scheduled':
        return Colors.blue;
      case 'auction_won':
        return Colors.amber;
      // Inspector notifications
      case 'inspection_requested':
      case 'inspection_assigned':
      case 'inspection_rescheduled':
        return Colors.indigo;
      case 'inspection_submitted':
      case 'inspection_complete':
        return Colors.teal;
      case 'inspection_cancelled':
        return Colors.red;
      // Transporter notifications
      case 'transport_assigned':
      case 'transport_pickup_due':
      case 'transport_in_transit':
        return Colors.deepPurple;
      case 'transport_delivered':
        return Colors.green;
      case 'transport_cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

