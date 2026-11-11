import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/product_details_screen.dart';

class BidDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bid;
  final Car? vehicle; // Optional vehicle data

  const BidDetailScreen({
    super.key,
    required this.bid,
    this.vehicle,
  });

  @override
  State<BidDetailScreen> createState() => _BidDetailScreenState();
}

class _BidDetailScreenState extends State<BidDetailScreen> {
  final BidService _bidService = BidService();
  final CarService _carService = CarService();
  bool _isLoading = false;
  bool _isAccepting = false;
  Map<String, dynamic>? _bidDetails;
  Car? _vehicle;

  @override
  void initState() {
    super.initState();
    _bidDetails = widget.bid;
    _vehicle = widget.vehicle;
    _loadBidDetails();
  }

  Future<void> _loadBidDetails() async {
    if (_vehicle == null && _bidDetails?['vehicle'] != null) {
      try {
        final vehicleData = _bidDetails!['vehicle'] as Map<String, dynamic>;
        final vehicleId = vehicleData['id'].toString();
        
        // Fetch full vehicle details
        final vehicle = await _carService.getVehicleById(vehicleId);
        if (vehicle != null) {
          setState(() {
            _vehicle = vehicle;
          });
        }
      } catch (e) {
        print('⚠️ Error loading vehicle details: $e');
      }
    }
  }

