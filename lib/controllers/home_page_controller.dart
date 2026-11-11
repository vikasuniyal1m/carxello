import 'dart:async';
import 'package:get/get.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/saved_search_service.dart';
import 'package:carauction/services/websocket_service.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/models/saved_search.dart';
import 'package:flutter/material.dart'; // Added for ScrollController
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carauction/controllers/app_state_controller.dart';
import 'package:carauction/controllers/notification_controller.dart';
import 'package:carauction/controllers/bid_controller.dart';

class HomePageController extends GetxController {
  final CarService _carService = CarService();
  final SavedSearchService _savedSearchService = SavedSearchService();

  final CarouselSliderController carouselController = CarouselSliderController();
  final ScrollController scrollController = ScrollController();

  AnimationController? animationController;
  Animation<double>? scaleAnimation;

  final RxInt currentCarouselIndex = 0.obs;
  final RxInt selectedTab = 0.obs; // For buyer tabs
  final RxInt selectedSellerTab = 0.obs; // For seller main tabs (Active Sales, Inventory, Performance)
  final RxInt selectedSellerSubTab = 0.obs; // For seller sub-tabs (Active, Sold, Draft for Inventory)
  final RxBool isBuyer = true.obs;
  final RxList<Car> carList = <Car>[].obs;
  final RxList<Car> sellerListings = <Car>[].obs; // Seller's own listings
  final RxList<Car> wonVehicles = <Car>[].obs; // Buyer's won vehicles
  final RxList<Car> purchaseHistory = <Car>[].obs; // Buyer's purchase history
  final RxBool isLoading = true.obs;
  final RxBool isLoadingWonVehicles = false.obs; // Loading state for won vehicles
  final RxBool isLoadingPurchaseHistory = false.obs; // Loading state for purchase history
  final RxDouble scrollOffset = 0.0.obs; // Reactive variable to store scroll offset
  final RxList<SavedSearch> savedSearches = <SavedSearch>[].obs; // List of saved searches
  final RxString currentUserId = ''.obs; // Current logged in user ID

  // Buyer dashboard data
  final Rx<Map<String, dynamic>?> buyerDashboard = Rx<Map<String, dynamic>?>(null);

  // Seller dashboard data
  final Rx<Map<String, dynamic>?> sellerStats = Rx<Map<String, dynamic>?>(null);
  final RxList<dynamic> pendingOffers = <dynamic>[].obs;
  final RxList<dynamic> sellerVehicles = <dynamic>[].obs; // Seller's vehicles with auction data
  final RxList<dynamic> liveAuctions = <dynamic>[].obs;
  final RxList<dynamic> endedAuctions = <dynamic>[].obs;
  final RxList<Car> pendingTransport = <Car>[].obs;
  final RxList<Car> scheduledTransport = <Car>[].obs;

  /// Manage bids tab (seller): matches website seller-bids.php filters.
  final RxString manageBidsFilter = 'pending_bids'.obs;

  void setManageBidsFilter(String value) {
    manageBidsFilter.value = value;
  }

  // Filter and sort state
  Map<String, dynamic>? currentFilters;
  String? currentSortBy;

  final List<String> imgList = [
    'assets/images/car1.png',
    'assets/images/car2.png',
    'assets/images/car3.png',
  ];

