import 'dart:async';
import 'package:get/get.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/services/swap_offer_service.dart';
import 'package:carauction/controllers/app_state_controller.dart';

class BidController extends GetxController {
  final BidService _bidService = BidService();
  final SwapOfferService _swapOfferService = SwapOfferService();

  final RxList<dynamic> myBids = <dynamic>[].obs;
  final RxList<dynamic> activeBids = <dynamic>[].obs;
  final RxList<dynamic> wonBids = <dynamic>[].obs;
  final RxList<dynamic> lostBids = <dynamic>[].obs;
  final RxList<dynamic> bidHistory = <dynamic>[].obs;
  final RxList<dynamic> swapOffers = <dynamic>[].obs;
  final Rx<Map<String, dynamic>?> bidAnalytics = Rx<Map<String, dynamic>?>(null);
  final RxBool isLoading = false.obs;
  final RxInt selectedTab = 0.obs; // 0: All Bids, 1: Active Bids, 2: Won Auctions, 3: Lost Auctions
  Timer? _refreshTimer;

  /// Only for [fetchMyBids] — [isLoading] is also used by [fetchBidAnalytics].
  bool _myBidsFetchBusy = false;

  @override
  void onInit() {
    super.onInit();
    fetchMyBids(); // Fetch all bids initially
    fetchSwapOffers();
    fetchBidAnalytics();
    // Disabled periodic refresh - refresh only when data comes from database
    // _startPeriodicRefresh();
  }

  String? _lastDataHash; // Store hash of last data to detect changes
  
  void _startPeriodicRefresh() {
    // DISABLED: Refresh only when data comes from database, not periodic polling
    _refreshTimer?.cancel();
    print('✅ Periodic refresh disabled - refresh only when data comes from database');
  }
  