  Future<void> _acceptBid() async {
    final bidId = _bidDetails?['id']?.toString() ?? widget.bid['id']?.toString();
    if (bidId == null) {
      Get.snackbar(
        'Error',
        'Bid ID not found',
        backgroundColor: Colors.grey[900],
        colorText: kWhiteColor,
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirm Bid Acceptance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to accept this bid?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action will:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Mark this bid as winning'),
                  const Text('• Mark vehicle as sold'),
                  const Text('• End the auction'),
                  const Text('• Create transport order'),
                  const Text('• Generate invoice'),
                  const Text('• Notify the buyer'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kBlackColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: kWhiteColor,
            ),
            child: const Text('Confirm & Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isAccepting = true);

    try {
      final isBuyNow = _bidDetails?['is_buy_now'] as bool? ?? 
                       widget.bid['is_buy_now'] as bool? ?? false;

      Map<String, dynamic> result;
      if (isBuyNow) {
        result = await _bidService.acceptBuyNow(bidId);
      } else {
        result = await _bidService.acceptBid(bidId);
      }

      // Show success message
      Get.snackbar(
        'Success',
        result['message'] as String? ?? 'Bid accepted successfully!',
        backgroundColor: kBlackColor,
        colorText: kWhiteColor,
        duration: const Duration(seconds: 3),
      );

      // Refresh home page data
      try {
        final homeController = Get.find<HomePageController>();
        await homeController.fetchCars();
        await homeController.fetchSellerDashboardData();
      } catch (e) {
        print('⚠️ HomePageController not found: $e');
      }

      // Refresh vehicle data if available
      if (_vehicle != null) {
        try {
          final updatedVehicle = await _carService.getVehicleById(_vehicle!.id);
          if (updatedVehicle != null) {
            setState(() {
              _vehicle = updatedVehicle;
            });
          }
        } catch (e) {
          print('⚠️ Error refreshing vehicle: $e');
        }
      }

      // Update bid details
      if (result['bid'] != null) {
        setState(() {
          _bidDetails = {
            ...(_bidDetails ?? widget.bid),
            ...result['bid'] as Map<String, dynamic>,
            'is_winning_bid': true,
          };
        });
      }

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to accept bid: ${e.toString()}',
        backgroundColor: Colors.grey[900],
        colorText: kWhiteColor,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = _bidDetails ?? widget.bid;
    final vehicle = _vehicle ?? widget.vehicle;
    
    final bidAmount = (bid['bid_amount'] is int)
        ? (bid['bid_amount'] as int).toDouble()
        : (bid['bid_amount'] as double? ?? 0.0);
    final isWinning = bid['is_winning_bid'] as bool? ?? false;
    final isBuyNow = bid['is_buy_now'] as bool? ?? false;
    final userName = bid['user_name'] as String? ?? 'Anonymous';
    final userId = bid['user_id']?.toString();
    final createdAt = bid['created_at'] as String? ?? '';
    final bidId = bid['id']?.toString() ?? '';
    final status = bid['status'] as String? ?? 'pending';

    // Check if seller can accept this bid
    final canAccept = vehicle != null && 
                      vehicle.status == 'active' && 
                      !isWinning && 
                      !_isAccepting;

    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Bid Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: kWhiteColor,
          ),
        ),
        backgroundColor: kAccentColor,
        foregroundColor: kWhiteColor,
        elevation: 0,
        toolbarHeight: 52,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Info Card
            if (vehicle != null) ...[
              _buildVehicleCard(vehicle),
              const SizedBox(height: 10),
            ],

            // Bid Info Card
            _buildBidInfoCard(
              bidAmount: bidAmount,
              isWinning: isWinning,
              isBuyNow: isBuyNow,
              userName: userName,
              userId: userId,
              createdAt: createdAt,
              status: status,
            ),

            const SizedBox(height: 10),

            // Bidder Info Card
            if (userId != null) ...[
              _buildBidderInfoCard(userId, userName),
              const SizedBox(height: 10),
            ],

            // Action Buttons
            if (canAccept) ...[
              _buildActionButtons(),
              const SizedBox(height: 10),
            ],

            // Status Info
            if (isWinning)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAccentColor.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: kAccentColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This bid has been accepted and is the winning bid.',
                        style: TextStyle(
                          color: Colors.grey[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!canAccept && vehicle?.status != 'active')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[800], size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This vehicle is no longer available for bidding.',
                        style: TextStyle(
                          color: Colors.grey[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Car vehicle) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(car: vehicle),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle.year} ${vehicle.make} ${vehicle.model}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              vehicle.location.isNotEmpty ? vehicle.location : 'Location not specified',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: vehicle.status == 'active'
                          ? kAccentColor.withOpacity(0.12)
                          : Colors.grey[300]!.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: vehicle.status == 'active'
                            ? kAccentColor.withOpacity(0.5)
                            : Colors.grey[400]!,
                      ),
                    ),
                    child: Text(
                      vehicle.status?.toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        color: vehicle.status == 'active' ? kBlackColor : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Starting Bid',
                      '\$${vehicle.startingBid.toStringAsFixed(0)}',
                      Icons.gavel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoItem(
                      'Buy Now',
                      vehicle.buyNowPrice != null
                          ? '\$${vehicle.buyNowPrice!.toStringAsFixed(0)}'
                          : 'N/A',
                      Icons.shopping_cart,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidInfoCard({
    required double bidAmount,
    required bool isWinning,
    required bool isBuyNow,
    required String userName,
    String? userId,
    required String createdAt,
    required String status,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bid Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${bidAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: kBlackColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWinning)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kAccentColor.withOpacity(0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 16, color: kAccentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Winning',
                          style: TextStyle(
                            color: kBlackColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isBuyNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.grey[800]),
                        const SizedBox(width: 6),
                        Text(
                          'Buy now',
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_empty, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Bidder', userName),
            const SizedBox(height: 12),
            _buildDetailRow('Bid Type', isBuyNow ? 'Buy Now' : 'Regular Bid'),
            const SizedBox(height: 12),
            _buildDetailRow('Status', status.toUpperCase()),
            const SizedBox(height: 12),
            _buildDetailRow('Placed On', _formatDate(createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildBidderInfoCard(String userId, String userName) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bidder Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kBlackColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: kAccentColor,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: kWhiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ID: $userId',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final bidderInfo = await _bidService.getBidderInfo(userId);
                      _showBidderDetailsDialog(bidderInfo);
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        'Failed to load bidder info: ${e.toString()}',
                        backgroundColor: Colors.grey[900],
                        colorText: kWhiteColor,
                      );
                    }
                  },
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('View Profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAccepting ? null : _acceptBid,
            icon: _isAccepting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_circle, size: 24),
            label: Text(
              _isAccepting ? 'Accepting Bid...' : 'Accept & Confirm Bid',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: kWhiteColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
      ],
    );
  }

  void _showBidderDetailsDialog(Map<String, dynamic> bidderInfo) {
    Get.dialog(
      AlertDialog(
        title: Text(bidderInfo['name'] ?? 'Bidder Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', bidderInfo['email'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow('Total Bids', bidderInfo['total_bids']?.toString() ?? '0'),
              const SizedBox(height: 12),
              _buildDetailRow('Winning Bids', bidderInfo['winning_bids']?.toString() ?? '0'),
              const SizedBox(height: 12),
              _buildDetailRow('Success Rate', '${bidderInfo['success_rate']?.toStringAsFixed(1) ?? '0.0'}%'),
              const SizedBox(height: 12),
              _buildDetailRow('Average Bid', '\$${bidderInfo['average_bid']?.toStringAsFixed(0) ?? '0'}'),
              const SizedBox(height: 12),
              _buildDetailRow('Total Spent', '\$${bidderInfo['total_spent']?.toStringAsFixed(0) ?? '0'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
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
        return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }
}

