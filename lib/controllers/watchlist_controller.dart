import 'dart:async';
import 'package:get/get.dart';
import 'package:carauction/services/watchlist_service.dart';
import 'package:carauction/controllers/app_state_controller.dart';

class WatchlistController extends GetxController {
  final WatchlistService _watchlistService = WatchlistService();

  final RxList<dynamic> watchlist = <dynamic>[].obs;
  final RxBool isLoading = false.obs;
  final RxMap<String, bool> watchlistStatus = <String, bool>{}.obs; // vehicleId -> isWatched
  final Rx<String?> loadingVehicleId = Rx<String?>(null); // vehicleId being toggled (for button loading)

  Timer? _refreshTimer; // Timer for real-time updates

  @override
  void onInit() {
    super.onInit();
    fetchWatchlist();
    // _startPeriodicRefresh(); // Disabled - refresh only when data comes from database
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  /// Start periodic refresh for real-time updates
  void _startPeriodicRefresh() {
    // DISABLED: Refresh only when data comes from database, not periodic polling
    _refreshTimer?.cancel();
    print('✅ Periodic refresh disabled - refresh only when data comes from database');
  }

  /// Fetch user's watchlist
  Future<void> fetchWatchlist() async {
    try {
      isLoading.value = true;
      print('📋 WatchlistController: Fetching watchlist...');
      final items = await _watchlistService.getWatchlist();
      print('✅ WatchlistController: Received ${items.length} items');
      
      // Debug: Print first item structure
      if (items.isNotEmpty) {
        print('📦 WatchlistController: First item structure: ${items[0]}');
      }
      
      watchlist.value = items;
      
      // Update watchlist status map
      for (var item in items) {
        final vehicleId = item['vehicle_id']?.toString() ?? item['vehicle']?['id']?.toString();
        if (vehicleId != null) {
          watchlistStatus[vehicleId] = true;
        }
      }
      
      print('✅ WatchlistController: Watchlist updated, total items: ${watchlist.length}');
    } catch (e) {
      print('❌ Error fetching watchlist: $e');
      watchlist.clear(); // Clear watchlist on error
    } finally {
      isLoading.value = false;
    }
  }

  /// Add vehicle to watchlist
  Future<bool> addToWatchlist(String vehicleId) async {
    try {
      await _watchlistService.addToWatchlist(vehicleId);
      watchlistStatus[vehicleId] = true;
      await fetchWatchlist(); // Refresh watchlist
      return true;
    } catch (e) {
      print('❌ Error adding to watchlist: $e');
      return false;
    }
  }

  /// Remove vehicle from watchlist
  Future<bool> removeFromWatchlist(String vehicleId) async {
    try {
      await _watchlistService.removeFromWatchlist(vehicleId);
      watchlistStatus[vehicleId] = false;
      await fetchWatchlist(); // Refresh watchlist
      return true;
    } catch (e) {
      print('❌ Error removing from watchlist: $e');
      return false;
    }
  }

  /// Toggle watchlist status
  Future<void> toggleWatchlist(String vehicleId) async {
    loadingVehicleId.value = vehicleId;
    try {
      final isWatched = watchlistStatus[vehicleId] ?? false;
      if (isWatched) {
        await removeFromWatchlist(vehicleId);
      } else {
        await addToWatchlist(vehicleId);
      }
    } finally {
      loadingVehicleId.value = null;
    }
  }

  /// Check if vehicle is in watchlist
  Future<void> checkWatchlistStatus(String vehicleId) async {
    try {
      final isWatched = await _watchlistService.checkWatchlist(vehicleId);
      watchlistStatus[vehicleId] = isWatched;
    } catch (e) {
      print('❌ Error checking watchlist status: $e');
      watchlistStatus[vehicleId] = false;
    }
  }

  /// Get watchlist status for a vehicle
  bool isWatched(String vehicleId) {
    return watchlistStatus[vehicleId] ?? false;
  }
}

