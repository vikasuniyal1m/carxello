import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:carauction/screens/bid_detail_screen.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:carauction/screens/chat_screen.dart';
import 'package:carauction/utils/preferences_helper.dart';

class SellerBidManagementScreen extends StatefulWidget {
  final Car vehicle;

  const SellerBidManagementScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<SellerBidManagementScreen> createState() => _SellerBidManagementScreenState();
}

class _SellerBidManagementScreenState extends State<SellerBidManagementScreen> {
  final BidService _bidService = BidService();
  final CarService _carService = CarService();
  final ChatService _chatService = ChatService();

  List<dynamic> _bids = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Bids, 1: Analytics, 2: Top Bidders

  @override
  void initState() {
    super.initState();
    print('SellerBidManagementScreen: Initializing for Vehicle ID: ${widget.vehicle.id}');
    _fetchBids();
    _fetchAnalytics();
  }

  Future<void> _fetchBids() async {
    setState(() => _isLoading = true);
    try {
      final bids = await _bidService.getVehicleBids(widget.vehicle.id);
      setState(() {
        _bids = bids;
        _isLoading = false;
      });
      print('SellerBidManagementScreen: Fetched ${bids.length} bids for Vehicle ID: ${widget.vehicle.id}');
      if (bids.isNotEmpty) {
        print('SellerBidManagementScreen: First bid data: ${bids.first}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'Failed to load bids: ${e.toString()}');
      print('SellerBidManagementScreen: Error fetching bids: ${e.toString()}');
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final analytics = await _bidService.getVehicleBidAnalytics(widget.vehicle.id);
      setState(() => _analytics = analytics);
    } catch (e) {
      print('❌ Error fetching analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      enableScroll: false,
      appBar: AppBar(
        title: Text('Bids - ${widget.vehicle.year} ${widget.vehicle.make} ${widget.vehicle.model}'),
        backgroundColor: kAccentColor,
        foregroundColor: kWhiteColor,
      ),
      body: Column(
        children: [
          // Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Bid History', 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton('Analytics', 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton('Top Bidders', 2),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading bid data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => setState(() => _selectedTab = index),
        style: TextButton.styleFrom(
          backgroundColor: _selectedTab == index ? kAccentColor : Colors.white,
          foregroundColor: _selectedTab == index ? Colors.white : Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: _selectedTab == index
                ? BorderSide.none
                : BorderSide(color: Colors.grey[300]!, width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 6.0,
          ),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildBidHistory();
      case 1:
        return _buildAnalyticsView();
      case 2:
        return _buildTopBidders();
      default:
        return _buildBidHistory();
    }
  }

  Widget _buildBidHistory() {
    if (_bids.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Bids Yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Bids will appear here when buyers place them',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBids,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _bids.length + 1, // +1 for warning message
        itemBuilder: (context, index) {
          // Show warning message first (like manage-bids.php)
          if (index == 0 && (widget.vehicle.status == 'active' || widget.vehicle.status == 'live')) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.grey[800], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Accepting a bid will immediately end the auction and mark this vehicle as sold, even if the auction time hasn\'t expired yet. The winning buyer will be notified automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Adjust index for bids (subtract 1 if warning is shown)
          final bidIndex = (widget.vehicle.status == 'active' || widget.vehicle.status == 'live') 
              ? index - 1 
              : index;
          
          if (bidIndex < 0 || bidIndex >= _bids.length) {
            return const SizedBox.shrink();
          }
          
          final bid = _bids[bidIndex];
          return _buildBidCard(bid);
        },
      ),
    );
  }

  Widget _buildBidCard(dynamic bid) {
    final bidAmount = (bid['amount'] is int) 
        ? (bid['amount'] as int).toDouble() 
        : (bid['amount'] as double? ?? bid['bid_amount'] as double? ?? 0.0);
    final isWinning = bid['is_winning_bid'] as bool? ?? false;
    // Try multiple fields to get bidder name - ensure it's never empty
    final userName = bid['user_name'] as String? ?? 
                    bid['buyer_name'] as String? ?? 
                    bid['name'] as String? ?? 
                    'Unknown Bidder';
    final userEmail = bid['user_email'] as String? ?? bid['buyer_email'] as String?;
    final userPhone = bid['user_phone'] as String? ?? bid['buyer_phone'] as String?;
    final createdAt = bid['created_at'] as String? ?? '';
    final bidId = bid['id']?.toString() ?? '';
    
    // Debug: Print bid data if name is missing
    if (userName == 'Unknown Bidder') {
      print('⚠️ View Bids: Missing bidder name for bid ID: $bidId');
      print('   Bid data: ${bid.toString()}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Material(
        color: kWhiteColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openBidDetail(bid),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
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
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kBlackColor,
                            ),
                          ),
                          if (userEmail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (userPhone != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              userPhone,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                const TextSpan(text: 'Bid: '),
                                TextSpan(
                                  text: '\$${bidAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: kBlackColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(bid['status'] as String? ?? 'pending').withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(bid['status'] as String? ?? 'pending'),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusText(bid['status'] as String? ?? 'pending'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(bid['status'] as String? ?? 'pending'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                    if (isWinning)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kAccentColor, width: 1),
                        ),
                        child: Text(
                          'Winning',
                          style: TextStyle(
                            color: kAccentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = ResponsiveHelper.isMobile(context);
                  
                  if (isMobile) {
                    // Stack vertically on mobile
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                            Flexible(
                              child: Text(
                                _formatDate(createdAt),
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        Wrap(
                          spacing: ResponsiveHelper.spacing(context, 8),
                          runSpacing: ResponsiveHelper.spacing(context, 8),
                          children: [
                            // View Details Button
                            ElevatedButton.icon(
                              onPressed: () => _openBidDetail(bid),
                              icon: Icon(
                                Icons.visibility,
                                size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                              ),
                              label: Text('View Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccentColor,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(0, 34),
                                padding: ResponsiveHelper.padding(
                                  context,
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Message Bidder Button
                            ElevatedButton.icon(
                              onPressed: () => _messageBidder(bid),
                              icon: Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                              ),
                              label: const Text('Message'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: kAccentColor,
                                side: const BorderSide(color: kAccentColor, width: 1),
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            // Accept/Reject Bid Buttons
                            Builder(
                              builder: (context) {
                                final bidStatus = bid['status'] as String? ?? 'pending';
                                final canAcceptBid = (widget.vehicle.status == 'active' || 
                                                     widget.vehicle.status == 'live') && 
                                                    bidStatus == 'pending' &&
                                                    !isWinning;
                                
                                if (canAcceptBid) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _acceptBid(bidId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kAccentColor,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          minimumSize: const Size(0, 34),
                                          padding: ResponsiveHelper.padding(
                                            context,
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                            ),
                                          ),
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                      ElevatedButton(
                                        onPressed: () => _rejectBid(bidId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[800],
                                          foregroundColor: kWhiteColor,
                                          visualDensity: VisualDensity.compact,
                                          minimumSize: const Size(0, 34),
                                          padding: ResponsiveHelper.padding(
                                            context,
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                            ),
                                          ),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ],
                                  );
                                } else if (bidStatus == 'accepted') {
                                  return Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kAccentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                      border: Border.all(color: kAccentColor),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: kAccentColor,
                                          size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                                        ),
                                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          'Accepted',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                            color: kAccentColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (bidStatus == 'rejected') {
                                  return Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                      border: Border.all(color: Colors.grey[500]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.grey[800],
                                          size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                                        ),
                                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          'Rejected',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                            color: Colors.grey[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // Desktop/Tablet: Horizontal layout
                    return Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                        Flexible(
                          child: Text(
                            _formatDate(createdAt),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        // View Details Button
                        ElevatedButton.icon(
                          onPressed: () => _openBidDetail(bid),
                          icon: Icon(
                            Icons.visibility,
                            size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                          label: const Text('View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccentColor,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 34),
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                              ),
                            ),
                          ),
                        ),
                        // Accept/Reject Bid Buttons
                        Builder(
                          builder: (context) {
                            final bidStatus = bid['status'] as String? ?? 'pending';
                            final canAcceptBid = (widget.vehicle.status == 'active' || 
                                                 widget.vehicle.status == 'live') && 
                                                bidStatus == 'pending' &&
                                                !isWinning;
                            
                            if (canAcceptBid) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                  ElevatedButton(
                                    onPressed: () => _acceptBid(bidId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAccentColor,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      minimumSize: const Size(0, 34),
                                      padding: ResponsiveHelper.padding(
                                        context,
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                        ),
                                      ),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                  ElevatedButton(
                                    onPressed: () => _rejectBid(bidId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[800],
                                      foregroundColor: kWhiteColor,
                                      visualDensity: VisualDensity.compact,
                                      minimumSize: const Size(0, 34),
                                      padding: ResponsiveHelper.padding(
                                        context,
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                        ),
                                      ),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              );
                            } else if (bidStatus == 'accepted') {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                  Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kAccentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                      border: Border.all(color: kAccentColor),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: kAccentColor,
                                          size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                                        ),
                                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          'Accepted',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                            color: kAccentColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            } else if (bidStatus == 'rejected') {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                  Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                      border: Border.all(color: Colors.grey[500]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.grey[800],
                                          size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                                        ),
                                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          'Rejected',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                            color: Colors.grey[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsView() {
    if (_analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Bids',
                  _analytics!['total_bids']?.toString() ?? '0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Unique Bidders',
                  _analytics!['unique_bidders']?.toString() ?? '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Highest Bid',
                  '\$${_analytics!['highest_bid']?.toStringAsFixed(0) ?? '0'}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Average Bid',
                  '\$${_analytics!['average_bid']?.toStringAsFixed(0) ?? '0'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Detailed Stats
          _buildSectionTitle('Bid Statistics'),
          const SizedBox(height: 12),
          _buildDetailRow('Starting Bid', '\$${_analytics!['starting_bid']?.toStringAsFixed(0) ?? '0'}'),
          _buildDetailRow('Lowest Bid', '\$${_analytics!['lowest_bid']?.toStringAsFixed(0) ?? '0'}'),
          _buildDetailRow('Total Bid Amount', '\$${_analytics!['total_bid_amount']?.toStringAsFixed(0) ?? '0'}'),
          const SizedBox(height: 16),
          // Bids by Day (if available)
          if (_analytics!['bids_by_day'] != null)
            Builder(
              builder: (context) {
                final bidsByDay = _analytics!['bids_by_day'];
                
                // Handle both Map and List formats
                if (bidsByDay is Map) {
                  final bidsByDayMap = bidsByDay as Map<String, dynamic>;
                  if (bidsByDayMap.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Bid Activity'),
                        const SizedBox(height: 12),
                        ...bidsByDayMap.entries.map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                  ),
                                  Text(
                                    '${entry.value} bids',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                      ],
                    );
                  }
                } else if (bidsByDay is List) {
                  final bidsByDayList = bidsByDay as List<dynamic>;
                  if (bidsByDayList.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Bid Activity'),
                        const SizedBox(height: 12),
                        ...bidsByDayList.map((item) {
                          final date = item['date']?.toString() ?? item['day']?.toString() ?? 'Unknown';
                          final count = item['count']?.toString() ?? item['bids']?.toString() ?? '0';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  date,
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                ),
                                Text(
                                  '$count bids',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  }
                }
                
                // Return empty widget if bids_by_day is empty or invalid
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Widget _buildTopBidders() {
    if (_analytics == null || _analytics!['top_bidders'] == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final topBidders = _analytics!['top_bidders'] as List<dynamic>;
    if (topBidders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Bidders Yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: topBidders.length,
      itemBuilder: (context, index) {
        final bidder = topBidders[index];
        final name = bidder['user_name'] as String? ?? 'Anonymous';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: kWhiteColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: kAccentColor,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: kWhiteColor, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlackColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Highest: \$${(_toDouble(bidder['highest_bid'])).toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Bids: ${bidder['bid_count'] ?? 0}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showBidderDetails(bidder['user_id'].toString()),
                    style: TextButton.styleFrom(
                      foregroundColor: kAccentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kBlackColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: kBlackColor,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _messageBidder(dynamic bid) async {
    final bidderId = bid['user_id']?.toString() ?? bid['buyer_id']?.toString() ?? (bid['user'] as Map?)?['id']?.toString();
    final bidderName = bid['user_name'] as String? ?? bid['buyer_name'] as String? ?? (bid['user'] as Map?)?['full_name'] as String? ?? 'Bidder';
    
    if (bidderId == null || bidderId.isEmpty) {
      Get.snackbar('Error', 'Bidder information not available');
      return;
    }

    final currentId = await PreferencesHelper.getUserId();
    if (currentId == bidderId) {
      Get.snackbar('Message', 'You cannot message yourself');
      return;
    }

    try {
      // Show loading
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      
      final res = await _chatService.getOrCreateConversation(
        otherUserId: bidderId,
        relatedType: 'vehicle',
        relatedId: int.tryParse(widget.vehicle.id),
      );
      
      Get.back(); // Dismiss loading

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: res['id'].toString(),
            otherUserName: bidderName,
            otherUserId: bidderId,
            currentUserId: currentId,
          ),
        ),
      );
    } catch (e) {
      Get.back(); // Dismiss loading
      Get.snackbar('Error', 'Failed to start chat: ${e.toString()}');
    }
  }

  void _openBidDetail(dynamic bid) {
    // Navigate to bid detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BidDetailScreen(
          bid: bid,
          vehicle: widget.vehicle,
        ),
      ),
    ).then((accepted) {
      // Refresh bids if a bid was accepted
      if (accepted == true) {
        _fetchBids();
        _fetchAnalytics();
      }
    });
  }

  Future<void> _acceptBid(String bidId) async {
    Get.dialog(
      AlertDialog(
        title: const Text('Accept Bid'),
        content: const Text(
          'Are you sure you want to accept this bid?\n\n'
          'This will:\n'
          '• Immediately end the auction\n'
          '• Mark the vehicle as sold\n'
          '• Reject all other bids\n'
          '• Notify the buyer automatically\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              
              // Show loading
              Get.dialog(
                const Center(child: CircularProgressIndicator()),
                barrierDismissible: false,
              );
              
              try {
                final result = await _bidService.acceptBid(bidId);
                Get.back(); // Close loading
                
                Get.snackbar(
                  'Success',
                  result['message'] ?? 'Bid accepted successfully! The auction has ended and the buyer has been notified.',
                  backgroundColor: kBlackColor,
                  colorText: kWhiteColor,
                  duration: const Duration(seconds: 4),
                );
                
                // Refresh bids and vehicle data
                await _fetchBids();
                await _fetchAnalytics();
                
                // Refresh home page data
                try {
                  final homeController = Get.find<HomePageController>();
                  await homeController.fetchCars();
                  await homeController.fetchSellerDashboardData();
                } catch (e) {
                  print('⚠️ HomePageController not found: $e');
                }
              } catch (e) {
                Get.back(); // Close loading
                Get.snackbar(
                  'Error',
                  'Failed to accept bid: ${e.toString()}',
                  backgroundColor: Colors.grey[900],
                  colorText: kWhiteColor,
                  duration: const Duration(seconds: 4),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectBid(String bidId) async {
    Get.dialog(
      AlertDialog(
        title: const Text('Reject Bid'),
        content: const Text(
          'Are you sure you want to reject this bid?\n\n'
          'The bidder will be notified that their bid has been rejected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              
              // Show loading
              Get.dialog(
                const Center(child: CircularProgressIndicator()),
                barrierDismissible: false,
              );
              
              try {
                await _bidService.rejectBid(bidId);
                Get.back(); // Close loading
                
                Get.snackbar(
                  'Success',
                  'Bid rejected successfully!',
                  backgroundColor: kBlackColor,
                  colorText: kWhiteColor,
                  duration: const Duration(seconds: 3),
                );
                
                // Refresh bids
                await _fetchBids();
                await _fetchAnalytics();
              } catch (e) {
                Get.back(); // Close loading
                Get.snackbar(
                  'Error',
                  'Failed to reject bid: ${e.toString()}',
                  backgroundColor: Colors.grey[900],
                  colorText: kWhiteColor,
                  duration: const Duration(seconds: 4),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: kWhiteColor,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // Helper methods for status display (like manage-bids.php)
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return kAccentColor;
      case 'rejected':
        return Colors.grey[800]!;
      case 'pending':
      default:
        return Colors.grey[800]!;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Future<void> _showBidderDetails(String userId) async {
    try {
      final bidderInfo = await _bidService.getBidderInfo(userId);
      Get.dialog(
        AlertDialog(
          title: Text(bidderInfo['name'] ?? 'Bidder Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Email', bidderInfo['email'] ?? 'N/A'),
                _buildDetailRow('Total Bids', bidderInfo['total_bids']?.toString() ?? '0'),
                _buildDetailRow('Winning Bids', bidderInfo['winning_bids']?.toString() ?? '0'),
                _buildDetailRow('Success Rate', '${bidderInfo['success_rate']?.toStringAsFixed(1) ?? '0.0'}%'),
                _buildDetailRow('Average Bid', '\$${bidderInfo['average_bid']?.toStringAsFixed(0) ?? '0'}'),
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
    } catch (e) {
      Get.snackbar('Error', 'Failed to load bidder info: ${e.toString()}');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

