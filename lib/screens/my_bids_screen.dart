import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/screens/onboarding_screen.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:carauction/screens/buy_now_screen.dart';
import 'package:carauction/screens/purchase_details_screen.dart';
import 'package:carauction/screens/bid_details_screen.dart';
import 'package:carauction/screens/chat_screen.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key, this.initialTabIndex});

  /// 0 All, 1 Active, 2 Won, 3 Lost — used when opening from notifications.
  final int? initialTabIndex;

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<BidController>()) {
      Get.put(BidController(), permanent: true);
    }
    final idx = widget.initialTabIndex;
    if (idx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Get.find<BidController>().updateSelectedTab(idx.clamp(0, 3));
      });
    }
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        final controller = Get.find<BidController>();
        controller.fetchMyBids();
        controller.fetchSwapOffers();
        controller.fetchBidAnalytics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return GetBuilder<BidController>(
      builder: (controller) {
        return FutureBuilder<void>(
          future: _ensureDataLoaded(controller),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                controller.myBids.isEmpty &&
                controller.isLoading.value) {
              return SafeScaffold(
                backgroundColor: Colors.grey[50],
                enableScroll: false,
                appBar: AppBar(
                  title: Text(
                    'My Bids',
                    style: TextStyle(
                      fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingLarge : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: kWhiteColor,
                    ),
                  ),
                  backgroundColor: kAccentColor,
                  foregroundColor: kWhiteColor,
                  elevation: 0,
                  toolbarHeight: 52,
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your bids...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return WillPopScope(
              onWillPop: () async {
                return true;
              },
              child: SafeScaffold(
                backgroundColor: Colors.grey[50],
                enableScroll: false,
                appBar: AppBar(
                  title: Text(
                    'My Bids',
                    style: TextStyle(
                      fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingLarge : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: kWhiteColor,
                    ),
                  ),
                  backgroundColor: kAccentColor,
                  foregroundColor: kWhiteColor,
                  elevation: 0,
                  toolbarHeight: 52,
                ),
                body: Column(
                  children: [
                    // _buildBidDashboard(context, controller),
                    const SizedBox(width: 6),
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildBalancedTabButton(context, 'All Bids', 0, controller),
                            const SizedBox(width: 6),
                            _buildBalancedTabButton(context, 'Active Bids', 1, controller),
                            const SizedBox(width: 6),
                            _buildBalancedTabButton(context, 'Won', 2, controller),
                            const SizedBox(width: 6),
                            _buildBalancedTabButton(context, 'Lost', 3, controller),
                          ],
                        ),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value && controller.myBids.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading your bids...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        switch (controller.selectedTab.value) {
                          case 0:
                            return _buildAllBids(context, controller);
                          case 1:
                            return _buildActiveBids(context, controller);
                          case 2:
                            return _buildWonAuctions(context, controller);
                          case 3:
                            return _buildLostAuctions(context, controller);
                          default:
                            return _buildAllBids(context, controller);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _ensureDataLoaded(BidController controller) async {
    if (controller.isLoading.value) {
      int attempts = 0;
      while (controller.isLoading.value && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }
    await controller.fetchMyBids();
    await controller.fetchSwapOffers();
    await controller.fetchBidAnalytics();
  }

  Future<void> _refreshBidsData(BidController controller) async {
    await controller.fetchMyBids();
    await controller.fetchSwapOffers();
    await controller.fetchBidAnalytics();
  }

  /// Buyer analytics + quick stats (API: GET bids/analytics/buyer).
  Widget _buildBidDashboard(BuildContext context, BidController controller) {
    return Obx(() {
      final m = controller.bidAnalytics.value;
      if (m == null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
            ),
          ),
        );
      }
      if (m.isEmpty) {
        return const SizedBox.shrink();
      }
      int n(dynamic v) {
        if (v is num) return v.round();
        return int.tryParse(v?.toString() ?? '0') ?? 0;
      }

      double d(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '0') ?? 0;
      }

      final totalBids = n(m['total_bids']);
      final activeBids = n(m['active_bids']);
      final wonBids = n(m['won_bids']);
      final winRate = d(m['success_rate']);
      final avgBid = d(m['average_bid']);
      final highest = d(m['highest_bid']);
      final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

      Widget tile(String label, String value) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlackColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_outlined, size: 18, color: Colors.grey[800]),
                const SizedBox(width: 6),
                Text(
                  'Overview',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey[900]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 560;
                final cells = [
                  tile('Total bids', '$totalBids'),
                  tile('Active', '$activeBids'),
                  tile('Won', '$wonBids'),
                  tile('Win rate', '${winRate.toStringAsFixed(0)}%'),
                  tile('Avg bid', currency.format(avgBid)),
                  tile('Highest', currency.format(highest)),
                ];
                if (wide) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cells.map((w) {
                      return SizedBox(width: (c.maxWidth - 16) / 3, child: w);
                    }).toList(),
                  );
                }
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.85,
                  children: cells,
                );
              },
            ),
          ],
        ),
      );
    });
  }

  void _openBidDetailsScreen(BuildContext context, dynamic bid) {
    if (bid is! Map) return;
    final map = Map<String, dynamic>.from(bid);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => BidDetailsScreen(bid: map),
      ),
    );
  }

  // ============ BALANCED TAB BUTTON ============
  Widget _buildBalancedTabButton(BuildContext context, String title, int index, BidController controller) {
    return Obx(() {
      final isSelected = controller.selectedTab.value == index;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? kAccentColor : kWhiteColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
            color: kAccentColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: kAccentColor.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => controller.updateSelectedTab(index),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Balanced
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, // Balanced
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kWhiteColor : kBlackColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAllBids(BuildContext context, BidController controller) {
    if (controller.isLoading.value && controller.myBids.isEmpty) {
      return const Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }

    if (controller.myBids.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshBidsData(controller),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const EmptyStateWidget(
              type: EmptyStateType.emptyBids,
              title: 'No Bids',
              message: 'Start bidding on vehicles to see them here',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshBidsData(controller),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: controller.myBids.length,
        itemBuilder: (context, index) {
          final bid = controller.myBids[index];
          final vehicle = bid['vehicle'] as Map<String, dynamic>?;
          final vehicleStatus = vehicle?['status'] as String?;
          final auctionEndTimeStr = vehicle?['auction_end_time'] as String?;
          final now = DateTime.now();
          bool isActive = false;

          if (auctionEndTimeStr != null) {
            try {
              final auctionEndTime = DateTime.parse(auctionEndTimeStr);
              isActive = auctionEndTime.isAfter(now) && (vehicleStatus == 'active' || vehicleStatus == null);
            } catch (e) {
              isActive = vehicleStatus == 'active' || vehicleStatus == null;
            }
          } else {
            isActive = vehicleStatus == 'active' || vehicleStatus == null;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBalancedBidCard(context, bid, controller, isActive: isActive),
          );
        },
      ),
    );
  }

  Widget _buildActiveBids(BuildContext context, BidController controller) {
    if (controller.isLoading.value && controller.activeBids.isEmpty && controller.myBids.isEmpty) {
      return const Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }

    final activeSwapOffers = _getActiveSwapOffers(controller);
    if (controller.activeBids.isEmpty && activeSwapOffers.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshBidsData(controller),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const EmptyStateWidget(
              type: EmptyStateType.emptyBids,
              title: 'No Active Bids',
              message: 'Vehicles you have bidded on (auction still live) will appear here',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshBidsData(controller),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: controller.activeBids.length + _getActiveSwapOffers(controller).length,
        itemBuilder: (context, index) {
          if (index < controller.activeBids.length) {
            final bid = controller.activeBids[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBalancedBidCard(context, bid, controller, isActive: true),
            );
          } else {
            final swapOffers = _getActiveSwapOffers(controller);
            final swapIndex = index - controller.activeBids.length;
            if (swapIndex < swapOffers.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBalancedSwapOfferCard(context, swapOffers[swapIndex], controller, isActive: true),
              );
            }
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildWonAuctions(BuildContext context, BidController controller) {
    if (controller.isLoading.value && controller.wonBids.isEmpty) {
      return const Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }

    if (controller.wonBids.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshBidsData(controller),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const EmptyStateWidget(
              type: EmptyStateType.emptyBids,
              title: 'No Won',
              message: 'Vehicles you won or purchased will appear here',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshBidsData(controller),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: controller.wonBids.length,
        itemBuilder: (context, index) {
          final bid = controller.wonBids[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBalancedBidCard(context, bid, controller, isActive: false),
          );
        },
      ),
    );
  }

  Widget _buildLostAuctions(BuildContext context, BidController controller) {
    if (controller.isLoading.value && controller.lostBids.isEmpty) {
      return const Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }

    if (controller.lostBids.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshBidsData(controller),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const EmptyStateWidget(
              type: EmptyStateType.emptyBids,
              title: 'No Lost',
              message: 'Vehicles you lost the auction on will appear here',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshBidsData(controller),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: controller.lostBids.length,
        itemBuilder: (context, index) {
          final bid = controller.lostBids[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBalancedBidCard(context, bid, controller, isActive: false),
          );
        },
      ),
    );
  }

  List<dynamic> _getActiveSwapOffers(BidController controller) {
    final pendingOffers = controller.swapOffers.where((offer) {
      final status = offer['status'] as String?;
      return status == 'pending';
    }).toList();

    final Map<String, dynamic> uniqueOffers = {};
    for (var offer in pendingOffers) {
      final vehicleId = offer['vehicle_id']?.toString() ?? '';
      if (vehicleId.isNotEmpty) {
        if (!uniqueOffers.containsKey(vehicleId)) {
          uniqueOffers[vehicleId] = offer;
        } else {
          final existingCreatedAt = uniqueOffers[vehicleId]?['created_at'] as String? ?? '';
          final currentCreatedAt = offer['created_at'] as String? ?? '';
          if (currentCreatedAt.isNotEmpty &&
              (existingCreatedAt.isEmpty || currentCreatedAt.compareTo(existingCreatedAt) > 0)) {
            uniqueOffers[vehicleId] = offer;
          }
        }
      }
    }

    return uniqueOffers.values.toList();
  }

  List<dynamic> _getHistorySwapOffers(BidController controller) {
    final historyOffers = controller.swapOffers.where((offer) {
      final status = offer['status'] as String?;
      return status == 'accepted' || status == 'rejected' || status == 'cancelled';
    }).toList();

    final Map<String, dynamic> uniqueOffers = {};
    for (var offer in historyOffers) {
      final vehicleId = offer['vehicle_id']?.toString() ?? '';
      if (vehicleId.isNotEmpty) {
        if (!uniqueOffers.containsKey(vehicleId)) {
          uniqueOffers[vehicleId] = offer;
        } else {
          final existingCreatedAt = uniqueOffers[vehicleId]?['created_at'] as String? ?? '';
          final currentCreatedAt = offer['created_at'] as String? ?? '';
          if (currentCreatedAt.isNotEmpty &&
              (existingCreatedAt.isEmpty || currentCreatedAt.compareTo(existingCreatedAt) > 0)) {
            uniqueOffers[vehicleId] = offer;
          }
        }
      }
    }

    return uniqueOffers.values.toList();
  }

  // ============ BALANCED SWAP OFFER CARD ============
  Widget _buildBalancedSwapOfferCard(BuildContext context, dynamic swapOffer, BidController controller, {required bool isActive}) {
    final vehicle = swapOffer['vehicle'] as Map<String, dynamic>?;
    final status = swapOffer['status'] as String? ?? 'pending';
    final buyerVehicleValue = (swapOffer['buyer_vehicle_value'] is int)
        ? (swapOffer['buyer_vehicle_value'] as int).toDouble()
        : (swapOffer['buyer_vehicle_value'] as double? ?? 0.0);
    final additionalPayment = (swapOffer['additional_payment'] is int)
        ? (swapOffer['additional_payment'] as int).toDouble()
        : (swapOffer['additional_payment'] as double? ?? 0.0);
    final totalValue = buyerVehicleValue + additionalPayment;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: vehicle != null ? () async {
            try {
              final vehicleId = vehicle['id'].toString();
              final vehicleStatus = vehicle['status'] as String? ?? 'active';
              final auctionEndTimeStr = vehicle['auction_end_time'] as String?;

              DateTime auctionEndTime;
              try {
                auctionEndTime = auctionEndTimeStr != null
                    ? DateTime.parse(auctionEndTimeStr)
                    : DateTime.now().add(const Duration(days: 7));
              } catch (e) {
                auctionEndTime = DateTime.now().add(const Duration(days: 7));
              }

              final startingBid = (vehicle['startingBid'] is num)
                  ? (vehicle['startingBid'] as num).toDouble()
                  : (vehicle['starting_bid'] is num)
                  ? (vehicle['starting_bid'] as num).toDouble()
                  : 0.0;

              final buyNowPrice = (vehicle['buyNowPrice'] is num)
                  ? (vehicle['buyNowPrice'] as num).toDouble()
                  : (vehicle['buy_now_price'] is num)
                  ? (vehicle['buy_now_price'] as num).toDouble()
                  : 0.0;

              final mileage = (vehicle['mileage'] is int)
                  ? vehicle['mileage'] as int
                  : ((vehicle['mileage'] is String) ? int.tryParse(vehicle['mileage']) ?? 0 : 0);

              final car = Car(
                id: vehicleId,
                make: vehicle['make'] as String? ?? 'Unknown',
                model: vehicle['model'] as String? ?? 'Vehicle',
                year: (vehicle['year'] is int)
                    ? vehicle['year'] as int
                    : ((vehicle['year'] is String) ? int.tryParse(vehicle['year']) ?? 0 : 0),
                imageUrl: vehicle['imageUrl'] as String? ?? vehicle['image_url'] as String? ?? 'assets/images/car1.png',
                startingBid: startingBid,
                buyNowPrice: buyNowPrice,
                mileage: mileage,
                location: vehicle['location'] as String? ?? '',
                distance: vehicle['distance'] as String? ?? '',
                auctionEndTime: auctionEndTime,
                status: vehicleStatus,
                vin: vehicle['vin'] as String?,
                description: vehicle['description'] as String?,
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsScreen(car: car),
                ),
              );
            } catch (e) {
              print('❌ Error navigating to vehicle: $e');
              Get.snackbar('Error', 'Could not load vehicle details');
            }
          } : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vehicle != null)
                            Text(
                              '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}',
                              style: TextStyle(
                                fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingMedium : 15,
                                fontWeight: FontWeight.bold,
                                color: kBlackColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.swap_horiz, size: 14, color: kAccentColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Swap',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '\$${totalValue.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: kBlackColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'accepted'
                            ? kAccentColor.withOpacity(0.12)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: status == 'accepted'
                              ? kAccentColor.withOpacity(0.4)
                              : Colors.grey[400]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'accepted'
                                ? Icons.check_circle
                                : status == 'rejected'
                                ? Icons.cancel
                                : status == 'cancelled'
                                ? Icons.remove_circle_outline
                                : Icons.hourglass_empty,
                            size: 11,
                            color: Colors.grey[900],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            status == 'accepted'
                                ? 'Accepted'
                                : status == 'rejected'
                                ? 'Rejected'
                                : status == 'cancelled'
                                ? 'Cancelled'
                                : 'Pending',
                            style: TextStyle(
                              color: Colors.grey[900],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final bidId = swapOffer['id']?.toString();
                              if (bidId == null) return;
                              final ok = await controller.cancelSwapOffer(bidId);
                              if (context.mounted) {
                                if (ok) {
                                  Get.snackbar('Done', 'Swap offer cancelled', snackPosition: SnackPosition.BOTTOM);
                                } else {
                                  Get.snackbar('Error', 'Could not cancel swap offer', snackPosition: SnackPosition.BOTTOM);
                                }
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kBlackColor,
                              side: BorderSide(color: Colors.grey[400]!),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ BALANCED BID CARD ============
  Widget _buildBalancedBidCard(BuildContext context, dynamic bid, BidController controller, {required bool isActive}) {
    final vehicle = bid['vehicle'] as Map<String, dynamic>?;
    final auction = bid['auction'] as Map<String, dynamic>?;

    final bidAmount = (bid['amount'] is int)
        ? (bid['amount'] as int).toDouble()
        : (bid['amount'] is double)
        ? (bid['amount'] as double)
        : (bid['bid_amount'] is int)
        ? (bid['bid_amount'] as int).toDouble()
        : (bid['bid_amount'] as double? ?? 0.0);

    final bidStatus = bid['bid_status'] as String?;
    final bidStatusText = bid['bid_status_text'] as String?;
    final isWinning = bid['is_winning_bid'] as bool? ?? false;
    final isBuyNow = bid['is_buy_now'] as bool? ?? false;

    final currentBid = auction != null
        ? ((auction['current_bid'] is int)
        ? (auction['current_bid'] as int).toDouble()
        : (auction['current_bid'] as double? ?? bidAmount))
        : bidAmount;

    final vehicleStatus = vehicle?['status'] as String?;
    final auctionEndTimeStr = auction?['end_time'] as String? ?? vehicle?['auction_end_time'] as String?;
    final now = DateTime.now();
    bool auctionEnded = false;

    if (auctionEndTimeStr != null) {
      try {
        final auctionEndTime = DateTime.parse(auctionEndTimeStr);
        auctionEnded = auctionEndTime.isBefore(now);
      } catch (e) {
        auctionEnded = false;
      }
    }

    final isActuallyWinning = bidStatus == 'won' || (isWinning && (auctionEnded || vehicleStatus == 'sold' || vehicleStatus == 'won'));
    final isLost = bidStatus == 'lost' || (auctionEnded && !isActuallyWinning && !isBuyNow);
    final isOutbid = bidStatus == 'outbid' || (isActive && !isWinning && !isBuyNow);

    final vehicleStatusLower = (vehicleStatus ?? '').toString().toLowerCase();
    // Won / sold listing: show invoice & purchase flow, not Buy Now checkout again.
    final purchaseCompleted = bidStatus == 'won' ||
        vehicleStatusLower == 'sold' ||
        vehicleStatusLower == 'won';

    final bidId = bid['id'].toString();
    final createdAt = bid['bid_time'] as String? ?? bid['created_at'] as String? ?? '';

    String? timeRemaining;
    if (isActive && auctionEndTimeStr != null) {
      try {
        final auctionEndTime = DateTime.parse(auctionEndTimeStr);
        final difference = auctionEndTime.difference(now);
        if (difference.inDays > 0) {
          timeRemaining = '${difference.inDays}d ${difference.inHours % 24}h';
        } else if (difference.inHours > 0) {
          timeRemaining = '${difference.inHours}h ${difference.inMinutes % 60}m';
        } else {
          timeRemaining = '${difference.inMinutes}m';
        }
      } catch (e) {}
    }

    String formatDateTime(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return 'N/A';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('MMM d, y').format(date);
      } catch (e) {
        return dateStr;
      }
    }

    final imageUrl = vehicle?['imageUrl'] as String? ?? vehicle?['image_url'] as String? ?? 'assets/images/car1.png';
    final locationZip = (vehicle?['location_zip'] ?? vehicle?['location'])?.toString().trim();
    final locationDisplay = (locationZip != null && locationZip.isNotEmpty) ? locationZip : 'N/A';
    final auctionEndFormatted = formatDateTime(auctionEndTimeStr);
    final bidPlacedFormatted = formatDateTime(createdAt.isNotEmpty ? createdAt : null);
    final bidAmountFormatted = NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(bidAmount);
    final currentBidFormatted = NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(currentBid);

    final canDelete = isActive && !isWinning && !isBuyNow;

    final screenWidth = ScreenSize.screenWidth;
    final imageWidth = (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? screenWidth * 0.26 : screenWidth * 0.3;
    final imageHeight = (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.productCardImageHeight : 120;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useVerticalLayout = constraints.maxWidth < 350;

          if (useVerticalLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: _buildBalancedVehicleImage(
                    context,
                    imageUrl,
                    width: double.infinity,
                    height: 140,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildBalancedCardContent(
                    context,
                    vehicle,
                    timeRemaining,
                    bidStatus,
                    bidStatusText,
                    isBuyNow,
                    isWinning,
                    isActive,
                    isLost,
                    bidAmountFormatted,
                    currentBidFormatted,
                    bidPlacedFormatted,
                    auctionEndFormatted,
                    locationDisplay,
                    vehicle,
                    bidAmount,
                    currentBid,
                    auctionEndTimeStr,
                    isActuallyWinning,
                    canDelete,
                    bidId,
                    controller,
                    isOutbid,
                    purchaseCompleted,
                    13,
                    () => _openBidDetailsScreen(context, bid),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: _buildBalancedVehicleImage(
                  context,
                  imageUrl,
                  width: imageWidth,
                  height: imageHeight.toDouble(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildBalancedCardContent(
                    context,
                    vehicle,
                    timeRemaining,
                    bidStatus,
                    bidStatusText,
                    isBuyNow,
                    isWinning,
                    isActive,
                    isLost,
                    bidAmountFormatted,
                    currentBidFormatted,
                    bidPlacedFormatted,
                    auctionEndFormatted,
                    locationDisplay,
                    vehicle,
                    bidAmount,
                    currentBid,
                    auctionEndTimeStr,
                    isActuallyWinning,
                    canDelete,
                    bidId,
                    controller,
                    isOutbid,
                    purchaseCompleted,
                    13,
                    () => _openBidDetailsScreen(context, bid),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalancedVehicleImage(BuildContext context, String imageUrl, {required double width, required double height}) {
    final bool isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final bool isAsset = imageUrl.startsWith('assets/');

    if (isNetwork) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 32),
          );
        },
      );
    } else if (isAsset) {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 32),
          );
        },
      );
    } else {
      try {
        final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        final fullUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
        return Image.network(
          fullUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 32),
            );
          },
        );
      } catch (e) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 32),
        );
      }
    }
  }

  // ============ BALANCED CARD CONTENT ============
  Widget _buildBalancedCardContent(
      BuildContext context,
      Map<String, dynamic>? vehicle,
      String? timeRemaining,
      String? bidStatus,
      String? bidStatusText,
      bool isBuyNow,
      bool isWinning,
      bool isActive,
      bool isLost,
      String bidAmountDisplay,
      String currentBidDisplay,
      String bidPlacedFormatted,
      String auctionEndFormatted,
      String locationDisplay,
      Map<String, dynamic>? vehicleForNav,
      double bidAmountForNav,
      double currentBidForNav,
      String? auctionEndTimeStr,
      bool isActuallyWinning,
      bool canDelete,
      String bidId,
      BidController controller,
      bool isOutbid,
      bool purchaseCompleted,
      double fontSize,
      VoidCallback onOpenBidDetails,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title and Status Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _vehicleTitleFromApi(vehicle),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeRemaining != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: kAccentColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            timeRemaining!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlackColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBalancedStatusBadge(context, bidStatus, bidStatusText, isBuyNow, isWinning, isActive, isLost),
          ],
        ),
        const SizedBox(height: 10),

        // Bid Info
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Highest Bid:', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  Text(bidAmountDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Auction Bid:', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  Text(currentBidDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bid Placed:', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  Text(bidPlacedFormatted, style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Location and End Date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 10, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(locationDisplay, style: TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Text('Ends: $auctionEndFormatted', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),

        // Lost Message
        if (isLost) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: Colors.grey[800], size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lost auction',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[900]),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Action Buttons Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 86,
                child: OutlinedButton.icon(
                  onPressed: onOpenBidDetails,
                  icon: const Icon(Icons.insights_outlined, size: 12),
                  label: const Text('Details', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentColor,
                    side: const BorderSide(color: kAccentColor),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              // View/Bid Button
              SizedBox(
                width: 90,
                child: ElevatedButton.icon(
                  onPressed: vehicleForNav != null ? () => _navigateToVehicle(context, vehicleForNav, bidAmountForNav, auctionEndTimeStr) : null,
                  icon: Icon(isActive ? Icons.gavel : Icons.visibility, size: 12),
                  label: Text(isActive ? 'Bid' : 'View', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? kAccentColor : kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),

              // Contact Button
              SizedBox(
                width: 80,
                child: OutlinedButton.icon(
                  onPressed: () => _openContactSeller(context, vehicleForNav),
                  icon: const Icon(Icons.chat_bubble_outline, size: 11),
                  label: const Text('Contact', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentColor,
                    side: const BorderSide(color: kAccentColor),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),

              // Winning/Purchase/Increase Button
              if (isActive && isWinning)
                SizedBox(
                  width: 80,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.emoji_events, size: 11),
                    label: const Text('Winning', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: kWhiteColor,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                )
              else if (isActuallyWinning && !isActive && purchaseCompleted)
                SizedBox(
                  width: 90,
                  child: ElevatedButton.icon(
                    onPressed: () => _openPurchaseDetails(context, vehicleForNav, bidAmountForNav),
                    icon: const Icon(Icons.receipt_long, size: 11),
                    label: const Text('View purchase', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlackColor,
                      foregroundColor: kWhiteColor,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                )
              else if (isActuallyWinning && !isActive && !purchaseCompleted)
                SizedBox(
                  width: 80,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToPayment(context, vehicleForNav, bidAmountForNav),
                    icon: const Icon(Icons.shopping_cart, size: 11),
                    label: const Text('Buy', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                )
              else if (isActive && !isWinning && !isBuyNow)
                  SizedBox(
                    width: 80,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToVehicle(context, vehicleForNav, currentBidForNav, auctionEndTimeStr),
                      icon: const Icon(Icons.arrow_upward, size: 11),
                      label: const Text('Increase', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),

              // Delete Button
              if (canDelete)
                SizedBox(
                  width: 70,
                  child: OutlinedButton.icon(
                    onPressed: () => _showWithdrawDialog(bidId, controller),
                    icon: const Icon(Icons.delete_outline, size: 11),
                    label: const Text('Delete', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
            ],
          ),
        ],

        // Info Messages
        if (isOutbid && isActive)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 10, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Your bid is not the highest bid!', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                ),
              ],
            ),
          ),
        if (isActive && isWinning && !canDelete)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 10, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Cannot delete bid while you are the highest bidder.', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _vehicleTitleFromApi(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Vehicle';
    final y = vehicle['year']?.toString().trim() ?? '';
    final make = vehicle['make']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final title = '$y $make $model'.trim();
    return title.isNotEmpty ? title : 'Vehicle';
  }

  Future<void> _openContactSeller(BuildContext context, Map<String, dynamic>? vehicle) async {
    if (vehicle == null || !context.mounted) return;
    final sellerId = (vehicle['seller_id'] ?? vehicle['sellerId'])?.toString();
    if (sellerId == null || sellerId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seller info not available.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    final currentId = await PreferencesHelper.getUserId();
    if (currentId != null && currentId == sellerId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot message yourself.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    try {
      final chatService = ChatService();
      final res = await chatService.getOrCreateConversation(
        otherUserId: sellerId,
        relatedType: 'vehicle',
        relatedId: int.tryParse(vehicle['id']?.toString() ?? '0'),
      );
      if (!context.mounted) return;
      final otherUser = res['other_user'] as Map<String, dynamic>?;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: res['id'].toString(),
            otherUserName: otherUser?['name'] as String? ?? vehicle['seller_name'] as String? ?? 'Seller',
            otherUserId: sellerId,
            currentUserId: currentId,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToVehicle(BuildContext context, Map<String, dynamic>? vehicle, double bidAmount, String? auctionEndTimeStr) async {
    if (vehicle == null) return;

    try {
      final vehicleId = vehicle['id'].toString();
      final vehicleStatus = vehicle['status'] as String? ?? 'active';

      DateTime auctionEndTime;
      try {
        auctionEndTime = auctionEndTimeStr != null
            ? DateTime.parse(auctionEndTimeStr)
            : DateTime.now().add(const Duration(days: 7));
      } catch (e) {
        auctionEndTime = DateTime.now().add(const Duration(days: 7));
      }

      final imageUrl = vehicle['imageUrl'] as String? ?? vehicle['image_url'] as String? ?? 'assets/images/car1.png';

      final car = Car(
        id: vehicleId,
        make: vehicle['make'] as String? ?? 'Unknown',
        model: vehicle['model'] as String? ?? 'Vehicle',
        year: (vehicle['year'] is int)
            ? vehicle['year'] as int
            : ((vehicle['year'] is String) ? int.tryParse(vehicle['year']) ?? 0 : 0),
        imageUrl: imageUrl,
        startingBid: (vehicle['startingBid'] is num)
            ? (vehicle['startingBid'] as num).toDouble()
            : (vehicle['starting_bid'] is num)
            ? (vehicle['starting_bid'] as num).toDouble()
            : bidAmount,
        buyNowPrice: (vehicle['buyNowPrice'] is num)
            ? (vehicle['buyNowPrice'] as num).toDouble()
            : (vehicle['buy_now_price'] is num)
            ? (vehicle['buy_now_price'] as num).toDouble()
            : 0.0,
        mileage: (vehicle['mileage'] is int)
            ? vehicle['mileage'] as int
            : ((vehicle['mileage'] is String) ? int.tryParse(vehicle['mileage']) ?? 0 : 0),
        location: vehicle['location'] as String? ?? '',
        distance: vehicle['distance'] as String? ?? '',
        auctionEndTime: auctionEndTime,
        status: vehicleStatus,
        vin: vehicle['vin'] as String?,
        description: vehicle['description'] as String?,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailsScreen(car: car),
        ),
      );
    } catch (e) {
      print('❌ Error navigating to vehicle: $e');
      Get.snackbar('Error', 'Could not load vehicle details');
    }
  }

  Car _carFromMyBidVehicleMap(Map<String, dynamic> vehicle, double bidAmount) {
    final vehicleId = vehicle['id'].toString();
    final imageUrl = vehicle['imageUrl'] as String? ?? vehicle['image_url'] as String? ?? 'assets/images/car1.png';
    return Car(
      id: vehicleId,
      make: vehicle['make'] as String? ?? 'Unknown',
      model: vehicle['model'] as String? ?? 'Vehicle',
      year: (vehicle['year'] is int)
          ? vehicle['year'] as int
          : ((vehicle['year'] is String) ? int.tryParse(vehicle['year']) ?? 0 : 0),
      imageUrl: imageUrl,
      startingBid: bidAmount,
      buyNowPrice: bidAmount,
      mileage: (vehicle['mileage'] is int)
          ? vehicle['mileage'] as int
          : ((vehicle['mileage'] is String) ? int.tryParse(vehicle['mileage']) ?? 0 : 0),
      location: vehicle['location'] as String? ?? '',
      distance: vehicle['distance'] as String? ?? '',
      auctionEndTime: DateTime.now(),
      status: 'sold',
      vin: vehicle['vin'] as String?,
      description: vehicle['description'] as String?,
      invoiceNumber: vehicle['invoice_number'] as String? ?? vehicle['invoiceNumber'] as String?,
      sellerId: vehicle['seller_id']?.toString() ?? vehicle['sellerId']?.toString(),
    );
  }

  Future<void> _openPurchaseDetails(BuildContext context, Map<String, dynamic>? vehicle, double bidAmount) async {
    if (vehicle == null) return;
    try {
      final vehicleId = vehicle['id'].toString();
      final carService = CarService();
      final fetched = await carService.getVehicleById(vehicleId);
      final car = fetched ?? _carFromMyBidVehicleMap(vehicle, bidAmount);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseDetailsScreen(car: car),
        ),
      );
    } catch (e) {
      print('❌ Error opening purchase details: $e');
      if (context.mounted) {
        Get.snackbar('Error', 'Could not open purchase details');
      }
    }
  }

  void _navigateToPayment(BuildContext context, Map<String, dynamic>? vehicle, double bidAmount) async {
    if (vehicle == null) return;

    try {
      final car = _carFromMyBidVehicleMap(vehicle, bidAmount);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BuyNowScreen(car: car),
        ),
      );

      if (result == true) {
        try {
          final bidController = Get.find<BidController>();
          await bidController.fetchMyBids();
        } catch (e) {
          print('⚠️ Could not refresh bids: $e');
        }
      }
    } catch (e) {
      print('❌ Error navigating to payment: $e');
      Get.snackbar('Error', 'Could not load payment screen');
    }
  }

  // ============ BALANCED STATUS BADGE ============
  Widget _buildBalancedStatusBadge(BuildContext context, String? bidStatus, String? bidStatusText, bool isBuyNow, bool isWinning, bool isActive, bool isLost) {
    final status = (bidStatus ?? '').toLowerCase();
    final badgePadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    const badgeFontSize = 11.0;
    const badgeIconSize = 12.0;
    final accentSoft = kAccentColor.withOpacity(0.14);
    final accentBorder = kAccentColor.withOpacity(0.35);
    final greySoft = Colors.grey[200]!;
    final greyBorder = Colors.grey[400]!;

    Widget badge(IconData icon, String label, {bool accent = false}) {
      return Container(
        padding: badgePadding,
        decoration: BoxDecoration(
          color: accent ? accentSoft : greySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent ? accentBorder : greyBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: badgeIconSize, color: accent ? kBlackColor : Colors.grey[800]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: badgeFontSize,
                  fontWeight: FontWeight.w700,
                  color: accent ? kBlackColor : Colors.grey[900],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'won' || (isWinning && !isActive)) {
      return badge(Icons.emoji_events, (status == 'won' ? 'Won' : null) ?? bidStatusText ?? 'Won', accent: true);
    }
    if (status == 'winning' || (isActive && isWinning)) {
      return badge(Icons.trending_up, bidStatusText ?? 'Winning', accent: true);
    }
    if (status == 'outbid' || (isActive && !isWinning && !isBuyNow)) {
      return badge(Icons.trending_down, bidStatusText ?? 'Outbid', accent: false);
    }
    if (isLost) {
      return badge(Icons.flag_outlined, 'Lost', accent: false);
    }

    // Dynamic Auction Status
    if (isActive) {
      final now = DateTime.now();
      // vehicle is passed in as a map to _buildBalancedBidCard, but not directly to this helper.
      // However, we can use the bidStatusText or fallback.
      // Looking at the caller, we might need more info.
      // But we can check if it's ending based on the label.
      // Actually, I'll just keep it simple or check if 'Active' should be 'Ending'.
      return badge(Icons.hourglass_empty, bidStatusText ?? 'Active', accent: false);
    }

    return badge(Icons.hourglass_empty, bidStatusText ?? 'Active', accent: false);
  }

  void _showWithdrawDialog(String bidId, BidController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('Withdraw Bid', style: TextStyle(fontSize: 16)),
        content: const Text('Are you sure you want to withdraw this bid?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.withdrawBid(bidId);
            },
            style: TextButton.styleFrom(foregroundColor: kBlackColor),
            child: const Text('Withdraw', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[date.month - 1]} ${date.day}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Now';
      }
    } catch (e) {
      return dateString;
    }
  }
}