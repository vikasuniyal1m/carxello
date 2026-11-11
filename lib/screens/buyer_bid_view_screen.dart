import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/utils/responsive_helper.dart';

class BuyerBidViewScreen extends StatefulWidget {
  final Car vehicle;

  const BuyerBidViewScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<BuyerBidViewScreen> createState() => _BuyerBidViewScreenState();
}

class _BuyerBidViewScreenState extends State<BuyerBidViewScreen> {
  final BidService _bidService = BidService();

  List<dynamic> _bids = [];
  Map<String, dynamic>? _userBid;
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      
      // Fetch all bids for this vehicle
      final bids = await _bidService.getVehicleBids(widget.vehicle.id);
      
      // Find user's bid
      Map<String, dynamic>? userBid;
      if (_currentUserId != null) {
        userBid = bids.firstWhere(
          (bid) => bid['buyer_id']?.toString() == _currentUserId || 
                   bid['user_id']?.toString() == _currentUserId,
          orElse: () => null,
        );
      }
      
      setState(() {
        _bids = bids;
        _userBid = userBid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Get.snackbar('Error', 'Failed to load bids: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bidding - ${widget.vehicle.year} ${widget.vehicle.make} ${widget.vehicle.model}',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.isMobile(context) ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (_bids.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 64, color: Colors.grey[400]),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'No Bids Yet',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Text(
              'Be the first to place a bid!',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: ResponsiveHelper.padding(context, all: 16),
      children: [
        // User's Bid Section (if exists)
        if (_userBid != null) ...[
          _buildSectionTitle('Your Bid'),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildUserBidCard(_userBid!),
          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
        ],
        
        // All Bids Section
        _buildSectionTitle('All Bids (${_bids.length})'),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        
        // Sort bids by amount (highest first)
        ...(_bids..sort((a, b) {
          final amountA = (a['amount'] is int) 
              ? (a['amount'] as int).toDouble() 
              : (a['amount'] as double? ?? 0.0);
          final amountB = (b['amount'] is int) 
              ? (b['amount'] as int).toDouble() 
              : (b['amount'] as double? ?? 0.0);
          return amountB.compareTo(amountA);
        })).map((bid) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
          child: _buildBidCard(bid),
        )).toList(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: ResponsiveHelper.textStyle(
        context,
        fontSize: ResponsiveHelper.isMobile(context) ? 18 : 20,
        fontWeight: FontWeight.bold,
        color: kBlackColor,
      ),
    );
  }

  Widget _buildUserBidCard(Map<String, dynamic> bid) {
    final bidAmount = (bid['amount'] is int) 
        ? (bid['amount'] as int).toDouble() 
        : (bid['amount'] as double? ?? 0.0);
    final isWinning = bid['is_winning_bid'] as bool? ?? false;
    final createdAt = bid['created_at'] as String? ?? bid['bid_time'] as String? ?? '';

    return Container(
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: isWinning ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinning ? Colors.green : Colors.blue,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWinning ? Icons.emoji_events : Icons.person,
                color: isWinning ? Colors.green : Colors.blue,
                size: ResponsiveHelper.iconSize(context, mobile: 24),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWinning ? 'You are Winning!' : 'Your Bid',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.isMobile(context) ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: isWinning ? Colors.green.shade900 : Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      '\$${bidAmount.toStringAsFixed(0)}',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.isMobile(context) ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: isWinning ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isWinning)
                Container(
                  padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'WINNING',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: ResponsiveHelper.iconSize(context, mobile: 16),
                color: Colors.grey[600],
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 4)),
              Text(
                _formatDate(createdAt),
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBidCard(Map<String, dynamic> bid) {
    final bidAmount = (bid['amount'] is int) 
        ? (bid['amount'] as int).toDouble() 
        : (bid['amount'] as double? ?? 0.0);
    final isWinning = bid['is_winning_bid'] as bool? ?? false;
    final isUserBid = _currentUserId != null && 
        (bid['buyer_id']?.toString() == _currentUserId || 
         bid['user_id']?.toString() == _currentUserId);
    
    // Don't show user's bid again in all bids if already shown
    if (isUserBid && _userBid != null) {
      return const SizedBox.shrink();
    }
    
    final userName = bid['user_name'] as String? ?? 
                    bid['buyer_name'] as String? ?? 
                    bid['name'] as String? ?? 
                    'Anonymous Bidder';
    final createdAt = bid['created_at'] as String? ?? bid['bid_time'] as String? ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isWinning 
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: ResponsiveHelper.padding(context, all: 16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: isWinning ? Colors.green : Colors.blue,
              radius: ResponsiveHelper.isMobile(context) ? 24 : 28,
              child: Text(
                userName[0].toUpperCase(),
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.isMobile(context) ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            // Bid Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.isMobile(context) ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isWinning)
                        Container(
                          padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'Winning',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    '\$${bidAmount.toStringAsFixed(0)}',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.isMobile(context) ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: isWinning ? Colors.green : kBlackColor,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: ResponsiveHelper.iconSize(context, mobile: 14),
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        _formatDate(createdAt),
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