  void initAnimation(TickerProvider vsync) {
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
    scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: animationController!, curve: Curves.easeOut),
    );
  }

  void disposeAnimation() {
    animationController?.dispose();
    animationController = null;
    scaleAnimation = null;
  }

  Timer? _refreshTimer; // Periodic refresh timer for real-time updates
  double? _savedScrollPosition; // Save scroll position during periodic refresh
  bool _isSmartRefresh = false; // Flag to enable smart refresh (incremental updates)

  @override
  void onInit() {
    super.onInit();

    // CRITICAL: Remove any existing listeners from previous instances
    // This prevents "multiple scroll views" error when GetX reuses controller
    try {
      scrollController.removeListener(_updateScrollOffset);
      scrollController.removeListener(_updateScrollOffset);
      scrollController.removeListener(_updateScrollOffset);
    } catch (e) {
      // Listener might not exist, that's okay
    }

    // Don't add listener here - NotificationListener in home_page.dart handles scroll offset
    // This prevents multiple attachments
    // Set loading to true initially - will be set to false after data loads
    isLoading.value = true;
    
    // Load current user ID
    PreferencesHelper.getUserId().then((id) {
      if (id != null) currentUserId.value = id;
    });

    // Load data immediately when controller initializes (no delays, no conditions)
    // This ensures data loads as soon as page opens
    fetchCars(); // Load immediately - page will show loading until data is ready

    _restoreBuyerSellerModeFromPrefs();
    // Setup WebSocket streaming for real-time updates (non-blocking)
    _setupWebSocketStreaming();
    // Disable auto refresh - refresh only when data comes from database/WebSocket
    // _startPeriodicRefresh(); // Disabled - refresh only when data comes from table
  }

  /// Setup WebSocket streaming - only updates when changes occur
  void _setupWebSocketStreaming() {
    final wsService = WebSocketService.instance;

    // Store callbacks for cleanup
    _carUpdateCallback = (data) {
      print('📡 WebSocket: Car updated event received');
      _handleCarUpdate(data);
    };

    _carAddedCallback = (data) {
      print('📡 WebSocket: New car added event received');
      _handleCarAdded(data);
    };

    _carRemovedCallback = (data) {
      print('📡 WebSocket: Car removed event received');
      _handleCarRemoved(data);
    };

    _bidUpdateCallback = (data) {
      print('📡 WebSocket: Bid placed event received');
      _handleBidUpdate(data);
    };

    // Subscribe to car/listing update events
    wsService.subscribe('car_updated', _carUpdateCallback!);
    wsService.subscribe('car_added', _carAddedCallback!);
    wsService.subscribe('car_removed', _carRemovedCallback!);
    wsService.subscribe('bid_placed', _bidUpdateCallback!);

    // Subscribe to all events for debugging
    wsService.subscribe('all', (data) {
      print('📡 WebSocket: Event received: ${data['type']}');
    });

    // Try to connect WebSocket
    wsService.connect().then((connected) {
      if (connected) {
        print('✅ WebSocket streaming enabled for real-time updates');
        // Cancel periodic refresh if WebSocket is connected
        _refreshTimer?.cancel();
      } else {
        print('⚠️ WebSocket not available - enabling polling fallback for real-time updates');
        // Enable periodic refresh as fallback when WebSocket is not available
        // _startPeriodicRefresh(); // Disabled - refresh only when data comes from table
      }
    });

    // Also check WebSocket connection status periodically
    // If WebSocket disconnects, fallback to polling
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!wsService.isConnected && _refreshTimer == null) {
        print('🔄 WebSocket disconnected - enabling polling fallback');
        // _startPeriodicRefresh(); // Disabled - refresh only when data comes from table
      } else if (wsService.isConnected && _refreshTimer != null) {
        print('✅ WebSocket reconnected - disabling polling');
        _refreshTimer?.cancel();
        _refreshTimer = null;
      }
    });
  }

  /// Handle car update event from WebSocket
  void _handleCarUpdate(Map<String, dynamic> data) {
    try {
      final carData = data['car'] as Map<String, dynamic>?;
      if (carData == null) return;

      // Enable smart refresh for WebSocket updates
      _isSmartRefresh = true;

      // Map backend fields to Flutter model
      final mappedCar = _mapBackendToFlutterFields(carData);
      final updatedCar = Car.fromJson(mappedCar);

      // Update in the appropriate list
      if (isBuyer.value) {
        // Update in carList
        final index = carList.indexWhere((car) => car.id == updatedCar.id);
        if (index >= 0) {
          carList[index] = updatedCar;
          print('✅ Updated car in list: ${updatedCar.id}');
        }
      } else {
        // Update in sellerListings
        final index = sellerListings.indexWhere((listing) => listing.id == updatedCar.id);
        if (index >= 0) {
          sellerListings[index] = updatedCar;
          carList[index] = updatedCar; // Also update carList for compatibility
          print('✅ Updated listing: ${updatedCar.id}');
        }
      }

      _isSmartRefresh = false;
    } catch (e) {
      print('❌ Error handling car update: $e');
    }
  }

  /// Handle new car added event from WebSocket
  void _handleCarAdded(Map<String, dynamic> data) async {
    try {
      final carData = data['car'] as Map<String, dynamic>?;
      if (carData == null) return;

      // Map backend fields to Flutter model
      final mappedCar = _mapBackendToFlutterFields(carData);
      final newCar = Car.fromJson(mappedCar);

      // Add to the appropriate list
      if (isBuyer.value) {
        // For buyers: Only add if:
        // 1. Vehicle is active
        // 2. Auction hasn't ended (auction_end_time > now)
        // 3. Not the buyer's own listing (seller_id != current_user_id)

        // Check vehicle status
        if (newCar.status != 'active') {
          print('⏭️ Skipping car ${newCar.id} - status is ${newCar.status}');
          return;
        }

        // Check auction end time
        final now = DateTime.now();
        if (newCar.auctionEndTime.isBefore(now) || newCar.auctionEndTime.isAtSameMomentAs(now)) {
          print('⏭️ Skipping car ${newCar.id} - auction has ended');
          return;
        }

        // Check if it's the buyer's own listing
        final currentUserId = await PreferencesHelper.getUserId();
        if (currentUserId != null && newCar.sellerId == currentUserId) {
          print('⏭️ Skipping car ${newCar.id} - buyer\'s own listing');
          return;
        }

        // Check if car already exists in list (avoid duplicates)
        final existingIndex = carList.indexWhere((car) => car.id == newCar.id);
        if (existingIndex >= 0) {
          print('⏭️ Car ${newCar.id} already in list, updating instead');
          carList[existingIndex] = newCar;
          return;
        }

        // Add to carList (at beginning for new listings)
        carList.insert(0, newCar);
        print('✅ Added new car to buyer list: ${newCar.id} - ${newCar.make} ${newCar.model}');
      } else {
        // For sellers: Add to sellerListings if it's their own listing
        final currentUserId = await PreferencesHelper.getUserId();
        if (currentUserId != null && newCar.sellerId == currentUserId) {
          // Check if already exists
          final existingIndex = sellerListings.indexWhere((listing) => listing.id == newCar.id);
          if (existingIndex >= 0) {
            print('⏭️ Listing ${newCar.id} already exists, updating instead');
            sellerListings[existingIndex] = newCar;
            carList[existingIndex] = newCar;
            return;
          }

          sellerListings.insert(0, newCar);
          carList.insert(0, newCar); // Also add to carList for compatibility
          print('✅ Added new listing to seller list: ${newCar.id} - ${newCar.make} ${newCar.model}');
        } else {
          print('⏭️ Skipping car ${newCar.id} - not seller\'s own listing');
        }
      }
    } catch (e) {
      print('❌ Error handling car added: $e');
    }
  }

  /// Handle car removed event from WebSocket
  void _handleCarRemoved(Map<String, dynamic> data) {
    try {
      final carId = data['car_id']?.toString() ?? data['id']?.toString();
      if (carId == null) return;

      // Remove from the appropriate list
      if (isBuyer.value) {
        carList.removeWhere((car) => car.id == carId);
        print('✅ Removed car from list: $carId');
      } else {
        sellerListings.removeWhere((listing) => listing.id == carId);
        carList.removeWhere((car) => car.id == carId);
        print('✅ Removed listing: $carId');
      }
    } catch (e) {
      print('❌ Error handling car removed: $e');
    }
  }

  /// Handle bid update event from WebSocket
  void _handleBidUpdate(Map<String, dynamic> data) {
    try {
      final carId = data['car_id']?.toString() ?? data['vehicle_id']?.toString();
      final newBid = data['bid_amount']?.toDouble() ?? data['amount']?.toDouble();

      if (carId == null || newBid == null) return;

      // Update current bid in the car
      if (isBuyer.value) {
        final index = carList.indexWhere((car) => car.id == carId);
        if (index >= 0) {
          // Create updated car with new bid
          final oldCar = carList[index];
          final updatedCar = Car(
            id: oldCar.id,
            make: oldCar.make,
            model: oldCar.model,
            year: oldCar.year,
            imageUrl: oldCar.imageUrl,
            startingBid: oldCar.startingBid,
            buyNowPrice: oldCar.buyNowPrice,
            mileage: oldCar.mileage,
            location: oldCar.location,
            distance: oldCar.distance,
            auctionEndTime: oldCar.auctionEndTime,
            status: oldCar.status,
            vin: oldCar.vin,
            currentBid: newBid, // Update current bid
            wonAmount: oldCar.wonAmount,
            transportStatus: oldCar.transportStatus,
            expectedDeliveryDate: oldCar.expectedDeliveryDate,
            invoiceNumber: oldCar.invoiceNumber,
            titleStatus: oldCar.titleStatus,
            inspectionStatus: oldCar.inspectionStatus,
            swapOfferStatus: oldCar.swapOfferStatus,
            description: oldCar.description,
            lastMatch: oldCar.lastMatch,
            currentMatches: oldCar.currentMatches,
            alerts: oldCar.alerts,
            price: oldCar.price,
            purchaseMethod: oldCar.purchaseMethod,
            purchaseAmount: oldCar.purchaseAmount,
            sellerId: oldCar.sellerId,
            sellerName: oldCar.sellerName,
            contactPhone: oldCar.contactPhone,
            contactEmail: oldCar.contactEmail,
            photos: oldCar.photos,
          );
          carList[index] = updatedCar;
          print('✅ Updated bid for car: $carId, new bid: $newBid');
        }
      }
    } catch (e) {
      print('❌ Error handling bid update: $e');
    }
  }

  /// Helper to map backend fields to Flutter model (same as in CarService)
  Map<String, dynamic> _mapBackendToFlutterFields(Map<String, dynamic> item) {
    return {
      'id': item['id']?.toString() ?? '',
      'make': item['make'] ?? 'Unknown',
      'model': item['model'] ?? 'Unknown',
      'year': item['year'] ?? 0,
      'imageUrl': item['image_url'] ?? item['imageUrl'] ?? 'assets/images/car1.png',
      'startingBid': (item['starting_bid'] ?? item['startingBid'] ?? 0).toDouble(),
      'buyNowPrice': (item['buy_now_price'] ?? item['buyNowPrice'] ?? 0).toDouble(),
      'mileage': item['mileage'] ?? 0,
      'location': item['location'] ?? '',
      'distance': item['distance'] ?? '',
      'auctionEndTime': item['auction_end_time'] ?? item['auctionEndTime'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'status': item['status'] ?? 'draft',
      'vin': item['vin'],
      'currentBid': item['current_bid']?.toDouble() ?? item['currentBid']?.toDouble(),
      'description': item['description'],
      'sellerId': item['seller_id']?.toString() ?? item['sellerId']?.toString(),
      'sellerName': item['seller_name'] ?? item['sellerName'],
      'contactPhone': item['contact_phone'] ?? item['contactPhone'],
      'contactEmail': item['contact_email'] ?? item['contactEmail'],
      'photos': item['photos'],
    };
  }

  void _startPeriodicRefresh() {
    // DISABLED: Refresh only when data comes from database/WebSocket, not periodic polling
    // Cancel any existing timer
    _refreshTimer?.cancel();
    print('✅ Periodic refresh disabled - refresh only when data comes from database/WebSocket');
  }

  // Save current scroll position
  void _saveScrollPosition() {
    // Check if controller has exactly one position (not attached to multiple scroll views)
    if (scrollController.hasClients && scrollController.positions.length == 1) {
      try {
        _savedScrollPosition = scrollController.offset;
      } catch (e) {
        print('⚠️ Error saving scroll position: $e');
      }
    }
  }

  // Restore scroll position after refresh
  void _restoreScrollPosition() {
    if (_savedScrollPosition != null && _savedScrollPosition! > 0) {
      // Wait for UI to rebuild before restoring scroll position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check if controller has exactly one position (not attached to multiple scroll views)
        if (scrollController.hasClients && scrollController.positions.length == 1) {
          try {
            // Only restore if user hasn't manually scrolled
            final currentOffset = scrollController.offset;
            if (currentOffset < 50) { // If near top, restore saved position
              scrollController.jumpTo(_savedScrollPosition!);
            }
          } catch (e) {
            print('⚠️ Error restoring scroll position: $e');
          }
        }
      });
    }
  }

  /// Smart update: Only update changed items, add new ones, remove deleted ones
  /// This prevents full list rebuild and preserves scroll position
  void _smartUpdateCarList(List<Car> newCars) {
    if (newCars.isEmpty && carList.isEmpty) return;

    final oldCarsMap = <String, Car>{};
    for (var car in carList) {
      oldCarsMap[car.id] = car;
    }

    final newCarsMap = <String, Car>{};
    for (var car in newCars) {
      newCarsMap[car.id] = car;
    }

    int addedCount = 0;
    int updatedCount = 0;
    int removedCount = 0;
    int unchangedCount = 0;

    // Find new cars to add
    final carsToAdd = <Car>[];
    for (var newCar in newCars) {
      if (!oldCarsMap.containsKey(newCar.id)) {
        // Additional check: Only add if car meets buyer criteria
        if (isBuyer.value) {
          // Check vehicle status
          if (newCar.status != 'active') {
            print('⏭️ Smart Update: Skipping car ${newCar.id} - status is ${newCar.status}');
            continue;
          }

          // Check auction end time
          final now = DateTime.now();
          if (newCar.auctionEndTime.isBefore(now) || newCar.auctionEndTime.isAtSameMomentAs(now)) {
            print('⏭️ Smart Update: Skipping car ${newCar.id} - auction has ended');
            continue;
          }
        }

        carsToAdd.add(newCar);
        addedCount++;
        print('✅ Smart Update: New car found: ${newCar.id} - ${newCar.make} ${newCar.model}');
      }
    }

    // Find cars to update (only if values changed)
    final carsToUpdate = <Car>[];
    for (var newCar in newCars) {
      final oldCar = oldCarsMap[newCar.id];
      if (oldCar != null) {
        // Check if any important values changed
        if (_hasCarChanged(oldCar, newCar)) {
          carsToUpdate.add(newCar);
          updatedCount++;
        } else {
          unchangedCount++;
        }
      }
    }

    // Find cars to remove (no longer in new list)
    final carsToRemove = <String>[];
    for (var oldCar in carList) {
      if (!newCarsMap.containsKey(oldCar.id)) {
        carsToRemove.add(oldCar.id);
        removedCount++;
      }
    }

    // Apply changes incrementally (only if there are actual changes)
    if (addedCount > 0 || updatedCount > 0 || removedCount > 0) {
      print('🔄 Smart Update: +$addedCount new, ~$updatedCount updated, -$removedCount removed, =$unchangedCount unchanged');

      // Remove deleted cars
      if (removedCount > 0) {
        carList.removeWhere((car) => carsToRemove.contains(car.id));
      }

      // Update changed cars (replace in place to preserve position)
      if (updatedCount > 0) {
        for (var updatedCar in carsToUpdate) {
          final index = carList.indexWhere((car) => car.id == updatedCar.id);
          if (index >= 0) {
            carList[index] = updatedCar;
          }
        }
      }

      // Add new cars at the beginning (newest first - shows latest listings at top)
      if (addedCount > 0) {
        // Insert new cars at the beginning to show latest listings first
        for (var newCar in carsToAdd.reversed) {
          carList.insert(0, newCar);
        }
        print('✅ Added $addedCount new cars to the beginning of the list');
      }
    } else {
      print('✅ Smart Update: No changes detected, list unchanged');
    }
  }

  /// Smart update for seller listings
  void _smartUpdateSellerListings(List<Car> newListings) {
    if (newListings.isEmpty && sellerListings.isEmpty) return;

    final oldListingsMap = <String, Car>{};
    for (var listing in sellerListings) {
      oldListingsMap[listing.id] = listing;
    }

    final newListingsMap = <String, Car>{};
    for (var listing in newListings) {
      newListingsMap[listing.id] = listing;
    }

    int addedCount = 0;
    int updatedCount = 0;
    int removedCount = 0;
    int unchangedCount = 0;

    // Find new listings to add
    final listingsToAdd = <Car>[];
    for (var newListing in newListings) {
      if (!oldListingsMap.containsKey(newListing.id)) {
        listingsToAdd.add(newListing);
        addedCount++;
      }
    }

    // Find listings to update (only if values changed)
    final listingsToUpdate = <Car>[];
    for (var newListing in newListings) {
      final oldListing = oldListingsMap[newListing.id];
      if (oldListing != null) {
        // Check if any important values changed
        if (_hasCarChanged(oldListing, newListing)) {
          listingsToUpdate.add(newListing);
          updatedCount++;
        } else {
          unchangedCount++;
        }
      }
    }

    // Find listings to remove
    final listingsToRemove = <String>[];
    for (var oldListing in sellerListings) {
      if (!newListingsMap.containsKey(oldListing.id)) {
        listingsToRemove.add(oldListing.id);
        removedCount++;
      }
    }

    // Apply changes incrementally
    if (addedCount > 0 || updatedCount > 0 || removedCount > 0) {
      print('🔄 Smart Update (Seller): +$addedCount new, ~$updatedCount updated, -$removedCount removed, =$unchangedCount unchanged');

      // Remove deleted listings
      if (removedCount > 0) {
        sellerListings.removeWhere((listing) => listingsToRemove.contains(listing.id));
      }

      // Update changed listings
      if (updatedCount > 0) {
        for (var updatedListing in listingsToUpdate) {
          final index = sellerListings.indexWhere((listing) => listing.id == updatedListing.id);
          if (index >= 0) {
            sellerListings[index] = updatedListing;
          }
        }
      }

      // Add new listings
      if (addedCount > 0) {
        sellerListings.addAll(listingsToAdd);
  }
    } else {
      print('✅ Smart Update (Seller): No changes detected, list unchanged');
    }
  }

  /// Check if car has any important changes that need UI update
  bool _hasCarChanged(Car oldCar, Car newCar) {
    // Compare important fields that affect UI
    return oldCar.currentBid != newCar.currentBid ||
           oldCar.status != newCar.status ||
           oldCar.auctionEndTime != newCar.auctionEndTime ||
           oldCar.buyNowPrice != newCar.buyNowPrice ||
           oldCar.startingBid != newCar.startingBid ||
           oldCar.transportStatus != newCar.transportStatus ||
           oldCar.inspectionStatus != newCar.inspectionStatus ||
           oldCar.swapOfferStatus != newCar.swapOfferStatus ||
           oldCar.imageUrl != newCar.imageUrl ||
           oldCar.description != newCar.description;
  }

  // Store WebSocket callbacks for cleanup
  Function(Map<String, dynamic>)? _carUpdateCallback;
  Function(Map<String, dynamic>)? _carAddedCallback;
  Function(Map<String, dynamic>)? _carRemovedCallback;
  Function(Map<String, dynamic>)? _bidUpdateCallback;

  @override
  void onClose() {
    _refreshTimer?.cancel();

    // Unsubscribe from WebSocket events
    final wsService = WebSocketService.instance;
    if (_carUpdateCallback != null) {
      wsService.unsubscribe('car_updated', _carUpdateCallback!);
    }
    if (_carAddedCallback != null) {
      wsService.unsubscribe('car_added', _carAddedCallback!);
    }
    if (_carRemovedCallback != null) {
      wsService.unsubscribe('car_removed', _carRemovedCallback!);
    }
    if (_bidUpdateCallback != null) {
      wsService.unsubscribe('bid_placed', _bidUpdateCallback!);
    }

    // Force remove listener if it exists (prevent multiple scroll views error)
    // Even though we don't add it in onInit(), it might exist from previous instances
    try {
      // Remove listener multiple times to ensure it's removed (safe to call multiple times)
      scrollController.removeListener(_updateScrollOffset);
      scrollController.removeListener(_updateScrollOffset);
      scrollController.removeListener(_updateScrollOffset);
    } catch (e) {
      // Listener might not have been added, that's okay
    }
    // Dispose controller to clean up all listeners
    scrollController.dispose();
    animationController?.dispose(); // Dispose animation controller if initialized
    animationController = null;
    scaleAnimation = null;
    super.onClose();
  }

  // Manual refresh method for pull-to-refresh
  Future<void> refreshCars() async {
    // Save scroll position before refresh
    _saveScrollPosition();
    await fetchCars();
    // Restore scroll position after refresh
    _restoreScrollPosition();
  }


  Future<void> fetchWonVehicles({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // Check if we need to refresh
      final now = DateTime.now();
      if (_lastWonFetch != null &&
          now.difference(_lastWonFetch!).inSeconds < 30) {
        return;
      }
    }

    try {
      isLoadingWonVehicles.value = true;
      // ... fetch logic ...
      _lastWonFetch = DateTime.now();
    } finally {
      isLoadingWonVehicles.value = false;
    }
  }

  Future<void> fetchPurchaseHistory({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final now = DateTime.now();
      if (_lastPurchaseFetch != null &&
          now.difference(_lastPurchaseFetch!).inSeconds < 30) {
        return;
      }
    }

    try {
      isLoadingPurchaseHistory.value = true;

      _lastPurchaseFetch = DateTime.now();
    } finally {
      isLoadingPurchaseHistory.value = false;
    }
  }

  DateTime? _lastWonFetch;
  DateTime? _lastPurchaseFetch;


  void _updateScrollOffset() {
    // This method should NOT be used as a listener anymore
    // NotificationListener in home_page.dart handles scroll offset updates
    // This method is kept for backward compatibility but should never be called
    // If it's called, it means a listener is still attached somewhere - skip silently
    return;

    // OLD CODE (disabled - NotificationListener handles this now):
    // Check if scroll controller has exactly one position (not attached to multiple scroll views)
    // if (!scrollController.hasClients || scrollController.positions.length != 1) {
    //   // If attached to multiple scroll views or no clients, skip update
    //   return;
    // }
    //
    // try {
    //   scrollOffset.value = scrollController.offset;
    //   // Save scroll position (non-blocking, don't break if it fails)
    //   PreferencesHelper.saveScrollPosition('home_page', scrollController.offset).catchError((e) {
    //     // Silently fail - don't break scroll functionality
    //   });
    // } catch (e) {
    //   // If error accessing offset (e.g., multiple positions), skip update
    //   print('⚠️ Error updating scroll offset: $e');
    // }
  }

  void updateCarouselIndex(int index) {
    currentCarouselIndex.value = index;
  }

  void updateSelectedTab(int index) {
    selectedTab.value = index; // Corrected: Assign to .value

    // Load specific data based on tab
    if (index == 1) {
      // Won Vehicles tab - load immediately
      fetchWonVehicles();
    } else if (index == 2) {
      // Purchase History tab - load immediately
      fetchPurchaseHistory();
    } else if (index == 0) {
      // Upcoming Auctions tab - don't auto-refresh, user will use pull-to-refresh
    } else {
      // Other tabs - fetch cars
      fetchCars();
    }

    // Trigger scroll to top when tab changes
    _scrollToTop();
  }

 /* /// Fetch won vehicles specifically (called when Won Vehicles tab is selected)
  Future<void> fetchWonVehicles() async {
    if (isLoadingWonVehicles.value) {
      print('⏭️ Won vehicles already loading, skipping duplicate call');
      return;
    }

    isLoadingWonVehicles.value = true;
    print('🔄 Loading won vehicles...');

    try {
      final won = await _carService.getWonVehicles().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⏱️ Timeout loading won vehicles - returning empty list');
          return <Car>[];
        },
      );

      print('✅ Successfully loaded ${won.length} won vehicles');
      wonVehicles.assignAll(won);
    } catch (e) {
      print('❌ Error fetching won vehicles: $e');
      wonVehicles.clear();
    } finally {
      isLoadingWonVehicles.value = false;
    }
  }*/

