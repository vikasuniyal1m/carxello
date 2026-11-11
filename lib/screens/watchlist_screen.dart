import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/watchlist_controller.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/widgets/empty_state_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    // Safely get or create watchlist controller
    WatchlistController watchlistController;
    try {
      watchlistController = Get.find<WatchlistController>();
    } catch (e) {
      // If not found, create it with permanent flag
      watchlistController = Get.put(WatchlistController(), permanent: true);
    }
    
    // Manually fetch watchlist if empty (in case controller was already initialized)
    // Load immediately when page opens (no delay)
    if (watchlistController.watchlist.isEmpty && !watchlistController.isLoading.value) {
      watchlistController.fetchWatchlist(); // Load immediately
    }

    return WillPopScope(
      onWillPop: () async {
        // Allow normal back navigation
        return true;
      },
      child: SafeScaffold(
      backgroundColor: Colors.grey[50],
      enableScroll: false,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        toolbarHeight: ScreenSize.isLargeTablet ? 64.0 : (ScreenSize.isSmallTablet ? ScreenSize.appBarHeight : ResponsiveHelper.appBarHeight(context)),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: ScreenSize.isLargeTablet ? 32.0 : (ScreenSize.isSmallTablet ? ScreenSize.iconLarge : 28.0),
        ),
        centerTitle: ScreenSize.isLargeTablet ? true : false,
        leadingWidth: ScreenSize.isLargeTablet ? 80.0 : null,
        title: Text(
          'My Watchlist',
          style: TextStyle(
            fontSize: ScreenSize.isLargeTablet ? 24.0 : (ScreenSize.isSmallTablet ? ScreenSize.headingMedium : 22.0),
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Obx(() {
        if (watchlistController.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                  strokeWidth: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? 4.0 : 3.0,
                ),
                SizedBox(height: ScreenSize.spacingLarge),
                Text(
                  'Loading watchlist...',
                  style: TextStyle(
                    fontSize: ScreenSize.textLarge,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        if (watchlistController.watchlist.isEmpty) {
          return const EmptyStateWidget(
            type: EmptyStateType.emptyWatchlist,
            title: 'No Vehicles in Watchlist',
            message: 'Start adding vehicles to your watchlist\nto keep track of your favorites',
          );
        }

        return RefreshIndicator(
          onRefresh: () => watchlistController.fetchWatchlist(),
          color: kAccentColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(ScreenSize.paddingMedium),
            itemCount: watchlistController.watchlist.length,
            itemBuilder: (context, index) {
              final item = watchlistController.watchlist[index];
              print('📦 WatchlistScreen: Building item $index: ${item.keys}');
              
              // Support both direct vehicle object and nested vehicle
              Map<String, dynamic>? vehicle;
              if (item['vehicle'] != null) {
                vehicle = item['vehicle'] as Map<String, dynamic>?;
              } else if (item.containsKey('id') && item.containsKey('make')) {
                // If item itself is vehicle data
                vehicle = item as Map<String, dynamic>;
              }
              
              if (vehicle == null) {
                print('⚠️ WatchlistScreen: Vehicle is null for item $index');
                return const SizedBox.shrink();
              }

              // Ensure imageUrl is set (API may send image_url or imageUrl)
              final mapped = Map<String, dynamic>.from(vehicle);
              if (mapped['imageUrl'] == null || mapped['imageUrl'].toString().isEmpty) {
                mapped['imageUrl'] = mapped['image_url'] ?? mapped['photo_url'] ?? 'assets/images/car1.png';
              }
              if (mapped['image_url'] == null || mapped['image_url'].toString().isEmpty) {
                mapped['image_url'] = mapped['imageUrl'];
              }

              try {
                print('   🚗 Parsing vehicle: ID=${mapped['id']}, Make=${mapped['make']}, Model=${mapped['model']}');
                final car = Car.fromJson(mapped);
                return _buildWatchlistCard(context, car, watchlistController);
              } catch (e) {
                print('❌ Error parsing vehicle: $e');
                print('   📄 Vehicle data: $vehicle');
                return const SizedBox.shrink();
              }
            },
          ),
        );
      }),
      ),
    );
  }

  Widget _buildWatchlistCard(
    BuildContext context,
    Car car,
    WatchlistController controller,
  ) {
    final imageSize = (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? 120.0 : 100.0;
    return Card(
      margin: EdgeInsets.only(bottom: ScreenSize.spacingMedium),
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenSize.borderRadiusMedium),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(car: car),
            ),
          ).then((_) {
            controller.fetchWatchlist();
          });
        },
        borderRadius: BorderRadius.circular(ScreenSize.borderRadiusMedium),
        child: Padding(
          padding: EdgeInsets.all(ScreenSize.paddingMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Image - consistent size, proper placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(ScreenSize.borderRadiusSmall),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: _buildVehicleImage(car.imageUrl, imageSize),
                ),
              ),
              SizedBox(width: ScreenSize.spacingMedium),
              // Vehicle Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${car.year} ${car.make} ${car.model}',
                      style: TextStyle(
                        fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textLarge : 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ScreenSize.spacingXSmall),
                    if (car.vin != null && car.vin!.isNotEmpty)
                      Text(
                        'VIN: ${car.vin}',
                        style: TextStyle(
                          fontSize: ScreenSize.textSmall,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: ScreenSize.spacingSmall),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '\$${_formatPrice(car.currentBid ?? car.price ?? car.startingBid)}',
                            style: TextStyle(
                              fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textLarge : 15,
                              fontWeight: FontWeight.bold,
                              color: kAccentColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (car.mileage != null && car.mileage! > 0) ...[
                          SizedBox(width: ScreenSize.spacingMedium),
                          Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${car.mileage!.toStringAsFixed(0)} mi',
                              style: TextStyle(
                                fontSize: ScreenSize.textSmall,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Remove from watchlist
              IconButton(
                icon: Icon(Icons.delete_outline, color: kAccentColor, size: ScreenSize.iconMedium),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Remove from Watchlist', style: TextStyle(fontSize: ScreenSize.headingSmall)),
                      content: Text('Remove this vehicle from your watchlist?', style: TextStyle(fontSize: ScreenSize.textMedium)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: TextStyle(fontSize: ScreenSize.textMedium)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Remove', style: TextStyle(color: Colors.red, fontSize: ScreenSize.textMedium, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await controller.removeFromWatchlist(car.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return value.toStringAsFixed(0);
  }

  /// Build vehicle image with full URL support and placeholder
  Widget _buildVehicleImage(String imageUrl, double size) {
    final hasValidUrl = imageUrl.isNotEmpty &&
        imageUrl != 'assets/images/car1.png' &&
        (imageUrl.startsWith('http') || imageUrl.startsWith('/') || imageUrl.contains('uploads'));
    if (!hasValidUrl) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[300],
        child: Icon(Icons.directions_car, size: size * 0.4, color: Colors.grey[500]),
      );
    }
    String fullUrl = imageUrl;
    if (!imageUrl.startsWith('http')) {
      final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      fullUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
    }
    return Image.network(
      fullUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: size,
          height: size,
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes!).toDouble()
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(Icons.directions_car, size: size * 0.4, color: Colors.grey[500]),
        );
      },
    );
  }
}

