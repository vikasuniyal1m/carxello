// lib/services/auto_sync_service.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/controllers/watchlist_controller.dart';
import 'package:carauction/controllers/notification_controller.dart';

class AutoSyncService extends GetxService {
  static AutoSyncService get to => Get.find();

  // Sync intervals (in seconds)
  static const int SYNC_INTERVAL = 30; // Har 30 second mein sync
  static const int NOTIFICATION_CHECK_INTERVAL = 15; // Har 15 second mein notifications

  Timer? _syncTimer;
  Timer? _notificationTimer;

  // Track last sync times
  DateTime _lastFullSync = DateTime.now();
  DateTime _lastNotificationCheck = DateTime.now();

  @override
  void onInit() {
    super.onInit();
    startAutoSync();
  }

  void startAutoSync() {
    // Stop existing timers
    stopAutoSync();

    // Full data sync timer (har 30 sec)
    _syncTimer = Timer.periodic(
      Duration(seconds: SYNC_INTERVAL),
          (timer) => _performFullSync(),
    );

    // Notification check timer (har 15 sec - faster for notifications)
    _notificationTimer = Timer.periodic(
      Duration(seconds: NOTIFICATION_CHECK_INTERVAL),
          (timer) => _checkNotifications(),
    );

    print('🔄 AutoSyncService started - Full sync every $SYNC_INTERVAL sec, Notifications every $NOTIFICATION_CHECK_INTERVAL sec');
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _notificationTimer?.cancel();
    print('🔄 AutoSyncService stopped');
  }

  Future<void> _performFullSync() async {
    try {
      print('🔄 Auto sync running at ${DateTime.now()}');

      // Sync HomePageController
      if (Get.isRegistered<HomePageController>()) {
        final homeCtrl = Get.find<HomePageController>();

        // Agar buyer hai toh cars sync karo
        if (homeCtrl.isBuyer.value) {
          await homeCtrl.fetchCars();
          await homeCtrl.fetchBuyerDashboardData();
        } else {
          // Seller hai toh seller data sync karo
          await homeCtrl.fetchCars(); // Seller ki listings
          await homeCtrl.fetchSellerDashboardData();
        }

        // Won vehicles aur purchase history bhi sync
        if (homeCtrl.isBuyer.value) {
          await homeCtrl.fetchWonVehicles();
          await homeCtrl.fetchPurchaseHistory();
        }
      }

      // Sync BidController (bids data)
      if (Get.isRegistered<BidController>()) {
        final bidCtrl = Get.find<BidController>();
        await bidCtrl.fetchMyBids();
        await bidCtrl.fetchSwapOffers();
      }

      // Sync WatchlistController (watchlist status)
      if (Get.isRegistered<WatchlistController>()) {
        final watchCtrl = Get.find<WatchlistController>();
        await watchCtrl.fetchWatchlist();
      }

      _lastFullSync = DateTime.now();
      print('✅ Auto sync completed at $_lastFullSync');

    } catch (e) {
      print('❌ Auto sync error: $e');
    }
  }

  Future<void> _checkNotifications() async {
    try {
      if (Get.isRegistered<NotificationController>()) {
        final notifCtrl = Get.find<NotificationController>();
        await notifCtrl.fetchNotifications();
      }
      _lastNotificationCheck = DateTime.now();
    } catch (e) {
      print('❌ Notification check error: $e');
    }
  }

  // Manual sync trigger (for pull-to-refresh ya button click)
  Future<void> triggerManualSync() async {
    print('👆 Manual sync triggered');
    await _performFullSync();
  }

  @override
  void onClose() {
    stopAutoSync();
    super.onClose();
  }
}