  String _calculateDataHash() {
    // Create a hash from bid IDs and statuses to detect changes
    final bidIds = myBids.map((bid) => '${bid['id']}_${bid['status']}').join(',');
    return bidIds.hashCode.toString();
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  /// Call on logout so the next user never sees the previous account's bids.
  void clearSession() {
    myBids.clear();
    activeBids.clear();
    wonBids.clear();
    lostBids.clear();
    bidHistory.clear();
    swapOffers.clear();
    bidAnalytics.value = null;
    selectedTab.value = 0;
    _myBidsFetchBusy = false;
  }

  /// Fetches all bids (no filter) and splits into active/won/lost client-side.
  Future<void> fetchMyBids({String? filter}) async {
    try {
      // Always request ALL bids so we can split into Active/Won/Lost. Ignore filter for API.
      if (_myBidsFetchBusy) {
        print('⏭️ Skipping fetch - my bids request already in progress');
        return;
      }
      _myBidsFetchBusy = true;
      isLoading.value = true;
      final rawBids = await _bidService.getMyBids(filter: null);

      // De-duplicate bids by ID so updated bids replace older ones instead of showing duplicates
      final Map<String, dynamic> uniqueBids = {};
      for (final bid in rawBids) {
        final id = bid['id']?.toString();
        if (id == null) continue;
        uniqueBids[id] = bid;
      }
      final bids = uniqueBids.values.toList();

      print('📦 Fetched ${rawBids.length} total bids from backend, ${bids.length} unique after de-dup');
      
      // Debug: Print all bids
      for (var bid in bids) {
        print('📋 Bid ID: ${bid['id']}, Amount: ${bid['bid_amount']}, isBuyNow: ${bid['is_buy_now']}, vehicle: ${bid['vehicle'] != null ? bid['vehicle']['id'] : 'null'}');
      }
      
      myBids.assignAll(bids);
      final now = DateTime.now();

      // Build won and lost first, then active = all other bids (so every bid appears in one tab)
      final wonBidsList = <dynamic>[];
      final lostBidsList = <dynamic>[];
      final wonIds = <String>{};
      final lostIds = <String>{};

      for (var bid in bids) {
        final vehicle = bid['vehicle'] as Map<String, dynamic>?;
        final bidId = bid['id']?.toString() ?? '';
        final bidStatus = (bid['bid_status'] as String?)?.toLowerCase();
        final bidStatusText = (bid['bid_status_text'] as String?)?.toLowerCase();
        final vehicleStatus = vehicle != null ? (vehicle['status'] as String?)?.toLowerCase() : null;
        final auctionEndTimeStr = vehicle?['auction_end_time'] as String? ?? (bid['auction'] as Map<String, dynamic>?)?['end_time'] as String?;
        final isWinning = bid['is_winning_bid'] as bool? ?? false;
        final isBuyNow = bid['is_buy_now'] as bool? ?? false;
        final auction = bid['auction'] as Map<String, dynamic>?;
        final winnerId = auction?['winner_id'];
        final userId = bid['user_id'] ?? bid['buyer_id'];
        final winnerMatch = winnerId != null && userId != null && winnerId.toString() == userId.toString();

        // Won: bid_status or bid_status_text says won, OR buy now accepted, OR vehicle sold/won and user winning
        if (bidStatus == 'won' || bidStatusText == 'won') {
          wonBidsList.add(bid);
          if (bidId.isNotEmpty) wonIds.add(bidId);
          continue;
        }
        if (isBuyNow && isWinning) {
          wonBidsList.add(bid);
          if (bidId.isNotEmpty) wonIds.add(bidId);
          continue;
        }
        if (vehicleStatus == 'sold' || vehicleStatus == 'won') {
          if (isWinning || winnerMatch) {
            wonBidsList.add(bid);
            if (bidId.isNotEmpty) wonIds.add(bidId);
            continue;
          }
        }

        // Lost: backend says lost
        if (bidStatus == 'lost' || bidStatusText == 'lost') {
          lostBidsList.add(bid);
          if (bidId.isNotEmpty) lostIds.add(bidId);
          continue;
        }

        // Fallback: auction ended (by time or status) -> won or lost
        bool auctionEnded = false;
        if (auctionEndTimeStr != null && auctionEndTimeStr.toString().trim().isNotEmpty) {
          try {
            auctionEnded = DateTime.parse(auctionEndTimeStr.toString()).isBefore(now);
          } catch (_) {
            auctionEnded = vehicleStatus == 'sold' || vehicleStatus == 'won' || vehicleStatus == 'ended';
          }
        } else {
          auctionEnded = vehicleStatus == 'sold' || vehicleStatus == 'won' || vehicleStatus == 'ended';
        }
        if (auctionEnded) {
          if (isWinning || winnerMatch) {
            wonBidsList.add(bid);
            if (bidId.isNotEmpty) wonIds.add(bidId);
          } else {
            lostBidsList.add(bid);
            if (bidId.isNotEmpty) lostIds.add(bidId);
          }
        }
      }

      // Active = all bids that are NOT won and NOT lost (so Active + Won + Lost cover all bids)
      final activeBidsListFinal = bids.where((bid) {
        final id = bid['id']?.toString() ?? '';
        return !wonIds.contains(id) && !lostIds.contains(id);
      }).toList();

      print('✅ Active bids: ${activeBidsListFinal.length}, 🏆 Won: ${wonBidsList.length}, ❌ Lost: ${lostBidsList.length}');
      activeBids.assignAll(activeBidsListFinal);
      wonBids.assignAll(wonBidsList);
      lostBids.assignAll(lostBidsList);
      
      // History = All bids that are NOT in active list (for backward compatibility)
      final activeBidIds = activeBidsListFinal.map((bid) => bid['id'].toString()).toSet();
      final historyBidsList = bids.where((bid) {
        return !activeBidIds.contains(bid['id'].toString());
      }).toList();
      
      print('📜 History bids: ${historyBidsList.length}');
      bidHistory.assignAll(historyBidsList);
    } catch (e) {
      print('❌ Error fetching my bids: $e');
    } finally {
      isLoading.value = false;
      _myBidsFetchBusy = false;
    }
  }

  Future<void> fetchSwapOffers() async {
    try {
      final offers = await _swapOfferService.getMySwapOffers();
      print('🔄 Fetched ${offers.length} swap offers');
      swapOffers.assignAll(offers);
    } catch (e) {
      print('❌ Error fetching swap offers: $e');
    }
  }

  /// Cancel own swap offer (buyer). Refreshes swap list after cancel.
  Future<bool> cancelSwapOffer(String bidId) async {
    try {
      await _swapOfferService.cancelOffer(bidId);
      await fetchSwapOffers();
      return true;
    } catch (e) {
      print('❌ Error cancelling swap offer: $e');
      return false;
    }
  }

  Future<void> fetchBidAnalytics() async {
    try {
      final analytics = await _bidService.getBuyerBidAnalytics();
      bidAnalytics.value = analytics;
      print('✅ Fetched bid analytics: $analytics');
    } catch (e) {
      print('❌ Error fetching bid analytics: $e');
      bidAnalytics.value = {};
    }
  }

  Future<void> withdrawBid(String bidId) async {
    try {
      await _bidService.withdrawBid(bidId);
      // Refresh bids after withdrawal
      await fetchMyBids();
      Get.snackbar(
        'Success',
        'Bid withdrawn successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to withdraw bid: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Only switch tab. Do NOT fetch with filter — we always have all bids and split into active/won/lost client-side.
  void updateSelectedTab(int index) {
    if (selectedTab.value == index) return;
    selectedTab.value = index;
  }
}

