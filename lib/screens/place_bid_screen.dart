import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/onboarding_screen.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';

class PlaceBidScreen extends StatefulWidget {
  final Car car;

  const PlaceBidScreen({
    super.key,
    required this.car,
  });

  @override
  State<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends State<PlaceBidScreen> with SingleTickerProviderStateMixin {
  final _bidAmountController = TextEditingController();
  final _maxBidController = TextEditingController();
  final _bidAmountFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final BidService _bidService = BidService();
  Timer? _timer;

  double _minimumBid = 0;
  double _currentHighestBid = 0;
  bool _isLoadingBidInfo = true;
  double _minBidIncrement = 100.0;
  bool _isSubmittingBid = false;

  @override
  void initState() {
    super.initState();
    final effectiveBid = widget.car.currentBid ?? widget.car.startingBid;
    _currentHighestBid = effectiveBid;
    _minimumBid = effectiveBid + 100.0;
    _minBidIncrement = 100.0;
    _bidAmountController.text = _minimumBid.toStringAsFixed(0);
    _isLoadingBidInfo = false;
    _bidAmountFocusNode.addListener(_onBidAmountFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlaceBidInfo());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _onBidAmountFocusChange() {
    if (_bidAmountFocusNode.hasFocus) return;
    final v = double.tryParse(_bidAmountController.text);
    if (v != null && v < _minimumBid && _minimumBid > 0) {
      _bidAmountController.text = _minimumBid.toStringAsFixed(0);
      setState(() {});
    }
  }

  /// Load place-bid info for all users (buyer & seller): minimum_bid, and user's last bid for pre-fill.
  Future<void> _loadPlaceBidInfo() async {
    if (!mounted) return;
    setState(() => _isLoadingBidInfo = true);
    try {
      final info = await _bidService.getPlaceBidInfo(widget.car.id);
      final minimumBid = (info['minimum_bid'] as num?)?.toDouble() ?? 0.0;
      final currentHighest = (info['current_highest_bid'] as num?)?.toDouble() ?? 0.0;
      final increment = (info['min_bid_increment'] as num?)?.toDouble() ?? 100.0;
      final myBidAmount = (info['my_bid_amount'] as num?)?.toDouble();

      if (!mounted) return;
      setState(() {
        _minimumBid = minimumBid;
        _currentHighestBid = currentHighest;
        _minBidIncrement = increment;
        _isLoadingBidInfo = false;
        // Pre-fill: user's last bid if >= minimum (update flow), else minimum
        final prefill = (myBidAmount != null && myBidAmount >= minimumBid)
            ? myBidAmount
            : minimumBid;
        _bidAmountController.text = prefill.toStringAsFixed(0);
      });
    } catch (e) {
      print('⚠️ Error loading place-bid info: $e');
      if (!mounted) return;
      final effectiveBid = widget.car.currentBid ?? widget.car.startingBid;
      setState(() {
        _currentHighestBid = effectiveBid;
        _minBidIncrement = 100.0;
        _minimumBid = effectiveBid + 100.0;
        _bidAmountController.text = _minimumBid.toStringAsFixed(0);
        _isLoadingBidInfo = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bidAmountFocusNode.removeListener(_onBidAmountFocusChange);
    _bidAmountFocusNode.dispose();
    _bidAmountController.dispose();
    _maxBidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: kWhiteColor,
      enableScroll: true,
      appBar: AppBar(
        toolbarHeight: ResponsiveHelper.appBarHeight(context),
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Place Bid',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: ResponsiveHelper.safePadding(
            context,
            horizontal: 16,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back to Vehicle Details Link
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
                ),
                label: Text(
                  'Back to Vehicle Details',
                  style: ResponsiveHelper.bodyStyle(context).copyWith(
                    color: kAccentColor,
                  ),
                ),
              ),
              ResponsiveHelper.sizedBoxHeight(context, 16),
              
              // Vehicle Information Card
              _buildVehicleInfoCard(),
              ResponsiveHelper.sizedBoxHeight(context, 24),
              
              // Bid Amount Section
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBidAmountSection(),
                    ResponsiveHelper.sizedBoxHeight(context, 24),
                    
                    // Maximum Bid Section
                    _buildMaxBidSection(),
                    ResponsiveHelper.sizedBoxHeight(context, 24),
                    
                    // Bidding Information
                    _buildBiddingInformation(),
                    ResponsiveHelper.sizedBoxHeight(context, 16),
                    
                    // Important Notes
                    _buildImportantNotes(),
                    ResponsiveHelper.sizedBoxHeight(context, 32),
                    
                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard() {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAccentColor,
            kThemeColor2,
          ],
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20),
        ),
      ),
      child: Column(
        children: [
          // Vehicle Name
          Text(
            '${widget.car.year} ${widget.car.make} ${widget.car.model}',
            style: TextStyle(
              fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                  ? ResponsiveHelper.adaptiveTitleSize(context)
                  : ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          ResponsiveHelper.sizedBoxHeight(context, 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Current Bid
              Column(
                children: [
                  Text(
                    'Current Bid',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                          ? ResponsiveHelper.adaptiveBodySize(context)
                          : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      color: Colors.white70,
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 4),
                  _isLoadingBidInfo
                      ? SizedBox(
                          width: ResponsiveHelper.progressIndicatorSize(context) * 0.5,
                          height: ResponsiveHelper.progressIndicatorSize(context) * 0.5,
                          child: CircularProgressIndicator(
                            strokeWidth: ResponsiveHelper.dividerThickness(context) * 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '\$${_currentHighestBid.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                                ? ResponsiveHelper.adaptiveTitleSize(context) * 0.9
                                : ResponsiveHelper.fontSize(context, mobile: 24, tablet: 26, desktop: 28),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ],
              ),
              
              // Time Left
              Column(
                children: [
                  Text(
                    'Time Left',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                          ? ResponsiveHelper.adaptiveBodySize(context)
                          : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      color: Colors.white70,
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 4),
                  Container(
                    padding: ResponsiveHelper.padding(
                      context,
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 22, desktop: 24),
                      ),
                    ),
                    child: Text(
                      _formatTimeLeft(),
                      style: TextStyle(
                        fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                            ? ResponsiveHelper.adaptiveBodySize(context)
                            : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBidAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _isLoadingBidInfo
                ? Text(
                    'Loading bid information...',
                    style: ResponsiveHelper.subheadingStyle(context).copyWith(
                      color: kBlackColor,
                    ),
                  )
                : Flexible(
                    child: Text(
                      'Bid amount',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                            ? ResponsiveHelper.adaptiveSubtitleSize(context)
                            : ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.w600,
                        color: kBlackColor,
                      ),
                    ),
                  ),
            _isLoadingBidInfo
                ? const SizedBox.shrink()
                : Text(
                    'Min: \$${_minimumBid.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                          ? ResponsiveHelper.adaptiveBodySize(context)
                          : ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
          ],
        ),
        ResponsiveHelper.sizedBoxHeight(context, 8),
        TextFormField(
          controller: _bidAmountController,
          focusNode: _bidAmountFocusNode,
          keyboardType: TextInputType.number,
          enabled: !_isLoadingBidInfo,
          style: ResponsiveHelper.bodyStyle(context),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: ResponsiveHelper.bodyStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
            hintText: 'Enter amount (min \$${_minimumBid.toStringAsFixed(0)})',
            contentPadding: ResponsiveHelper.padding(
              context,
              horizontal: 16,
              vertical: ResponsiveHelper.textFieldHeight(context) * 0.25,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: kAccentColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your bid amount';
            }
            final bidAmount = double.tryParse(value);
            if (bidAmount == null) {
              return 'Please enter a valid amount';
            }
            if (bidAmount < _minimumBid) {
              return 'Your bid must be at least \$${_minimumBid.toStringAsFixed(0)} (minimum for this auction)';
            }
            return null;
          },
        ),
        if (!_isLoadingBidInfo && _minimumBid > 0) ...[
          ResponsiveHelper.sizedBoxHeight(context, 6),
          Text(
            'Enter your bid in dollars. You cannot bid below \$${_minimumBid.toStringAsFixed(0)}.',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMaxBidSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
          'Maximum Bid (Optional - Auto-bid)',
          style: TextStyle(
            fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                ? ResponsiveHelper.adaptiveSubtitleSize(context)
                : ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
            fontWeight: FontWeight.w600,
            color: kBlackColor,
          ),
        ),
        ResponsiveHelper.sizedBoxHeight(context, 8),
        TextFormField(
          controller: _maxBidController,
          keyboardType: TextInputType.number,
          style: ResponsiveHelper.bodyStyle(context),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: ResponsiveHelper.bodyStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
            hintText: 'Auto-bid up to this amount',
            contentPadding: ResponsiveHelper.padding(
              context,
              horizontal: 16,
              vertical: ResponsiveHelper.textFieldHeight(context) * 0.25,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: kAccentColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final maxBid = double.tryParse(value);
              final bidAmount = double.tryParse(_bidAmountController.text);
              if (maxBid != null && bidAmount != null && maxBid < bidAmount) {
                return 'Maximum bid must be greater than or equal to bid amount';
              }
            }
            return null;
          },
        ),
        ResponsiveHelper.sizedBoxHeight(context, 8),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20),
              color: kAccentColor,
            ),
            ResponsiveHelper.sizedBoxWidth(context, 8),
            Expanded(
              child: Text(
                'We\'ll automatically bid for you up to this amount',
                style: TextStyle(
                  fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                      ? ResponsiveHelper.adaptiveBodySize(context)
                      : ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                  color: kAccentColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiddingInformation() {
    return Container(
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: kAccentColor.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.build,
            color: kAccentColor,
            size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          ResponsiveHelper.sizedBoxWidth(context, 12),
          Expanded(
            child: Text(
              'All bids are binding. By placing a bid, you agree to purchase the vehicle if you win.',
              style: TextStyle(
                fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                    ? ResponsiveHelper.adaptiveBodySize(context)
                    : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotes() {
    return Container(
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
              ),
              ResponsiveHelper.sizedBoxWidth(context, 8),
              Text(
                'Important Notes',
                style: TextStyle(
                  fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                      ? ResponsiveHelper.adaptiveSubtitleSize(context)
                      : ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.w600,
                  color: kBlackColor,
                ),
              ),
            ],
          ),
          ResponsiveHelper.sizedBoxHeight(context, 12),
          _buildNoteItem('Winning bidders must complete payment within 24 hours.'),
          ResponsiveHelper.sizedBoxHeight(context, 8),
          _buildNoteItem('Additional fees may apply for transportation and documentation.'),
          ResponsiveHelper.sizedBoxHeight(context, 8),
          _buildNoteItem('Vehicle is sold "as-is" unless otherwise specified.'),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: ResponsiveHelper.safeMargin(
            context,
            top: 6,
            right: 8,
          ),
          width: ResponsiveHelper.spacing(context, 6),
          height: ResponsiveHelper.spacing(context, 6),
          decoration: BoxDecoration(
            color: Colors.orange[700],
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                  ? ResponsiveHelper.adaptiveBodySize(context)
                  : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                  ? ResponsiveHelper.adaptiveButtonPadding(context)
                  : ResponsiveHelper.padding(
                      context,
                      vertical: ResponsiveHelper.buttonHeight(context) * 0.3,
                    ),
              side: BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
                ),
              ),
              minimumSize: Size(
                0,
                ResponsiveHelper.buttonHeight(context),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                    ? ResponsiveHelper.adaptiveButtonTextSize(context)
                    : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                fontWeight: FontWeight.w600,
                color: kBlackColor,
              ),
            ),
          ),
        ),
        ResponsiveHelper.sizedBoxWidth(context, 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSubmittingBid
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      _handlePlaceBid();
                    }
                  },
            icon: _isSubmittingBid
                ? SizedBox(
                    width: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                    height: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.gavel,
                    color: Colors.white,
                    size: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                        ? ResponsiveHelper.adaptiveIconSize(context)
                        : ResponsiveHelper.iconSize(context),
                  ),
            label: Text(
              _isSubmittingBid ? 'Placing bid...' : 'Place Bid',
              style: TextStyle(
                fontSize: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                    ? ResponsiveHelper.adaptiveButtonTextSize(context)
                    : ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              padding: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context)
                  ? ResponsiveHelper.adaptiveButtonPadding(context)
                  : ResponsiveHelper.padding(
                      context,
                      vertical: ResponsiveHelper.buttonHeight(context) * 0.3,
                    ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
                ),
              ),
              minimumSize: Size(
                0,
                ResponsiveHelper.buttonHeight(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeLeft() {
    final difference = widget.car.auctionEndTime.difference(DateTime.now());
    if (difference.isNegative) {
      return 'Ended';
    }
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;
    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }

  Future<void> _handlePlaceBid() async {
    final bidAmount = double.tryParse(_bidAmountController.text);
    final maxBid = _maxBidController.text.isNotEmpty 
        ? double.tryParse(_maxBidController.text) 
        : null;

    if (bidAmount == null) {
      print('❌ ERROR: Please enter a valid bid amount');
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmittingBid = true);

    try {
      final bidService = BidService();
      await bidService.placeBid(widget.car.id, bidAmount, maxBid: maxBid);
      
      if (mounted) {
        print('✅ Bid placed successfully!');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        print('❌ BID ERROR: ${e.toString()}');
        String msg = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Failed to place bid: ', '')
            .trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isEmpty ? 'Failed to place bid' : msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingBid = false);
    }
  }
}