/*  /// Fetch purchase history specifically (called when Purchase History tab is selected)
  Future<void> fetchPurchaseHistory() async {
    if (isLoadingPurchaseHistory.value) {
      print('⏭️ Purchase history already loading, skipping duplicate call');
      return;
    }

    isLoadingPurchaseHistory.value = true;
    print('🔄 Loading purchase history...');

    try {
      final purchased = await _carService.getPurchaseHistory().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⏱️ Timeout loading purchase history - returning empty list');
          return <Car>[];
        },
      );

      print('✅ Successfully loaded ${purchased.length} purchase history items');
      purchaseHistory.assignAll(purchased);
    } catch (e) {
      print('❌ Error fetching purchase history: $e');
      purchaseHistory.clear();
    } finally {
      isLoadingPurchaseHistory.value = false;
    }
  }*/

  void _scrollToTop() {
    // Scroll to top smoothly
    // Check if controller has exactly one position (not attached to multiple scroll views)
    if (scrollController.hasClients && scrollController.positions.length == 1) {
      try {
        scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        print('⚠️ Error scrolling to top: $e');
      }
    }
  }

  Future<void> _restoreBuyerSellerModeFromPrefs() async {
    try {
      final role = (await PreferencesHelper.getUserRole())?.toLowerCase().trim();
      if (role != 'seller/buyer') return;
      final mode = (await PreferencesHelper.getBuyerSellerMode())?.toLowerCase().trim();
      if (mode == 'seller') {
        isBuyer.value = false;
      } else if (mode == 'buyer') {
        isBuyer.value = true;
      }
    } catch (e) {
      print('⚠️ HomePageController._restoreBuyerSellerModeFromPrefs: $e');
    }
  }

  /// Persists buyer/seller mode first, then refreshes notifications (API `role` param), bids, and listings.
  Future<void> toggleBuyerSeller(bool value) async {
    isBuyer.value = value;
    await PreferencesHelper.saveBuyerSellerMode(value ? 'buyer' : 'seller');
    if (Get.isRegistered<NotificationController>()) {
      await Get.find<NotificationController>().onBuyerSellerModeChanged();
    }
    try {
      if (Get.isRegistered<BidController>()) {
        await Get.find<BidController>().fetchMyBids();
      }
    } catch (_) {}
    // Reset tabs when switching
    if (value) {
      selectedTab.value = 0; // Reset buyer tabs
    } else {
      selectedSellerTab.value = 0; // Reset seller tabs
      selectedSellerSubTab.value = 0; // Reset seller sub-tabs
    }
    await fetchCars();
  }

  void updateSelectedSellerTab(int index) {
    selectedSellerTab.value = index;
    // Listing (1): default to Live/Active only. Inventory (3): its own Active sub-tab is 0.
    if (index == 1) {
      selectedSellerSubTab.value = 3; // My Listings → Active (live) listings
    } else if (index == 3) {
      selectedSellerSubTab.value = 0; // Inventory → Active
    } else {
      selectedSellerSubTab.value = 0;
    }
    fetchCars(); // This will also fetch seller dashboard data
    if (!isBuyer.value) {
      // If seller, also refresh dashboard data
      fetchSellerDashboardData();
    }
    // Refresh dashboard data when switching to Home tab
    if (index == 0 && isBuyer.value) {
      fetchBuyerDashboardData();
    }
    if (index == 0 && !isBuyer.value) {
      fetchSellerDashboardData();
    }
    // Trigger scroll to top when tab changes
    _scrollToTop();
  }

  void updateSelectedSellerSubTab(int index) {
    selectedSellerSubTab.value = index;
    fetchCars();
    // Trigger scroll to top when sub-tab changes
    _scrollToTop();
  }

  /// Add or update saved search
  Future<void> addSavedSearch(SavedSearch search) async {
    try {
      // Save to storage (SharedPreferences + backend)
      await _savedSearchService.saveSearch(search);

      // Update local list
      final existingIndex = savedSearches.indexWhere((s) => s.id == search.id);
      if (existingIndex >= 0) {
        savedSearches[existingIndex] = search;
        print('✅ Updated saved search: ${search.searchName}');
      } else {
        savedSearches.add(search);
        print('✅ Added new saved search: ${search.searchName}');
      }
    } catch (e) {
      print('❌ Error saving search: $e');
      // Still update UI even if save fails
      final existingIndex = savedSearches.indexWhere((s) => s.id == search.id);
      if (existingIndex >= 0) {
        savedSearches[existingIndex] = search;
      } else {
        savedSearches.add(search);
      }
    }
  }

  /// Delete saved search
  Future<void> deleteSavedSearch(String id) async {
    try {
      // Delete from storage
      await _savedSearchService.deleteSearch(id);
      // Remove from local list
      savedSearches.removeWhere((s) => s.id == id);
      print('✅ Deleted saved search: $id');
    } catch (e) {
      print('❌ Error deleting search: $e');
      // Still remove from UI
      savedSearches.removeWhere((s) => s.id == id);
    }
  }

  Future<void> fetchCars({Map<String, dynamic>? filters, String? sortBy}) async {
    try {
      isLoading.value = true;
      print('🔄 fetchCars called - isBuyer: ${isBuyer.value}');

      // Update current filters/sort if provided
      // If filters is explicitly null, clear current filters
      if (filters == null) {
        currentFilters = null;
        // Clear saved filters
        try {
          await PreferencesHelper.saveFilterSettings({});
        } catch (e) {
          print('⚠️ Error clearing filter settings: $e');
        }
        print('🧹 Filters cleared - resetting to default');
      } else if (filters.isNotEmpty) {
        // Only update if filters are not empty
        currentFilters = filters;
        // Save filters only if explicitly provided (don't auto-load on every call)
        try {
          await PreferencesHelper.saveFilterSettings(filters);
        } catch (e) {
          print('⚠️ Error saving filter settings: $e');
        }
      } else {
        // Empty filters map - clear filters
        currentFilters = null;
        try {
          await PreferencesHelper.saveFilterSettings({});
        } catch (e) {
          print('⚠️ Error clearing filter settings: $e');
        }
        print('🧹 Filters cleared (empty map) - resetting to default');
      }

      if (sortBy != null) {
        currentSortBy = sortBy;
        // Save sort only if explicitly provided
        try {
          await PreferencesHelper.saveLastSortBy(sortBy);
        } catch (e) {
          print('⚠️ Error saving sort preference: $e');
        }
      }

      if (isBuyer.value) {
        final Map<String, dynamic> appliedFilters = {};
        if (currentFilters != null) {
          appliedFilters.addAll(currentFilters!);
        }
        final scope = selectedTab.value == 0 ? 'upcoming' : 'active';
        appliedFilters['auction_scope'] = scope;
        print('👤 ========================================');
        print('👤 FETCHING CARS FOR BUYER');
        print('👤 ========================================');
        print('👤 Fetching cars for buyer...');
        print('   🔍 Filters: $appliedFilters');
        print('   📊 Sort: $currentSortBy');
        try {
          final cars = await _carService.fetchCars(
            filters: appliedFilters,
            sortBy: currentSortBy,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⏱️ Timeout fetching cars - returning empty list');
              return <Car>[];
            },
          );
          print('✅ Fetched ${cars.length} cars for buyer');
          print('   📊 Car statuses breakdown:');
          final statusCounts = <String, int>{};
          for (var car in cars) {
            statusCounts[car.status] = (statusCounts[car.status] ?? 0) + 1;
            print('      - ID: ${car.id}, Status: ${car.status}, Make: ${car.make}, Model: ${car.model}, Seller ID: ${car.sellerId}');
          }
          print('   📈 Status Summary:');
          statusCounts.forEach((status, count) {
            print('      - $status: $count');
          });

          // Use smart update for periodic refresh, full update for manual refresh
          if (_isSmartRefresh && carList.isNotEmpty) {
            _smartUpdateCarList(cars);
          } else {
            // Full update - but preserve scroll position
            _saveScrollPosition();
          carList.assignAll(cars);
            // Restore scroll position after a short delay
            Future.delayed(const Duration(milliseconds: 100), () {
              _restoreScrollPosition();
            });
          }
          print('👤 ========================================');

          // Fetch buyer dashboard data (non-blocking)
          fetchBuyerDashboardData().catchError((e) {
            print('⚠️ Error fetching buyer dashboard: $e');
          });
        } catch (e) {
          print('❌ Error fetching cars: $e');
          carList.clear();
        }

        // Fetch won vehicles and purchase history (non-blocking, only if not already loading)
        if (!isLoadingWonVehicles.value) {
          _carService.getWonVehicles().timeout(
            const Duration(seconds: 15),
            onTimeout: () => <Car>[],
          ).then((won) {
            if (!isLoadingWonVehicles.value) {
              wonVehicles.assignAll(won);
            }
          }).catchError((e) {
            print('⚠️ Error fetching won vehicles (background): $e');
          });
        }

        if (!isLoadingPurchaseHistory.value) {
          _carService.getPurchaseHistory().timeout(
            const Duration(seconds: 15),
            onTimeout: () => <Car>[],
          ).then((purchased) {
            if (!isLoadingPurchaseHistory.value) {
              purchaseHistory.assignAll(purchased);
            }
          }).catchError((e) {
            print('⚠️ Error fetching purchase history (background): $e');
          });
        }
      } else {
        // Seller: fetch own listings
        print('🏪 ========================================');
        print('🏪 FETCHING SELLER LISTINGS');
        print('🏪 ========================================');
        try {
          final listings = await _carService.getMyListings().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⏱️ Timeout fetching seller listings - returning empty list');
              return <Car>[];
            },
          );
          print('✅ Fetched ${listings.length} listings for seller');
          print('   📊 Listing statuses breakdown:');
          final statusCounts = <String, int>{};
          for (var listing in listings) {
            statusCounts[listing.status] = (statusCounts[listing.status] ?? 0) + 1;
            print('      - ID: ${listing.id}, Status: ${listing.status}, Make: ${listing.make}, Model: ${listing.model}');
          }
          print('   📈 Status Summary:');
          statusCounts.forEach((status, count) {
            print('      - $status: $count');
          });
          // Use smart update for periodic refresh, full update for manual refresh
          if (_isSmartRefresh && sellerListings.isNotEmpty) {
            _smartUpdateSellerListings(listings);
            // Also update carList for compatibility
            _smartUpdateCarList(listings);
          } else {
          sellerListings.assignAll(listings);
          // Also update carList for compatibility
          carList.assignAll(listings);
          }
          print('   ✅ Updated sellerListings: ${sellerListings.length} items');
          print('   ✅ Updated carList: ${carList.length} items');
          print('🏪 ========================================');

          // Fetch seller dashboard data (non-blocking)
          fetchSellerDashboardData().catchError((e) {
            print('⚠️ Error fetching seller dashboard: $e');
          });
        } catch (e) {
          print('❌ Error fetching seller listings: $e');
          sellerListings.clear();
          carList.clear();
        }
      }
    } catch (e) {
      print('❌ Error fetching cars: $e');
      // Set empty lists to prevent UI errors
      if (isBuyer.value) {
        carList.clear();
      } else {
        sellerListings.clear();
        carList.clear();
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Make this method public so it can be called from screens
  Future<void> fetchBuyerDashboardData() async {
    try {
      print('👤 Fetching buyer dashboard data...');
      final dashboard = await _carService.getBuyerDashboard().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <String, dynamic>{},
      );
      buyerDashboard.value = dashboard;
      print('✅ Buyer dashboard data fetched successfully');
      print('   📊 Active Auctions: ${dashboard['active_auctions']?['active_count'] ?? 0}');
      print('   📊 Total Bids: ${dashboard['bid_stats']?['total_bids'] ?? 0}');
      print('   📊 Won Bids: ${dashboard['bid_stats']?['won_bids'] ?? 0}');
      print('   📊 Recent Bids: ${(dashboard['recent_bids'] as List?)?.length ?? 0}');
      print('   📊 Purchased Vehicles: ${(dashboard['purchased_vehicles'] as List?)?.length ?? 0}');
      print('   📊 Transport Orders: ${(dashboard['transport_orders'] as List?)?.length ?? 0}');
      print('   📊 Inspection Requests: ${(dashboard['inspection_requests'] as List?)?.length ?? 0}');
    } catch (e) {
      print('❌ Error fetching buyer dashboard: $e');
      buyerDashboard.value = null;
    }
  }

  // Make this method public so it can be called from screens
  Future<void> fetchSellerDashboardData() async {
    try {
      // Fetch seller statistics with timeout
      final stats = await _carService.getSellerStats().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <String, dynamic>{},
      );
      sellerStats.value = stats;

      // Fetch pending offers with timeout (non-blocking)
      _carService.getPendingOffers().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <dynamic>[],
      ).then((offers) {
        pendingOffers.assignAll(offers);
      }).catchError((e) {
        print('⚠️ Error fetching pending offers: $e');
      });

      // Fetch live auctions with timeout (non-blocking)
      _carService.getLiveAuctions().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <dynamic>[],
      ).then((live) {
        liveAuctions.assignAll(live);
      }).catchError((e) {
        print('⚠️ Error fetching live auctions: $e');
      });

      // Fetch ended auctions with timeout (non-blocking)
      _carService.getEndedAuctions().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <dynamic>[],
      ).then((ended) {
        endedAuctions.assignAll(ended);
      }).catchError((e) {
        print('⚠️ Error fetching ended auctions: $e');
      });

      // Fetch pending transport with timeout (non-blocking)
      _carService.getPendingTransport().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <Car>[],
      ).then((pending) {
        pendingTransport.assignAll(pending);
      }).catchError((e) {
        print('⚠️ Error fetching pending transport: $e');
      });

      // Fetch scheduled transport with timeout (non-blocking)
      _carService.getScheduledTransport().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <Car>[],
      ).then((scheduled) {
        scheduledTransport.assignAll(scheduled);
      }).catchError((e) {
        print('⚠️ Error fetching scheduled transport: $e');
      });

      // Fetch seller's vehicles with auction data (non-blocking)
      _carService.getSellerVehicles().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <dynamic>[],
      ).then((vehicles) {
        sellerVehicles.assignAll(vehicles);
        print('✅ Seller vehicles fetched: ${vehicles.length}');
      }).catchError((e) {
        print('⚠️ Error fetching seller vehicles: $e');
      });
    } catch (e) {
      print('❌ Error fetching seller dashboard data: $e');
    }
  }
}
