import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/image_helper.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/models/car.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carauction/screens/place_bid_screen.dart';
import 'package:carauction/screens/buy_now_screen.dart';
import 'package:carauction/screens/swap_purchase_screen.dart';
import 'package:carauction/screens/swap_offer_status_screen.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/services/swap_offer_service.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carauction/services/user_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/services/nhtsa_service.dart';
import 'package:carauction/services/valuation_service.dart';
import 'package:carauction/screens/chat_screen.dart';
import 'package:carauction/screens/seller_bid_management_screen.dart';
import 'package:carauction/screens/buyer_bid_view_screen.dart';
import 'package:carauction/screens/transport_tracking_screen.dart';
import 'package:carauction/screens/vehicle_shipping_screen.dart';
import 'package:carauction/screens/seller_inspection_request_screen.dart';
import 'package:carauction/screens/buyer_inspection_status_screen.dart';
import 'package:carauction/screens/view_report_screen.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/controllers/watchlist_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/home_page_controller.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Car car;

  const ProductDetailsScreen({super.key, required this.car});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _selectedTab = 0;
  int _currentImageIndex = 0;
  bool _isActionButtonsExpanded = true;

  bool _isSmallMediumTablet(BuildContext context) {
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final screenHeight = ResponsiveHelper.screenHeight(context);
    return (screenWidth >= 780 && screenWidth <= 850) &&
        (screenHeight >= 1080 && screenHeight <= 1300);
  }

  bool _isMediumTablet(BuildContext context) {
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final screenHeight = ResponsiveHelper.screenHeight(context);
    return (screenWidth >= 1010 && screenWidth <= 1050) &&
        (screenHeight >= 1330 && screenHeight <= 1570);
  }

  bool _isLargeTablet(BuildContext context) {
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final screenHeight = ResponsiveHelper.screenHeight(context);
    return (screenWidth >= 1200 && screenWidth <= 1650) &&
        (screenHeight >= 1350 && screenHeight <= 1900);
  }

  bool _isTabletOrIPad(BuildContext context) {
    return _isSmallMediumTablet(context) ||
        _isMediumTablet(context) ||
        _isLargeTablet(context) ||
        ResponsiveHelper.isTabletOrIPad(context);
  }

  double get _actualListPrice {
    final p = widget.car.price ?? widget.car.buyNowPrice;
    if (p != null && p > 0) return p;
    return widget.car.startingBid;
  }

  String _getDisplayPriceText() {
    final price = _actualListPrice;
    if (price <= 0) return 'Contact for price';
    return '\$${price.toStringAsFixed(0)}';
  }

  String _getPriceLabelText() {
    final hasListPrice = (widget.car.price ?? widget.car.buyNowPrice) != null &&
        (widget.car.price ?? widget.car.buyNowPrice)! > 0;
    if (hasListPrice) return 'Price';
    if (widget.car.hasAuction == true && widget.car.startingBid > 0) {
      return 'Starting bid \$${widget.car.startingBid.toStringAsFixed(0)}';
    }
    return 'Price';
  }

  final CarouselSliderController _carouselController = CarouselSliderController();
  List<String> _carImages = [];
  bool _isLoadingPhotos = true;

  Timer? _countdownTimer;
  String _timeRemaining = '';

  final BidService _bidService = BidService();
  final SwapOfferService _swapOfferService = SwapOfferService();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final CarService _carService = CarService();
  final InspectionService _inspectionService = InspectionService();
  final ValuationService _valuationService = ValuationService();

  // ============ BID/BUY NOW/SWAP STATUS ============
  bool _hasBuyNowBid = false;
  bool _isLoadingBidStatus = true;
  Map<String, dynamic>? _currentBid;
  Map<String, dynamic>? _pendingBuyNowBid;
  bool _hasRegularBid = false;
  bool _hasSwapOffer = false;
  bool _isCurrentUserSeller = false;
  String? _currentUserId;
  bool _isInWatchlist = false;
  late final WatchlistController _watchlistController;
  bool _hasTransporterAssigned = false;
  bool _hasTransportRequested = false;
  bool _isCheckingTransporter = false;
  bool _isPurchasedByCurrentUser = false;
  String? _refetchedStatus;
  bool _hasRefreshedStatus = false;
  Map<String, dynamic>? _inspectionInfo;
  bool _isLoadingInspection = false;
  bool _isExpanded = false;
  int _expandedSection = 0;

  // ============ ADD THESE NEW VARIABLES ============
  List<Map<String, dynamic>> _recentBids = [];  // Store recent bids for this vehicle
  double? _highestBid;
  int _bidCount = 0;
  Map<String, dynamic>? _winningBidInfo;

  final GlobalKey _listingSectionKey = GlobalKey();
  final GlobalKey _placeBidSectionKey = GlobalKey();
  final GlobalKey _purchasedSectionKey = GlobalKey();
  final GlobalKey _distanceCalculatorSectionKey = GlobalKey();
  final GlobalKey _tabContentKey = GlobalKey();
  final ScrollController _detailsScrollController = ScrollController();

  final TextEditingController _yourLocationZipController = TextEditingController();
  double? _calculatedDistance;
  bool _isCalculatingDistance = false;
  String? _savedDistance;

  double? _marketValuation;
  double? _tradeInValue;
  double? _recommendedPrice;
  bool _isLoadingValuation = false;

  String? _loadingButtonKey;

  final NHTSAService _nhtsaService = NHTSAService();
  Map<String, dynamic>? _vinDecodeData;
  Map<String, dynamic>? _vinSafetyData;
  List<dynamic>? _vinRecallsData;
  bool _isLoadingVinDecode = false;
  bool _vinDecodeLoaded = false;

  @override
  void initState() {
    super.initState();
    try {
      _watchlistController = Get.find<WatchlistController>();
    } catch (e) {
      _watchlistController = Get.put(WatchlistController(), permanent: true);
    }

    _loadVehiclePhotos();
    _checkIfSeller();
    _checkBidStatus();
    _checkWatchlistStatus();
    _checkTransporterStatus();
    _checkIfPurchasedByUser();
    _refreshVehicleStatus();
    _checkInspectionInfo();
    _loadMarketValuation();
    _loadUserZipForDistance();
    _startCountdownTimer();
    _updateTimeRemaining();

    // ============ FETCH RECENT BIDS ============
    _fetchRecentBids();
  }

  // ============ FETCH RECENT BIDS FOR THIS VEHICLE ============
  Future<void> _fetchRecentBids() async {
    try {
      final bids = await _bidService.getVehicleBids(widget.car.id);
      if (mounted) {
        setState(() {
          _recentBids = List<Map<String, dynamic>>.from(bids);
          _bidCount = _recentBids.length;

          // Find highest bid
          if (_recentBids.isNotEmpty) {
            _highestBid = _recentBids.map((b) =>
            (b['bid_amount'] is int)
                ? (b['bid_amount'] as int).toDouble()
                : (b['bid_amount'] as double? ?? 0.0)
            ).reduce((a, b) => a > b ? a : b);

            // Find winning bid (highest bid)
            _winningBidInfo = _recentBids.firstWhere(
                  (b) {
                final amount = (b['bid_amount'] is int)
                    ? (b['bid_amount'] as int).toDouble()
                    : (b['bid_amount'] as double? ?? 0.0);
                return amount == _highestBid;
              },
              orElse: () => <String, dynamic>{},
            );
          }
        });
      }
    } catch (e) {
      print('⚠️ Error fetching recent bids: $e');
    }
  }

  Future<void> _loadUserZipForDistance() async {
    try {
      final profile = await _userService.getUserProfile();
      if (!mounted) return;
      final zip = profile['zip_code']?.toString().trim();
      if (zip != null && zip.isNotEmpty) {
        _yourLocationZipController.text = zip;
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkInspectionInfo();
      }
    });
  }

  Future<void> _loadMarketValuation() async {
    setState(() {
      _isLoadingValuation = true;
    });

    try {
      final result = await _valuationService.getValuation(
        vehicleId: widget.car.id,
        vin: widget.car.vin,
        make: widget.car.make,
        model: widget.car.model,
        year: widget.car.year,
        mileage: widget.car.mileage,
      );

      if (mounted) {
        setState(() {
          _marketValuation = (result['average']?['retail'] as num?)?.toDouble();
          _tradeInValue = (result['internal']?['trade_in'] as num?)?.toDouble() ?? 
                            (result['average']?['trade_in'] as num?)?.toDouble();
          _recommendedPrice = (result['recommended_price'] as num?)?.toDouble();
          _isLoadingValuation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingValuation = false;
        });
      }
      print('⚠️ Error loading market valuation: $e');
    }
  }

  Future<void> _calculateDistance() async {
    if (_yourLocationZipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your ZIP code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String originalLocation = widget.car.location.trim();
    print('📍 Original vehicle location: "$originalLocation"');

    String vehicleZip = originalLocation;

    if (vehicleZip.isEmpty) {
      print('⚠️ Vehicle location is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle location ZIP code is not available. Please contact the seller.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (vehicleZip.contains(',')) {
      vehicleZip = vehicleZip.split(',').last.trim();
      print('📍 After comma split: "$vehicleZip"');
    }

    String digitsOnly = vehicleZip.replaceAll(RegExp(r'[^0-9]'), '');
    print('📍 Extracted digits: "$digitsOnly"');

    if (digitsOnly.isNotEmpty) {
      vehicleZip = digitsOnly;
    } else {
      vehicleZip = '';
    }

    print('📍 Final extracted ZIP code: "$vehicleZip"');

    if (vehicleZip.isEmpty || vehicleZip.length < 5) {
      print('⚠️ Invalid ZIP code extracted: "$vehicleZip"');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle location ZIP code is invalid. Please contact the seller.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isCalculatingDistance = true;
      _calculatedDistance = null;
    });

    try {
      final result = await _carService.calculateDistance(
        vehicleZip,
        _yourLocationZipController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _calculatedDistance = (result['distance'] as num?)?.toDouble();
          _isCalculatingDistance = false;
        });

        if (_calculatedDistance != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Distance calculated: ${_calculatedDistance!.toStringAsFixed(1)} miles'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalculatingDistance = false;
        });

        String errorMessage = 'Failed to calculate distance';
        String errorString = e.toString();

        if (errorString.contains('Vehicle location ZIP code not found')) {
          errorMessage = 'Vehicle location ZIP code not found in database. Please contact the seller.';
        } else if (errorString.contains('Your location ZIP code not found')) {
          errorMessage = 'The ZIP code you entered is not found. Please check and try again.';
        } else if (errorString.contains('ZIP code')) {
          errorMessage = errorString;
        } else {
          errorMessage = 'Failed to calculate distance. Please try again later.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      print('⚠️ Error calculating distance: $e');
    }
  }

  void _saveDistance() {
    if (_calculatedDistance != null) {
      setState(() {
        _savedDistance = _calculatedDistance!.toStringAsFixed(1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Distance saved: $_savedDistance miles'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _yourLocationZipController.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _scrollToExpandedSection(int section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? ctx = section == 1
          ? _listingSectionKey.currentContext
          : section == 4
          ? _purchasedSectionKey.currentContext
          : _placeBidSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      }
    });
  }

  void _scrollToDistanceCalculator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        final ctx = _distanceCalculatorSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  void _scrollToTabContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _tabContentKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      }
    });
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeRemaining();
        });
      }
    });
  }

  void _updateTimeRemaining() {
    final difference = widget.car.auctionEndTime.difference(DateTime.now());
    if (difference.isNegative) {
      _timeRemaining = 'Auction Ended';
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;

      if (days > 0) {
        _timeRemaining = '${days}d ${hours}h ${minutes}m ${seconds}s';
      } else if (hours > 0) {
        _timeRemaining = '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        _timeRemaining = '${minutes}m ${seconds}s';
      } else {
        _timeRemaining = '${seconds}s';
      }
    }
  }

  Future<void> _loadVehiclePhotos() async {
    try {
      setState(() {
        _isLoadingPhotos = true;
      });

      print('📸 ProductDetails: Loading photos for vehicle: ${widget.car.id}');
      print('   Main image URL: ${widget.car.imageUrl}');

      final carJson = widget.car.toJson();
      if (carJson.containsKey('photos') && carJson['photos'] != null) {
        final photos = carJson['photos'] as List<dynamic>?;
        print('   Found ${photos?.length ?? 0} photos in car object');
        if (photos != null && photos.isNotEmpty) {
          _carImages = photos.map((photo) {
            if (photo is Map) {
              final photoUrl = photo['photo_url'] as String? ??
                  photo['photoUrl'] as String? ??
                  photo['url'] as String? ??
                  widget.car.imageUrl;
              print('   Photo URL: $photoUrl');
              return _normalizeImageUrl(photoUrl);
            }
            return _normalizeImageUrl(photo.toString());
          }).toList();
        } else {
          print('   No photos in car object, using main image');
          _carImages = [_normalizeImageUrl(widget.car.imageUrl)];
        }
      } else {
        print('   Photos not in car object, fetching from API...');
        try {
          final photos = await _carService.getVehiclePhotos(widget.car.id);
          print('   API returned ${photos.length} photos');
          if (photos.isNotEmpty) {
            _carImages = photos
                .map(
                  (photo) {
                final photoUrl = photo['photo_url'] as String? ??
                    photo['photoUrl'] as String? ??
                    photo['url'] as String? ??
                    widget.car.imageUrl;
                print('   API Photo URL: $photoUrl');
                return _normalizeImageUrl(photoUrl);
              },
            )
                .toList();
          } else {
            print('   No photos from API, using main image');
            _carImages = [_normalizeImageUrl(widget.car.imageUrl)];
          }
        } catch (e) {
          print('⚠️ Error fetching photos from API: $e');
          _carImages = [_normalizeImageUrl(widget.car.imageUrl)];
        }
      }

      if (_carImages.isEmpty) {
        print('   No images found, using main image as fallback');
        _carImages = [_normalizeImageUrl(widget.car.imageUrl)];
      }

      print('✅ ProductDetails: Loaded ${_carImages.length} images');
      for (int i = 0; i < _carImages.length; i++) {
        print('   Image $i: ${_carImages[i]}');
      }

      setState(() {
        _isLoadingPhotos = false;
      });
    } catch (e) {
      print('⚠️ Error loading vehicle photos: $e');
      developer.log('Error loading vehicle photos', error: e, stackTrace: StackTrace.current);
      _carImages = [_normalizeImageUrl(widget.car.imageUrl)];
      setState(() {
        _isLoadingPhotos = false;
      });
    }
  }

  String _normalizeImageUrl(String url) {
    return ImageHelper.normalizeImageUrl(url);
  }

  void _showFullScreenImages(int initialIndex) {
    if (_carImages.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: _carImages.length,
              controller: PageController(initialPage: initialIndex.clamp(0, _carImages.length - 1)),
              itemBuilder: (context, index) {
                final url = _carImages[index];
                final isNetwork = url.startsWith('http://') || url.startsWith('https://');
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: isNetwork
                        ? Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, size: 64, color: Colors.red);
                      },
                    )
                        : Image.asset(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, size: 64, color: Colors.red);
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${initialIndex.clamp(0, _carImages.length - 1) + 1} / ${_carImages.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkIfSeller() async {
    try {
      final userProfile = await _userService.getUserProfile();
      _currentUserId = userProfile['id']?.toString();

      final sellerIdStr = widget.car.sellerId?.toString().trim();
      if (_currentUserId != null && sellerIdStr != null && sellerIdStr.isNotEmpty) {
        _isCurrentUserSeller = _currentUserId == sellerIdStr;
        print(
          '👤 Current User ID: $_currentUserId, Seller ID: $sellerIdStr, Is Seller: $_isCurrentUserSeller',
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        final storedUserId = prefs.getString('user_id');
        if (storedUserId != null && sellerIdStr != null && sellerIdStr.isNotEmpty) {
          _isCurrentUserSeller = storedUserId.trim() == sellerIdStr;
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Error checking if seller: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedUserId = prefs.getString('user_id');
        final sellerIdStr = widget.car.sellerId?.toString().trim();
        if (storedUserId != null && sellerIdStr != null && sellerIdStr.isNotEmpty) {
          _isCurrentUserSeller = storedUserId.trim() == sellerIdStr;
          if (mounted) setState(() {});
        }
      } catch (e2) {
        print('⚠️ Error in fallback seller check: $e2');
      }
    }
  }

  Future<void> _checkWatchlistStatus() async {
    try {
      await _watchlistController.checkWatchlistStatus(widget.car.id);
      if (mounted) {
        setState(() {
          _isInWatchlist = _watchlistController.isWatched(widget.car.id);
        });
      }
    } catch (e) {
      print('⚠️ Error checking watchlist status: $e');
    }
  }

  Future<void> _shareListing() async {
    try {
      final title = '${widget.car.year} ${widget.car.make} ${widget.car.model}';
      final text = 'Check out this vehicle: $title • ${widget.car.mileage} mi • \$${widget.car.startingBid.toStringAsFixed(0)} starting bid.';
      await Share.share(
        text,
        subject: title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _checkTransporterStatus() async {
    if (_isVehicleCompleted || _hasBuyNowBid) {
      try {
        setState(() {
          _isCheckingTransporter = true;
        });

        final transportService = TransportService();
        try {
          final transportOrderResponse = await transportService.getTransportOrder(widget.car.id);
          final orderData = transportOrderResponse['order'] as Map<String, dynamic>? ?? transportOrderResponse;

          if (mounted) {
            setState(() {
              _hasTransportRequested = orderData != null && orderData['id'] != null;
              _hasTransporterAssigned = orderData != null &&
                  orderData['transporter_id'] != null &&
                  orderData['date_approved_by_admin'] == true &&
                  orderData['date_approved_by_customer'] == true;
              _isCheckingTransporter = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _hasTransportRequested = false;
              _hasTransporterAssigned = false;
              _isCheckingTransporter = false;
            });
          }
        }
      } catch (e) {
        print('⚠️ Error checking transporter status: $e');
        if (mounted) {
          setState(() {
            _hasTransportRequested = false;
            _hasTransporterAssigned = false;
            _isCheckingTransporter = false;
          });
        }
      }
    }
  }

  Future<void> _checkInspectionInfo() async {
    try {
      print('🔍 _checkInspectionInfo - Starting check for vehicle: ${widget.car.id}');
      setState(() {
        _isLoadingInspection = true;
      });

      final result = await _inspectionService.getVehicleInspection(widget.car.id.toString());

      print('📋 _checkInspectionInfo - Full API result: $result');
      print('📋 _checkInspectionInfo - has_inspection: ${result['has_inspection']}');
      print('📋 _checkInspectionInfo - inspection: ${result['inspection']}');

      if (mounted) {
        setState(() {
          if (result['has_inspection'] == true && result['inspection'] != null) {
            _inspectionInfo = result['inspection'] as Map<String, dynamic>;
            print('✅ _checkInspectionInfo - Inspection found!');
            print('✅ _checkInspectionInfo - Status: ${_inspectionInfo!['status']}');
            print('✅ _checkInspectionInfo - ID: ${_inspectionInfo!['id']}');
          } else {
            _inspectionInfo = null;
            print('ℹ️ _checkInspectionInfo - No inspection found');
          }
          _isLoadingInspection = false;
        });
      }
    } catch (e) {
      print('⚠️ Error checking inspection info: $e');
      if (mounted) {
        setState(() {
          _inspectionInfo = null;
          _isLoadingInspection = false;
        });
      }
    }
  }

  // ============ CHECK BID STATUS - UPDATED ============
  Future<void> _checkBidStatus() async {
    try {
      final hasBuyNow = await _bidService.hasBuyNowBid(widget.car.id);
      final currentBid = await _bidService.getCurrentBid(widget.car.id);
      final pendingBuyNow = await _bidService.getPendingBuyNowBid(widget.car.id);

      bool hasSwap = false;
      try {
        hasSwap = await _swapOfferService.hasSwapOffer(widget.car.id);
      } catch (e) {
        hasSwap = widget.car.swapOfferStatus != null &&
            widget.car.swapOfferStatus!.isNotEmpty &&
            widget.car.swapOfferStatus != 'none';
      }

      if (mounted) {
        setState(() {
          _hasBuyNowBid = hasBuyNow;
          _currentBid = currentBid;
          _pendingBuyNowBid = pendingBuyNow;
          _hasRegularBid = currentBid != null;
          _hasSwapOffer = hasSwap;
          _isLoadingBidStatus = false;

          // Auto-expand if user has bid
          if (currentBid != null && !hasBuyNow && _expandedSection != 2) {
            _expandedSection = 2;
          }
        });

        // Fetch recent bids again to update bid list
        _fetchRecentBids();
      }
    } catch (e) {
      print('⚠️ Error checking bid status: $e');
      if (mounted) {
        setState(() {
          _isLoadingBidStatus = false;
        });
      }
    }
  }

  String get _effectiveStatus => _refetchedStatus ?? widget.car.status ?? '';

  // ============ IS VEHICLE COMPLETED (SOLD/WON) ============
  bool get _isVehicleCompleted {
    if (_effectiveStatus == 'sold' || _effectiveStatus == 'won') {
      return true;
    }
    if (widget.car.wonAmount != null) {
      return true;
    }
    if (_isPurchasedByCurrentUser) {
      return true;
    }
    if (_hasBuyNowBid) { // If user placed Buy Now bid, consider completed
      return true;
    }
    return false;
  }

  Future<void> _refreshVehicleStatus() async {
    try {
      final car = await _carService.getVehicleById(widget.car.id.toString());
      if (!mounted) return;
      setState(() {
        _hasRefreshedStatus = true;
        if (car != null && (car.status == 'sold' || car.status == 'won')) {
          _refetchedStatus = car.status;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _hasRefreshedStatus = true);
    }
  }

  bool get _isAuctionLive {
    final s = _effectiveStatus.toLowerCase().trim();
    if (s == 'sold' || s == 'won') return false;
    if (_hasRegularBid) return true;
    if (_isCurrentUserSeller) return false;
    return true;
  }

  bool get _canUpdateOrCancelBid {
    if (_currentBid == null || _hasBuyNowBid || _hasSwapOffer) return false;
    final s = _effectiveStatus.toLowerCase().trim();
    if (s == 'sold' || s == 'won') return false;
    return true;
  }

  Future<void> _checkIfPurchasedByUser() async {
    try {
      if (widget.car.status == 'sold' || widget.car.status == 'won') {
        try {
          final purchaseHistory = await _carService.getPurchaseHistory();
          final isInPurchaseHistory = purchaseHistory.any((car) => car.id == widget.car.id);
          if (isInPurchaseHistory) {
            if (mounted) {
              setState(() {
                _isPurchasedByCurrentUser = true;
              });
            }
            print('✅ Vehicle found in purchase history (sold status)');
            return;
          }
        } catch (e) {
          print('⚠️ Error checking purchase history: $e');
        }
      }

      try {
        final purchaseHistory = await _carService.getPurchaseHistory();
        final isInPurchaseHistory = purchaseHistory.any((car) => car.id == widget.car.id);
        if (isInPurchaseHistory) {
          if (mounted) {
            setState(() {
              _isPurchasedByCurrentUser = true;
            });
          }
          print('✅ Vehicle found in purchase history');
          return;
        }
      } catch (e) {
        print('⚠️ Error checking purchase history: $e');
      }

      if (widget.car.status == 'sold' || widget.car.status == 'won') {
        try {
          final wonBids = await _bidService.getMyBids(filter: 'won');
          final isPurchased = wonBids.any((bid) {
            final vehicle = bid['vehicle'] as Map<String, dynamic>?;
            if (vehicle != null) {
              final vehicleId = vehicle['id']?.toString() ?? vehicle['vehicle_id']?.toString();
              return vehicleId == widget.car.id;
            }
            return false;
          });

          if (mounted) {
            setState(() {
              _isPurchasedByCurrentUser = isPurchased;
            });
          }
          if (isPurchased) {
            print('✅ Vehicle found in won bids');
          }
        } catch (e) {
          print('⚠️ Error checking won bids: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error checking if purchased by user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isInitialLoading = _isLoadingPhotos || _isLoadingBidStatus;

    return SafeScaffold(
      backgroundColor: kWhiteColor,
      enableScroll: false,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        toolbarHeight: ResponsiveHelper.isMobile(context)
            ? null
            : (_isLargeTablet(context)
            ? 100.0
            : (_isMediumTablet(context)
            ? 88.0
            : (_isSmallMediumTablet(context) ? 80.0 : 84.0))),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: ResponsiveHelper.isMobile(context)
              ? 22.0
              : (_isLargeTablet(context)
              ? 42.0
              : (_isMediumTablet(context)
              ? 36.0
              : (_isSmallMediumTablet(context) ? 32.0 : 34.0))),
        ),
        title: Text(
          'Vehicle Details',
          style: TextStyle(
            fontSize: ResponsiveHelper.isMobile(context)
                ? 18.0
                : (_isLargeTablet(context)
                ? 34.0
                : (_isMediumTablet(context)
                ? 28.0
                : (_isSmallMediumTablet(context) ? 24.0 : 26.0))),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: ResponsiveHelper.isMobile(context)
                ? 22.0
                : (_isLargeTablet(context)
                ? 42.0
                : (_isMediumTablet(context)
                ? 36.0
                : (_isSmallMediumTablet(context) ? 32.0 : 34.0))),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _loadingButtonKey == 'appBarFav'
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(
              _isInWatchlist ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _loadingButtonKey == 'appBarFav'
                ? null
                : () async {
              setState(() => _loadingButtonKey = 'appBarFav');
              await _watchlistController.toggleWatchlist(widget.car.id);
              if (mounted) {
                setState(() {
                  _loadingButtonKey = null;
                  _isInWatchlist = _watchlistController.isWatched(widget.car.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isInWatchlist ? 'Added to watchlist' : 'Removed from watchlist',
                    ),
                    backgroundColor: _isInWatchlist ? Colors.green : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white, size: 22),
            onPressed: () => _shareListing(),
          ),
        ],
      ),
      body: Stack(
        children: [
          isInitialLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading vehicle details...',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.adaptiveBodySize(context) * 0.9,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _detailsScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageCarousel(),
                      _buildCarDetailsCard(),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (_isLoadingPhotos) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.22,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        CarouselSlider(
          carouselController: _carouselController,
          items: _carImages.map((imagePath) {
            return Builder(
              builder: (BuildContext context) {
                final bool isNetwork =
                    imagePath.startsWith('http://') ||
                        imagePath.startsWith('https://');

                print('🖼️ ProductDetails: Loading image: $imagePath (isNetwork: $isNetwork)');

                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final idx = _carImages.indexOf(imagePath);
                        if (idx >= 0) _showFullScreenImages(idx);
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                        ),
                        child: isNetwork
                            ? Image.network(
                          imagePath,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ ProductDetails: Failed to load image: $imagePath');
                            return Image.asset(
                              'assets/images/car1.png',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Image not found',
                                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        )
                            : Image.asset(
                          imagePath,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ ProductDetails: Failed to load asset: $imagePath');
                            return Image.asset(
                              'assets/images/car1.png',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Image not found',
                                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }).toList(),
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.22,
            viewportFraction: 1.0,
            autoPlay: false,
            enlargeCenterPage: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
        ),
        Positioned(
          left: 12,
          top: MediaQuery.of(context).size.height * 0.11,
          child: GestureDetector(
            onTap: () {
              _carouselController.previousPage();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: MediaQuery.of(context).size.height * 0.11,
          child: GestureDetector(
            onTap: () {
              _carouselController.nextPage();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  // ============ BID STATUS SECTION - NEW ============
  Widget _buildBidStatusSection() {
    if (_recentBids.isEmpty && !_hasRegularBid && !_hasBuyNowBid) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                'Bidding Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_bidCount bids',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Current User's Bid
          if (_hasRegularBid && _currentBid != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Current Bid',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '\$${_formatNumberWithCommas(_currentBid!['bid_amount'])}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_highestBid != null && _highestBid == _currentBid!['bid_amount'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kAccentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'WINNING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
          ],

          // Highest Bid
          if (_highestBid != null && _winningBidInfo != null && !_winningBidInfo!.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Highest Bid',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '\$${_formatNumberWithCommas(_highestBid!)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'by ${_winningBidInfo!['bidder_name'] ?? 'Anonymous'}',
                              style: TextStyle(
                                fontSize: 10,
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
          ],

          // Recent Bids List (last 3)
          if (_recentBids.length > 1) ...[
            const SizedBox(height: 2),
            const Text(
              'Recent Bids',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ..._recentBids.take(3).map((bid) {
              final amount = (bid['bid_amount'] is int)
                  ? (bid['bid_amount'] as int).toDouble()
                  : (bid['bid_amount'] as double? ?? 0.0);
              final isCurrentUserBid = _hasRegularBid && _currentBid != null &&
                  _currentBid!['bid_amount'] == amount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 4,
                      color: isCurrentUserBid ? Colors.amber : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '\$${_formatNumberWithCommas(amount)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrentUserBid ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentUserBid ? Colors.amber[800] : Colors.grey[800],
                        ),
                      ),
                    ),
                    Text(
                      _formatTimeAgo(bid['created_at']),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  String _formatNumberWithCommas(num number) {
    final formatter = number.toStringAsFixed(0);
    return formatter.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  /// Helper to build dynamic status badges in details
  Widget _buildDynamicStatusBadgeInDetails() {
    // 1. Priority: SOLD
    if (_isVehicleCompleted) {
      return _buildDetailBadge('SOLD', Colors.red);
    }

    // 2. Priority: PENDING (Buy Now bid placed)
    if (_hasBuyNowBid) {
      return _buildDetailBadge('PENDING', Colors.orange);
    }

    // 3. Priority: Auction Status
    final status = _effectiveStatus.toLowerCase();
    if (status == 'live' || status == 'active') {
      final now = DateTime.now();
      final difference = widget.car.auctionEndTime.difference(now);

      if (difference.isNegative) {
        return _buildDetailBadge('ENDED', Colors.grey);
      } else if (difference.inHours < 24) {
        return _buildDetailBadge('ENDING', Colors.orange);
      } else {
        return _buildDetailBadge('ACTIVE', Colors.green);
      }
    }

    // 4. Priority: Regular Bidding
    if (_hasRegularBid) {
      return _buildDetailBadge('BIDDING', kAccentColor);
    }

    return const SizedBox.shrink();
  }

  /// Helper to build the badge container for details
  Widget _buildDetailBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildValuationBanner() {
    return const SizedBox.shrink();

    // Original code below (commented out)
    /*
    if (_isLoadingValuation || _recommendedPrice == null || _recommendedPrice == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[700],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estimate from internal valuation (same logic as website when no comps).',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Recommended price: \$${_formatNumberWithCommas(_recommendedPrice!)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_marketValuation != null && _marketValuation! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Market Value: \$${_formatNumberWithCommas(_marketValuation!)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
    */
  }

  Widget _buildCarDetailsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 0),
      decoration: const BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildValuationBanner(),
            // New Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'New',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Car Model + Auction Timer + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${widget.car.make} ${widget.car.model}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                ),
                _buildDynamicStatusBadgeInDetails(),
              ],
            ),
            const SizedBox(height: 3),

            // Mileage and Rating
            Row(
              children: [
                Text(
                  '${widget.car.mileage} mi.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        size: 12,
                        color: index < 4 ? Colors.amber : Colors.grey[300],
                      );
                    }),
                    const SizedBox(width: 3),
                    const Text(
                      '4.9 (1k)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Price and Distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPriceLabelText(),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.adaptiveBodySize(context) * 1.2,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 5.0,),
                      Text(
                        _getDisplayPriceText(),
                        style: TextStyle(
                          fontSize: (ResponsiveHelper.adaptiveTitleSize(context) * 0.8).clamp(16.0, 22.0),
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context) ? 10.0 : 8.0,
                    vertical: ResponsiveHelper.isIPad(context) || ResponsiveHelper.isAndroidTablet(context) ? 6.0 : 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.car.distance,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.adaptiveBodySize(context) * 0.85,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),

            // BID STATUS SECTION - ADDED HERE
            _buildBidStatusSection(),
            if (_recentBids.isNotEmpty) const SizedBox(height: 8),

            // Performance Statistics
            Row(
              children: [
                Expanded(child: _buildPerformanceCard('543 HP', 'Horsepower')),
                const SizedBox(width: 6),
                Expanded(child: _buildPerformanceCard('284 lb-ft', 'Torque')),
                const SizedBox(width: 6),
                Expanded(child: _buildPerformanceCard('7.2 sec', '0-60 mph')),
              ],
            ),
            const SizedBox(height: 12),

            // Tabs
            _buildTabs(),
            const SizedBox(height: 8),

            // Tab Content
            RepaintBoundary(
              key: _tabContentKey,
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Details', 'Features', 'Design', 'Price Map'];
    return Row(
      children: List.generate(tabs.length, (index) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = index;
              });
              _scrollToTabContent();
            },
            child: Column(
              children: [
                Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _selectedTab == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _selectedTab == index
                        ? kAccentColor
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: _selectedTab == index
                        ? kAccentColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDetailsTab();
      case 1:
        return _buildFeaturesTab();
      case 2:
        return _buildDesignTab();
      case 3:
        return _buildPriceMapTab();
      default:
        return _buildDetailsTab();
    }
  }

  String _getInspectionStatusDisplay(String? raw) {
    if (raw == null || raw.isEmpty) return 'Not yet';
    final lower = raw.toLowerCase().trim();
    if (lower == 'not_yet' || lower == 'not_requested') return 'Not yet';
    if (lower == 'pending' || lower == 'assigned' || lower == 'in_progress' || lower == 'requested') return 'Pending';
    if (lower == 'completed' || lower == 'approved') return 'Inspected';
    if (lower == 'rejected' || lower == 'cancelled' || lower == 'declined') return 'Not inspected';
    return 'Not yet';
  }

  String _getInspectionPortalStatusText(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    final lower = raw.toLowerCase().trim();
    switch (lower) {
      case 'completed': return 'Completed';
      case 'in_progress': return 'In Progress';
      case 'assigned': return 'Assigned';
      case 'accepted': return 'Accepted';
      case 'pending': return 'Pending';
      case 'requested': return 'Requested';
      default: return raw;
    }
  }

  Color _getInspectionStatusColor(String? raw) {
    if (raw == null || raw.isEmpty) return Colors.grey;
    final lower = raw.toLowerCase().trim();
    if (lower == 'completed') return Colors.green;
    if (lower == 'in_progress') return Colors.blue;
    if (lower == 'assigned') return Colors.orange;
    if (lower == 'accepted' || lower == 'pending' || lower == 'requested') return Colors.amber[700]!;
    return Colors.grey;
  }

  Widget _buildInspectionStatusCard() {
    if (_inspectionInfo == null) return const SizedBox.shrink();
    final status = _inspectionInfo!['status']?.toString();
    final statusText = _getInspectionPortalStatusText(status);
    final color = _getInspectionStatusColor(status);
    String? detail;
    if (_inspectionInfo!['inspector_name'] != null && _inspectionInfo!['inspector_name'].toString().isNotEmpty) {
      detail = 'Inspector: ${_inspectionInfo!['inspector_name']}';
    } else if (_inspectionInfo!['scheduled_date'] != null) {
      try {
        final d = DateTime.parse(_inspectionInfo!['scheduled_date'].toString());
        detail = 'Scheduled: ${d.month}/${d.day}/${d.year}';
      } catch (_) {
        detail = 'Scheduled: ${_inspectionInfo!['scheduled_date']}';
      }
    } else if (_inspectionInfo!['location'] != null && _inspectionInfo!['location'].toString().isNotEmpty) {
      detail = 'Location: ${_inspectionInfo!['location']}';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inspection: $statusText',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    final listingDetails = <Map<String, String>>[];

    if (widget.car.year != null) {
      listingDetails.add({'label': 'Year', 'value': widget.car.year.toString()});
    }
    if (widget.car.make.isNotEmpty) {
      listingDetails.add({'label': 'Make', 'value': widget.car.make});
    }
    if (widget.car.model.isNotEmpty) {
      listingDetails.add({'label': 'Model', 'value': widget.car.model});
    }
    if (widget.car.vin != null && widget.car.vin!.isNotEmpty) {
      listingDetails.add({'label': 'VIN', 'value': widget.car.vin!});
    }
    if (widget.car.mileage != null) {
      listingDetails.add({'label': 'Mileage', 'value': '${widget.car.mileage!.toStringAsFixed(0)} miles'});
    }
    if (widget.car.location.isNotEmpty) {
      listingDetails.add({'label': 'Location', 'value': widget.car.location});
    }
    if (widget.car.exteriorColor != null && widget.car.exteriorColor!.isNotEmpty) {
      listingDetails.add({'label': 'Exterior Color', 'value': widget.car.exteriorColor!});
    }
    if (widget.car.interiorColor != null && widget.car.interiorColor!.isNotEmpty) {
      listingDetails.add({'label': 'Interior Color', 'value': widget.car.interiorColor!});
    }
    if (widget.car.condition != null && widget.car.condition!.isNotEmpty) {
      listingDetails.add({'label': 'Condition', 'value': widget.car.condition!});
    }
    if (widget.car.isSmokerVehicle != null) {
      listingDetails.add({
        'label': 'Smoker vehicle',
        'value': widget.car.isSmokerVehicle! ? 'Yes' : 'No',
      });
    }
    if (widget.car.hasRedLightOrSalvage != null) {
      listingDetails.add({
        'label': 'Salvage / red light title',
        'value': widget.car.hasRedLightOrSalvage! ? 'Disclosed' : 'No',
      });
    }
    if (widget.car.thirdPartyInspected != null) {
      listingDetails.add({
        'label': 'Third-party inspected',
        'value': widget.car.thirdPartyInspected! ? 'Yes' : 'No',
      });
    }
    if (widget.car.engineType != null && widget.car.engineType!.isNotEmpty) {
      listingDetails.add({'label': 'Engine Type', 'value': widget.car.engineType!});
    }
    if (widget.car.fuelType != null && widget.car.fuelType!.isNotEmpty) {
      listingDetails.add({'label': 'Fuel Type', 'value': widget.car.fuelType!});
    }
    if (widget.car.driveTrain != null && widget.car.driveTrain!.isNotEmpty) {
      listingDetails.add({'label': 'Drive Train', 'value': widget.car.driveTrain!});
    }

    if (widget.car.hasAuction == true) {
      if (widget.car.currentBid != null && widget.car.currentBid! > 0) {
        listingDetails.add({'label': 'Current Bid', 'value': '\$${widget.car.currentBid!.toStringAsFixed(0)}'});
      }
      if (widget.car.startingBid != null) {
        listingDetails.add({'label': 'Starting Bid', 'value': '\$${widget.car.startingBid!.toStringAsFixed(0)}'});
      }
    }
    if (widget.car.buyNowPrice != null && widget.car.buyNowPrice! > 0) {
      listingDetails.add({'label': 'Buy Now Price', 'value': '\$${widget.car.buyNowPrice!.toStringAsFixed(0)}'});
    }
    if (widget.car.status != null && widget.car.status!.isNotEmpty) {
      listingDetails.add({'label': 'Status', 'value': widget.car.status!.toUpperCase()});
    }

    if (widget.car.description != null && widget.car.description!.isNotEmpty) {
      listingDetails.add({
        'label': 'Seller disclosure',
        'value': widget.car.description!,
      });
    }

    final inspectionStatusRaw = _inspectionInfo?['status']?.toString() ?? widget.car.inspectionStatus;
    listingDetails.add({
      'label': 'Inspection Status',
      'value': _getInspectionStatusDisplay(inspectionStatusRaw),
    });
    if (_inspectionInfo != null) {
      final inspection = _inspectionInfo!;
      if (inspection['inspector_name'] != null && inspection['inspector_name'].toString().isNotEmpty) {
        listingDetails.add({'label': 'Inspection Assigned To', 'value': inspection['inspector_name']});
      }
      if (inspection['scheduled_date'] != null) {
        try {
          final date = DateTime.parse(inspection['scheduled_date']);
          listingDetails.add({'label': 'Inspection Scheduled', 'value': '${date.month}/${date.day}/${date.year}'});
        } catch (e) {
          // Ignore
        }
      }
    }

    if (listingDetails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No listing details available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
/*
        if (_marketValuation != null || _isLoadingValuation) ...[
          _buildMarketValuationSection(),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),
        ],
*/
        RepaintBoundary(
          key: _distanceCalculatorSectionKey,
          child: _buildDistanceCalculatorSection(
            expanded: _expandedSection == 3,
            onExpansionChanged: (bool exp) {
              setState(() => _expandedSection = exp ? 3 : 0);
              if (exp) _scrollToDistanceCalculator();
            },
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 20)),
        RepaintBoundary(
          key: _listingSectionKey,
          child: _buildSpecSection(
            'Listing Information',
            listingDetails,
            expanded: _expandedSection == 1,
            onExpansionChanged: (bool exp) {
              setState(() => _expandedSection = exp ? 1 : 0);
              if (exp) _scrollToExpandedSection(1);
            },
            initialCount: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildMarketValuationSection() {
    return Container(
      padding: ResponsiveHelper.padding(context, all: 14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, color: Colors.blue[700], size: 22),
              SizedBox(width: ResponsiveHelper.spacing(context, 6)),
              Text(
                'Market Valuation',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          if (_isLoadingValuation)
            Center(
              child: Padding(
                padding: ResponsiveHelper.padding(context, vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_marketValuation != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Internal Valuation',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        '\$${_marketValuation!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_tradeInValue != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trade-In',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                        Text(
                          '\$${_tradeInValue!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            Text(
              'Internal valuation. Connect APIs for accurate data.',
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDistanceCalculatorSection({
    required bool expanded,
    required ValueChanged<bool> onExpansionChanged,
  }) {
    String vehicleZip = widget.car.location.trim();
    String displayZip = 'N/A';
    if (vehicleZip.isNotEmpty) {
      String zipToProcess = vehicleZip;
      if (zipToProcess.contains(',')) {
        zipToProcess = zipToProcess.split(',').last.trim();
      }
      if (RegExp(r'^\d{5}(-\d{4})?$').hasMatch(zipToProcess)) {
        displayZip = zipToProcess;
      } else {
        String digitsOnly = zipToProcess.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.isNotEmpty) {
          if (zipToProcess.contains('-') && digitsOnly.length >= 9) {
            displayZip = '${digitsOnly.substring(0, 5)}-${digitsOnly.substring(5, 9)}';
          } else if (digitsOnly.length >= 9) {
            displayZip = '${digitsOnly.substring(0, 5)}-${digitsOnly.substring(5, 9)}';
          } else {
            displayZip = digitsOnly;
          }
        } else {
          displayZip = zipToProcess;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        key: ValueKey('distance_$_expandedSection'),
        initiallyExpanded: expanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: kAccentColor,
        collapsedIconColor: kAccentColor,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        onExpansionChanged: onExpansionChanged,
        title: Row(
          children: [
            Icon(Icons.location_on, color: kAccentColor, size: 22),
            SizedBox(width: ResponsiveHelper.spacing(context, 6)),
            Text(
              'Distance Calculator',
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                fontWeight: FontWeight.bold,
                color: kBlackColor,
              ),
            ),
          ],
        ),
        children: [
          _buildLocationField(
            'Vehicle Location',
            displayZip != 'N/A'
                ? displayZip
                : (widget.car.location.isNotEmpty ? widget.car.location.trim() : 'Not available'),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 10)),
          TextField(
            controller: _yourLocationZipController,
            decoration: InputDecoration(
              labelText: 'Your Location (ZIP Code)',
              hintText: 'Enter your ZIP code',
              labelStyle: const TextStyle(fontSize: 13),
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: Icon(Icons.location_searching, color: kAccentColor, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                borderSide: BorderSide(color: kAccentColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 10)),
          ElevatedButton.icon(
            onPressed: _isCalculatingDistance ? null : _calculateDistance,
            icon: _isCalculatingDistance
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(Icons.calculate, size: 16),
            label: Text(
              _isCalculatingDistance ? 'Calculating...' : 'Calculate',
              style: TextStyle(fontSize: ResponsiveHelper.fontSize(context, mobile: 13)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.white,
              padding: ResponsiveHelper.padding(context, horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
              ),
            ),
          ),
          if (_calculatedDistance != null) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 10)),
            Container(
              padding: ResponsiveHelper.padding(context, all: 10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distance',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        '${_calculatedDistance!.toStringAsFixed(1)} miles',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _saveDistance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: ResponsiveHelper.padding(context, horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
            fontWeight: FontWeight.w600,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 6)),
        Container(
          padding: ResponsiveHelper.padding(context, all: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey[600], size: 18),
              SizedBox(width: ResponsiveHelper.spacing(context, 6)),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecSection(
      String title,
      List<Map<String, String>> specs, {
        bool? expanded,
        void Function(bool)? onExpansionChanged,
        int initialCount = 4,
      }) {
    final useExpand = specs.length > initialCount;
    final initialSpecs = useExpand ? specs.take(initialCount).toList() : specs;
    final remainingSpecs = useExpand ? specs.skip(initialCount).toList() : <Map<String, String>>[];

    Widget content(List<Map<String, String>> list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((spec) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    spec['label']!,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    spec['value']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kBlackColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (useExpand) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: content(initialSpecs),
            ),
            ExpansionTile(
              key: ValueKey('listing_$_expandedSection'),
              initiallyExpanded: expanded ?? false,
              onExpansionChanged: onExpansionChanged,
              tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              childrenPadding: EdgeInsets.fromLTRB(0, 0, 0, 12),
              iconColor: kAccentColor,
              collapsedIconColor: kAccentColor,
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              title: Text(
                'Show ${remainingSpecs.length} more details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kAccentColor,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: content(remainingSpecs),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 10),
        content(specs),
      ],
    );
  }

  static String _vinVal(dynamic v) => (v == null || v.toString().trim().isEmpty) ? '' : v.toString().trim();

  List<MapEntry<String, String>> _getEnginePerformanceEntries() {
    if (_vinDecodeData == null) return [];
    final d = _vinDecodeData!;
    final list = <MapEntry<String, String>>[];
    final addedKeys = <String>{};
    void add(String key, String label, String value) {
      if (value.isEmpty) return;
      final k = key.toLowerCase();
      if (addedKeys.contains(k)) return;
      addedKeys.add(k);
      list.add(MapEntry(label, value));
    }
    add('engine_type', 'Engine', _vinVal(d['engine_type']));
    add('engine_configuration', 'Engine configuration', _vinVal(d['engine_configuration']));
    add('engine_cylinders', 'Cylinders', _vinVal(d['engine_cylinders']));
    add('engine_hp', 'Engine HP', _vinVal(d['engine_hp']));
    add('displacement_cc', 'Displacement (CC)', _vinVal(d['displacement_cc']));
    add('displacement_l', 'Displacement (L)', _vinVal(d['displacement_l']));
    if (_vinVal(d['displacement']).isNotEmpty && _vinVal(d['displacement_l']).isEmpty) add('displacement', 'Displacement', _vinVal(d['displacement']));
    add('fuel_type', 'Fuel type', _vinVal(d['fuel_type']));
    add('fuel_type_primary', 'Fuel type (primary)', _vinVal(d['fuel_type_primary']));
    add('fuel_injection_type', 'Fuel injection', _vinVal(d['fuel_injection_type']));
    add('drive_train', 'Drive train', _vinVal(d['drive_train']));
    if (_vinVal(d['drive_type']).isNotEmpty && _vinVal(d['drive_train']).isEmpty) add('drive_type', 'Drive type', _vinVal(d['drive_type']));
    add('transmission', 'Transmission', _vinVal(d['transmission']));
    add('transmission_style', 'Transmission style', _vinVal(d['transmission_style']));
    add('transmission_speeds', 'Transmission speeds', _vinVal(d['transmission_speeds']));
    add('brake_system_type', 'Brake system', _vinVal(d['brake_system_type']));
    add('top_speed_mph', 'Top speed (MPH)', _vinVal(d['top_speed_mph']));
    final engineLike = ['engine', 'displacement', 'fuel', 'drive', 'transmission', 'brake', 'speed', 'cylinder', 'hp', 'horsepower', 'liter', 'cc'];
    for (final entry in d.entries) {
      final key = entry.key.toString().toLowerCase();
      if (addedKeys.contains(key)) continue;
      final value = _vinVal(entry.value);
      if (value.isEmpty) continue;
      final isEngineLike = engineLike.any((t) => key.contains(t));
      if (isEngineLike) {
        final label = key.replaceAll('_', ' ').split(' ').map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase()).join(' ');
        list.add(MapEntry(label, value));
        addedKeys.add(key);
      }
    }
    return list;
  }

  List<MapEntry<String, String>> _getSafetyFeaturesEntries() {
    final list = <MapEntry<String, String>>[];
    final features = _vinSafetyData?['safety_features'];
    if (features is Map) {
      final f = Map<String, dynamic>.from(features);
      if (_vinVal(f['ElectronicStabilityControl']).isNotEmpty) list.add(MapEntry('Electronic stability control', _vinVal(f['ElectronicStabilityControl'])));
      if (_vinVal(f['ForwardCollisionWarning']).isNotEmpty) list.add(MapEntry('Forward collision warning', _vinVal(f['ForwardCollisionWarning'])));
      if (_vinVal(f['LaneDepartureWarning']).isNotEmpty) list.add(MapEntry('Lane departure warning', _vinVal(f['LaneDepartureWarning'])));
      if (_vinVal(f['DynamicBrakeSupport']).isNotEmpty) list.add(MapEntry('Dynamic brake support', _vinVal(f['DynamicBrakeSupport'])));
      if (_vinVal(f['RearVideoSystem']).isNotEmpty) list.add(MapEntry('Rear video system', _vinVal(f['RearVideoSystem'])));
    }
    if (list.isEmpty && _vinDecodeData != null) {
      final d = _vinDecodeData!;
      if (_vinVal(d['body_class']).isNotEmpty) list.add(MapEntry('Body class', _vinVal(d['body_class'])));
      if (_vinVal(d['doors']).isNotEmpty) list.add(MapEntry('Doors', _vinVal(d['doors'])));
      if (_vinVal(d['seats']).isNotEmpty) list.add(MapEntry('Seats', _vinVal(d['seats'])));
      if (_vinVal(d['trim']).isNotEmpty) list.add(MapEntry('Trim', _vinVal(d['trim'])));
      if (_vinVal(d['gvwr']).isNotEmpty) list.add(MapEntry('GVWR', _vinVal(d['gvwr'])));
    }
    return list;
  }

  List<MapEntry<String, String>> _getSafetyRatingsRecallsEntries() {
    final list = <MapEntry<String, String>>[];
    final ratings = _vinSafetyData?['ratings'];
    if (ratings is Map) {
      final r = Map<String, dynamic>.from(ratings);
      if (_vinVal(r['OverallRating']).isNotEmpty) list.add(MapEntry('Overall rating', _vinVal(r['OverallRating'])));
      if (_vinVal(r['OverallFrontCrashRating']).isNotEmpty) list.add(MapEntry('Front crash rating', _vinVal(r['OverallFrontCrashRating'])));
      if (_vinVal(r['OverallSideRating']).isNotEmpty) list.add(MapEntry('Side rating', _vinVal(r['OverallSideRating'])));
      if (_vinVal(r['RolloverRating']).isNotEmpty) list.add(MapEntry('Rollover rating', _vinVal(r['RolloverRating'])));
      if (_vinVal(r['FrontCrashDriversideRating']).isNotEmpty) list.add(MapEntry('Front crash driver side', _vinVal(r['FrontCrashDriversideRating'])));
    }
    return list;
  }

  Widget _buildSafetyRatingsRecallsSection() {
    final ratings = _getSafetyRatingsRecallsEntries();
    final recalls = _vinRecallsData;
    final hasRatings = ratings.isNotEmpty;
    final hasRecalls = recalls != null && recalls.isNotEmpty;
    if (!hasRatings && !hasRecalls) {
      return _buildVinDetailSection('Safety Ratings & Recalls', Icons.warning_amber_rounded, []);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: kAccentColor),
              const SizedBox(width: 6),
              const Text(
                'Safety Ratings & Recalls',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kBlackColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasRatings)
            ...ratings.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: Text(e.key, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500))),
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13, color: kBlackColor))),
                ],
              ),
            )),
          if (hasRecalls) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Recalls (${recalls!.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlackColor)),
            ),
            for (int i = 0; i < recalls.length; i++) ...[
              Builder(
                builder: (context) {
                  final r = recalls[i] is Map ? Map<String, dynamic>.from(recalls[i] as Map) : <String, dynamic>{};
                  final campaign = _vinVal(r['NHTSACampaignNumber']);
                  final summary = _vinVal(r['Summary']);
                  final consequence = _vinVal(r['Consequence']);
                  final remedy = _vinVal(r['Remedy']);
                  final notes = _vinVal(r['Notes']);
                  if (campaign.isEmpty && summary.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (campaign.isNotEmpty) Text('Campaign: $campaign', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(summary, style: const TextStyle(fontSize: 12))),
                          if (consequence.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Consequence: $consequence', style: TextStyle(fontSize: 11, color: Colors.red.shade700))),
                          if (remedy.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Remedy: $remedy', style: const TextStyle(fontSize: 11))),
                          if (notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Notes: $notes', style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _getManufacturerInfoEntries() {
    if (_vinDecodeData == null) return [];
    final d = _vinDecodeData!;
    final list = <MapEntry<String, String>>[];
    if (_vinVal(d['manufacturer']).isNotEmpty) list.add(MapEntry('Manufacturer', _vinVal(d['manufacturer'])));
    if (_vinVal(d['manufacturer_id']).isNotEmpty) list.add(MapEntry('Manufacturer ID', _vinVal(d['manufacturer_id'])));
    if (_vinVal(d['make']).isNotEmpty) list.add(MapEntry('Make', _vinVal(d['make'])));
    if (_vinVal(d['model']).isNotEmpty) list.add(MapEntry('Model', _vinVal(d['model'])));
    if (_vinVal(d['year']).isNotEmpty) list.add(MapEntry('Year', _vinVal(d['year'])));
    if (_vinVal(d['plant_country']).isNotEmpty) list.add(MapEntry('Plant country', _vinVal(d['plant_country'])));
    if (_vinVal(d['plant_city']).isNotEmpty) list.add(MapEntry('Plant city', _vinVal(d['plant_city'])));
    if (_vinVal(d['plant_state']).isNotEmpty) list.add(MapEntry('Plant state', _vinVal(d['plant_state'])));
    return list;
  }

  Widget _buildVinDetailSection(String title, IconData icon, List<MapEntry<String, String>> entries) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kAccentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'No data available for this category.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          else
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(fontSize: 13, color: kBlackColor),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    final vin = widget.car.vin?.trim();
    final hasVin = vin != null && vin.length == 17;
    if (hasVin && !_vinDecodeLoaded && !_isLoadingVinDecode) {
      _loadVinDecode();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VIN-based vehicle information',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingVinDecode)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (!hasVin)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'VIN not available for this listing. These details are from official VIN decode when available.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          )
        else if (hasVin && _vinDecodeData == null && _vinDecodeLoaded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'VIN decode returned no data for this vehicle.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            )
          else ...[
              _buildVinDetailSection('Engine & Performance', Icons.engineering, _getEnginePerformanceEntries()),
              _buildVinDetailSection('Safety Features', Icons.security, _getSafetyFeaturesEntries()),
              _buildSafetyRatingsRecallsSection(),
              _buildVinDetailSection('Manufacturer Info', Icons.business, _getManufacturerInfoEntries()),
            ],
      ],
    );
  }

  Future<void> _loadVinDecode() async {
    final vin = widget.car.vin?.trim();
    if (vin == null || vin.length != 17) return;
    if (_isLoadingVinDecode) return;
    setState(() {
      _isLoadingVinDecode = true;
      _vinDecodeLoaded = true;
    });
    try {
      final full = await _nhtsaService.getVinFullDetails(vin, modelYear: widget.car.year);
      if (mounted) {
        if (full != null && full['decode'] != null) {
          setState(() {
            _vinDecodeData = Map<String, dynamic>.from(full['decode'] as Map);
            _vinSafetyData = full['safety'] != null ? Map<String, dynamic>.from(full['safety'] as Map) : null;
            _vinRecallsData = full['recalls'] is List ? List.from(full['recalls'] as List) : null;
            _isLoadingVinDecode = false;
          });
        } else {
          final data = await _nhtsaService.decodeVin(vin, modelYear: widget.car.year);
          setState(() {
            _vinDecodeData = data;
            _vinSafetyData = null;
            _vinRecallsData = null;
            _isLoadingVinDecode = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _vinDecodeData = null;
          _vinSafetyData = null;
          _vinRecallsData = null;
          _isLoadingVinDecode = false;
        });
      }
    }
  }

  Widget _buildDesignTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap any photo to open full screen',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (_isLoadingPhotos)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_carImages.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No photos available', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: _carImages.length,
            itemBuilder: (context, index) {
              final url = _carImages[index];
              final isNetwork = url.startsWith('http://') || url.startsWith('https://');
              return GestureDetector(
                onTap: () => _showFullScreenImages(index),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: isNetwork
                        ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 28),
                        );
                      },
                    )
                        : Image.asset(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 28),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPriceMapTab() {
    final marketValuation = _marketValuation;
    final isValuationReady = !_isLoadingValuation && marketValuation != null && marketValuation > 0;
    final bookAvg = isValuationReady ? marketValuation! : null;
    final bookLow = isValuationReady ? (marketValuation! * 0.85) : null;
    final bookHigh = isValuationReady ? (marketValuation! * 1.15) : null;

    String? bookRangeText;
    if (isValuationReady && bookLow != null && bookHigh != null) {
      bookRangeText = '\$${bookLow.toStringAsFixed(0)} - \$${bookHigh.toStringAsFixed(0)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_car, color: Colors.blue[700], size: 22),
            const SizedBox(width: 6),
            Text(
              'JD POWER & KBB BOOK VALUE:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kBlackColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          bookRangeText ?? 'Book value not available',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: bookRangeText != null ? kAccentColor : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Handle CARFAX report view
            },
            icon: const Icon(Icons.description, color: Colors.white, size: 18),
            label: const Text(
              'VIEW CARFAX REPORT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Price history',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 6),
        if (!isValuationReady && _isLoadingValuation)
          const Text(
            'Loading valuation...',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          )
        else
          const Text(
            'Price history not available for this listing.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        const SizedBox(height: 12),

        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              isValuationReady ? 'Valuation loaded' : 'No history graph',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildPriceCard(
                'Average',
                bookAvg != null ? '\$${bookAvg.toStringAsFixed(0)}' : 'N/A',
                Colors.blue,
                Icons.attach_money,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPriceCard(
                'Highest',
                bookHigh != null ? '\$${bookHigh.toStringAsFixed(0)}' : 'N/A',
                Colors.green,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPriceCard(
                'Lowest',
                bookLow != null ? '\$${bookLow.toStringAsFixed(0)}' : 'N/A',
                Colors.red,
                Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Pricing',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 8),
        if (isValuationReady)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Pricing breakdown not available for this listing.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Pricing breakdown not available.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Price',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kBlackColor,
              ),
            ),
            Text(
              _getDisplayPriceText(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kAccentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Est. Monthly Payment',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Text(
              'N/A',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kBlackColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              // Handle credit simulation
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Credit Simulation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kBlackColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(
      String title,
      String value,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: ResponsiveHelper.adaptiveBodySize(context) * 0.9, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveHelper.adaptiveBodySize(context) * 0.9,
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowRequestInspection() {
    final status = _inspectionInfo?['status']?.toString();
    final normalizedStatus = status != null ? status.toLowerCase().trim() : null;
    final isCompleted = _inspectionInfo != null &&
        normalizedStatus != null &&
        normalizedStatus == 'completed';
    return !isCompleted;
  }

  Widget _buildInspectionButton() {
    print('🔍 _buildInspectionButton - _inspectionInfo: $_inspectionInfo');

    final status = _inspectionInfo?['status']?.toString();
    final normalizedStatus = status != null ? status.toLowerCase().trim() : null;
    final isCompleted = _inspectionInfo != null &&
        normalizedStatus != null &&
        normalizedStatus == 'completed';

    final inspectionId = _inspectionInfo?['id']?.toString();

    print('🔍 _buildInspectionButton - status: "$status", normalized: "$normalizedStatus", isCompleted: $isCompleted');

    if (isCompleted) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewReportScreen(
                car: widget.car,
                inspectionId: inspectionId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.description, size: 16),
        label: const Text(
          'View Report',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          elevation: 2,
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SellerInspectionRequestScreen(
                car: widget.car,
              ),
            ),
          );
        },
        icon: const Icon(Icons.search, size: 16),
        label: const Text(
          'Inspection',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          elevation: 2,
        ),
      );
    }
  }

  // ============ UPDATED ACTION BUTTONS WITH CORRECT LOGIC ============
  Widget _buildActionButtons() {
    if (_isCurrentUserSeller) {
      final isSold = _effectiveStatus == 'sold' || _effectiveStatus == 'won';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhiteColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSold) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue[700], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'VEHICLE SOLD',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SellerBidManagementScreen(vehicle: widget.car),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          side: BorderSide(color: kAccentColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          isSold ? 'View Bid History' : 'View Bids',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kAccentColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInspectionButton(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ============ BUYER BUTTONS WITH PROPER LOGIC ============
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: kWhiteColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show status message if vehicle is sold
                  if (_isVehicleCompleted || _effectiveStatus == 'sold' || _effectiveStatus == 'won') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isPurchasedByCurrentUser
                            ? kAccentColor.withOpacity(0.15)
                            : kAccentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: kAccentColor.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPurchasedByCurrentUser
                                ? Icons.shopping_cart_checkout
                                : Icons.check_circle,
                            color: kAccentColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isPurchasedByCurrentUser
                                      ? 'You have purchased this vehicle'
                                      : 'This vehicle is sold now',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kBlackColor,
                                  ),
                                ),
                                if (widget.car.wonAmount != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    'Final Price: ${_formatCurrency(widget.car.wonAmount!)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: kAccentColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, color: Colors.white, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  _isPurchasedByCurrentUser ? 'PURCHASED' : 'SOLD',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // For purchased users: wrap Inspection + Transport
                  if (!_isCurrentUserSeller && (_isPurchasedByCurrentUser || _isVehicleCompleted || _hasBuyNowBid)) ...[
                    RepaintBoundary(
                      key: _purchasedSectionKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.none,
                        child: ExpansionTile(
                          key: ValueKey('purchased_$_expandedSection'),
                          initiallyExpanded: _expandedSection == 4,
                          onExpansionChanged: (bool exp) {
                            setState(() => _expandedSection = exp ? 4 : 0);
                            if (exp) _scrollToExpandedSection(4);
                          },
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          childrenPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 8, top: 2),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                          ),
                          collapsedShape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          iconColor: kAccentColor,
                          collapsedIconColor: kAccentColor,
                          backgroundColor: Colors.white,
                          collapsedBackgroundColor: kAccentColor.withOpacity(0.1),
                          title: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: kAccentColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Inspection, Transport & more',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            if (_shouldShowRequestInspection() || _inspectionInfo != null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    if (_inspectionInfo != null) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BuyerInspectionStatusScreen(
                                            car: widget.car,
                                            initialInspection: _inspectionInfo,
                                          ),
                                        ),
                                      );
                                      if (mounted) _checkInspectionInfo();
                                    } else {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SellerInspectionRequestScreen(car: widget.car),
                                        ),
                                      );
                                      if (mounted) _checkInspectionInfo();
                                    }
                                  },
                                  icon: Icon(
                                    _inspectionInfo != null ? Icons.visibility : Icons.assignment_outlined,
                                    size: 16,
                                    color: kAccentColor,
                                  ),
                                  label: Text(
                                    _inspectionInfo != null ? (!_shouldShowRequestInspection() ? 'View Inspection Report' : 'View Inspection Status') : 'Schedule Inspection',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kBlackColor,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: kAccentColor, width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isCheckingTransporter
                                    ? null
                                    : () async {
                                  if (_hasTransporterAssigned) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TransportTrackingScreen(
                                          vehicleId: widget.car.id,
                                        ),
                                      ),
                                    );
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VehicleShippingScreen(car: widget.car),
                                      ),
                                    );
                                    if (mounted) _checkTransporterStatus();
                                  }
                                },
                                icon: Icon(
                                  _hasTransportRequested
                                      ? Icons.visibility
                                      : (_hasTransporterAssigned ? Icons.visibility : Icons.local_shipping),
                                  size: 16,
                                  color: kAccentColor,
                                ),
                                label: Text(
                                  _isCheckingTransporter
                                      ? 'Checking transport...'
                                      : _hasTransportRequested
                                      ? 'View Transport Status'
                                      : (_hasTransporterAssigned ? 'Track Transport' : 'Schedule Transport'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kBlackColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: kAccentColor, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ] else if (!_isCurrentUserSeller && (_shouldShowRequestInspection() || _inspectionInfo != null)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (_inspectionInfo != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BuyerInspectionStatusScreen(
                                  car: widget.car,
                                  initialInspection: _inspectionInfo,
                                ),
                              ),
                            );
                            if (mounted) _checkInspectionInfo();
                          } else {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SellerInspectionRequestScreen(car: widget.car),
                              ),
                            );
                            if (mounted) _checkInspectionInfo();
                          }
                        },
                        icon: Icon(
                          _inspectionInfo != null ? Icons.visibility : Icons.assignment_outlined,
                          size: 16,
                          color: kAccentColor,
                        ),
                        label: Text(
                          _inspectionInfo != null
                              ? (!_shouldShowRequestInspection() ? 'View Inspection Report' : 'View Inspection Status')
                              : 'Schedule Inspection',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: kAccentColor, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    if (_inspectionInfo != null) ...[
                      const SizedBox(height: 6),
                      _buildInspectionStatusCard(),
                      const SizedBox(height: 6),
                    ] else
                      const SizedBox(height: 6),
                  ],

                  // ============ MAIN BID/BUY NOW/SWAP SECTION ============
                  if (_hasRefreshedStatus &&
                      !_isVehicleCompleted &&
                      !_isPurchasedByCurrentUser &&
                      _effectiveStatus != 'sold' &&
                      _effectiveStatus != 'won') ...[
                    RepaintBoundary(
                      key: _placeBidSectionKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.none,
                        child: ExpansionTile(
                            key: ValueKey('placeBid_$_expandedSection'),
                            initiallyExpanded: _expandedSection == 2,
                            onExpansionChanged: (bool exp) {
                              setState(() => _expandedSection = exp ? 2 : 0);
                              if (exp) _scrollToExpandedSection(2);
                            },
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            childrenPadding: const EdgeInsets.only(
                              left: 2,
                              right: 2,
                              bottom: 2,
                              top: 1,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              ),
                            ),
                            collapsedShape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            iconColor: kAccentColor,
                            collapsedIconColor: kAccentColor,
                            backgroundColor: Colors.white,
                            collapsedBackgroundColor: kAccentColor.withOpacity(0.1),
                            title: Row(
                              children: [
                                Icon(
                                  Icons.gavel_rounded,
                                  size: 16,
                                  color: kAccentColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Place Bid, Buy Now, Watch & more',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child:
                                    _hasRegularBid &&
                                        _currentBid != null &&
                                        !_hasBuyNowBid
                                        ? Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed:
                                            _loadingButtonKey == 'updateBid'
                                                ? null
                                                : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PlaceBidScreen(
                                                        car: widget.car,
                                                      ),
                                                ),
                                              ).then((_) async {
                                                if (!mounted) return;
                                                setState(() => _loadingButtonKey = 'updateBid');
                                                try {
                                                  await _checkBidStatus();
                                                  try {
                                                    final bidController =
                                                    Get.find<BidController>();
                                                    await bidController.fetchMyBids();
                                                  } catch (e) {
                                                    print(
                                                      '⚠️ BidController not found, skipping refresh',
                                                    );
                                                  }
                                                  try {
                                                    final homeController =
                                                    Get.find<HomePageController>();
                                                    await homeController.fetchCars();
                                                    await homeController
                                                        .fetchSellerDashboardData();
                                                  } catch (e) {
                                                    print(
                                                      '⚠️ HomePageController not found: $e',
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(() => _loadingButtonKey = null);
                                                  }
                                                }
                                              });
                                            },
                                            icon: _loadingButtonKey == 'updateBid'
                                                ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                                : const Icon(Icons.gavel, size: 18),
                                            label: const Text(
                                              'Update Bid',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: kAccentColor, // Blue for Update Bid
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                        : (widget.car.hasAuction == true
                                        ? ElevatedButton.icon(
                                      onPressed:
                                      (!_isAuctionLive ||
                                          _hasBuyNowBid ||
                                          _hasSwapOffer ||
                                          _loadingButtonKey == 'placeBid')
                                          ? null
                                          : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaceBidScreen(car: widget.car),
                                          ),
                                        ).then((_) async {
                                          if (!mounted) return;
                                          setState(() => _loadingButtonKey = 'placeBid');
                                          try {
                                            await _checkBidStatus();
                                            try {
                                              final homeController =
                                              Get.find<HomePageController>();
                                              await homeController.fetchCars();
                                              await homeController
                                                  .fetchSellerDashboardData();
                                            } catch (e) {
                                              print(
                                                '⚠️ HomePageController not found: $e',
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _loadingButtonKey = null);
                                            }
                                          }
                                        });
                                      },
                                      icon: _loadingButtonKey == 'placeBid'
                                          ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                          : const Icon(Icons.gavel, size: 18),
                                      label: const Text(
                                        'Place Bid',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        (!_isAuctionLive ||
                                            _hasBuyNowBid ||
                                            _hasSwapOffer)
                                            ? Colors.grey.shade400
                                            : kAccentColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation:
                                        (!_isAuctionLive ||
                                            _hasBuyNowBid ||
                                            _hasSwapOffer)
                                            ? 0
                                            : 2,
                                      ),
                                    )
                                        : const SizedBox.shrink()),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                      (_hasBuyNowBid ||
                                          _isVehicleCompleted ||
                                          _isCurrentUserSeller ||
                                          _loadingButtonKey == 'buyNow')
                                          ? null
                                          : () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BuyNowScreen(car: widget.car),
                                          ),
                                        );
                                        if (result == true && mounted) {
                                          setState(() => _loadingButtonKey = 'buyNow');
                                          try {
                                            if (_currentBid != null) {
                                              try {
                                                final bidController = Get.find<BidController>();
                                                await bidController.withdrawBid(_currentBid!['id'].toString());
                                              } catch (e) {
                                                print('⚠️ Auto-withdraw bid on Buy Now: $e');
                                              }
                                            }
                                            await _checkBidStatus();
                                            await _checkIfPurchasedByUser();
                                            await _checkInspectionInfo();
                                            try {
                                              final bidController = Get.find<BidController>();
                                              await bidController.fetchMyBids();
                                            } catch (e) {
                                              print('⚠️ BidController not found, skipping refresh: $e');
                                            }
                                            try {
                                              final homeController = Get.find<HomePageController>();
                                              await homeController.fetchCars();
                                              await homeController.fetchSellerDashboardData();
                                            } catch (e) {
                                              print('⚠️ HomePageController not found: $e');
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _loadingButtonKey = null);
                                            }
                                          }
                                        }
                                      },
                                      icon: _loadingButtonKey == 'buyNow'
                                          ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                          : Icon(
                                        _hasBuyNowBid
                                            ? Icons.check_circle
                                            : Icons.shopping_cart,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _hasBuyNowBid ? 'Done' : 'Buy Now',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        (_hasBuyNowBid ||
                                            _isVehicleCompleted ||
                                            _isCurrentUserSeller)
                                            ? Colors.grey.shade400
                                            : const Color(0xFF4CAF50),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation:
                                        (_hasBuyNowBid ||
                                            _isVehicleCompleted ||
                                            _isCurrentUserSeller)
                                            ? 0
                                            : 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Contact Seller and View Bidding in one row
                              Row(
                                children: [
                                  if (!_isCurrentUserSeller) ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: (_isVehicleCompleted || _loadingButtonKey == 'contactSeller')
                                            ? null
                                            : () => _handleContactSeller(),
                                        icon: _loadingButtonKey == 'contactSeller'
                                            ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                                          ),
                                        )
                                            : Icon(
                                          Icons.person_outline,
                                          size: 16,
                                          color: _isVehicleCompleted ? Colors.grey : kAccentColor,
                                        ),
                                        label: const Text(
                                          'Contact Seller',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _isVehicleCompleted
                                              ? Colors.grey
                                              : kAccentColor,
                                          side: BorderSide(
                                            color: _isVehicleCompleted ? Colors.grey : kAccentColor,
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!_isVehicleCompleted && !_isPurchasedByCurrentUser) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _loadingButtonKey == 'viewBidding'
                                              ? null
                                              : () async {
                                            setState(() => _loadingButtonKey = 'viewBidding');
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => BuyerBidViewScreen(vehicle: widget.car),
                                              ),
                                            );
                                            if (mounted) {
                                              setState(() => _loadingButtonKey = null);
                                            }
                                          },
                                          icon: _loadingButtonKey == 'viewBidding'
                                              ? SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                                            ),
                                          )
                                              : const Icon(Icons.gavel, size: 16),
                                          label: const Text(
                                            'View Bidding',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: kAccentColor,
                                            side: const BorderSide(
                                              color: kAccentColor,
                                              width: 1.5,
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Swap Options
                              if (_hasRefreshedStatus &&
                                  !_isVehicleCompleted &&
                                  !_isPurchasedByCurrentUser &&
                                  _effectiveStatus != 'sold' &&
                                  _effectiveStatus != 'won') ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                    (_hasBuyNowBid ||
                                        _isVehicleCompleted ||
                                        _isCurrentUserSeller ||
                                        _loadingButtonKey == 'swap')
                                        ? null
                                        : () async {
                                      if (_hasSwapOffer) {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SwapOfferStatusScreen(car: widget.car),
                                          ),
                                        );
                                        if (mounted) await _checkBidStatus();
                                      } else {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SwapPurchaseScreen(car: widget.car),
                                          ),
                                        );
                                        if (result == true && mounted) {
                                          setState(() => _loadingButtonKey = 'swap');
                                          try {
                                            await _checkBidStatus();
                                            try {
                                              final bidController =
                                              Get.find<BidController>();
                                              await bidController.fetchMyBids();
                                              await bidController.fetchSwapOffers();
                                            } catch (e) {
                                              print(
                                                  '⚠️ BidController not found, skipping refresh: $e');
                                            }
                                            try {
                                              final homeController =
                                              Get.find<HomePageController>();
                                              await homeController.fetchCars();
                                              await homeController.fetchSellerDashboardData();
                                            } catch (e) {
                                              print(
                                                  '⚠️ HomePageController not found: $e');
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _loadingButtonKey = null);
                                            }
                                          }
                                        }
                                      }
                                    },
                                    icon: _loadingButtonKey == 'swap'
                                        ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                        : Icon(
                                      _hasSwapOffer ? Icons.visibility : Icons.swap_horiz,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _hasSwapOffer ? 'View swap status' : 'Swap Options',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      (_hasBuyNowBid ||
                                          _isVehicleCompleted ||
                                          _isCurrentUserSeller)
                                          ? Colors.grey.shade400
                                          : const Color(0xFFFF9800),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation:
                                      (_hasBuyNowBid ||
                                          _isVehicleCompleted ||
                                          _isCurrentUserSeller)
                                          ? 0
                                          : 2,
                                    ),
                                  ),
                                ),
                              ],
                            ]
                        ),
                      ),
                    ),
                  ]
                ]
            ),
          ),
        )
    );
  }

  // ============ SELLER DETAILS SECTION - EXACTLY LIKE SCREENSHOT ============
  Future<void> _handleContactSeller() async {
    if (!mounted) return;
    setState(() => _loadingButtonKey = 'contactSeller');
    final phoneNumber = widget.car.contactPhone?.trim();
    final hasPhone = phoneNumber != null && phoneNumber.isNotEmpty;
    final hasEmail = widget.car.contactEmail != null && widget.car.contactEmail!.trim().isNotEmpty;
    final parentContext = context;
    final car = widget.car;

    if (mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.white,
        builder: (sheetContext) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Text(
                'Seller details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
              const SizedBox(height: 16),

              // Seller Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    // Seller Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: kAccentColor.withOpacity(0.1),
                      child: Text(
                        (widget.car.sellerName != null && widget.car.sellerName!.isNotEmpty)
                            ? widget.car.sellerName!.substring(0, 1).toUpperCase()
                            : 'S',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kAccentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Seller Name and Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.car.sellerName ?? 'Seller',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kBlackColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vehicle Seller',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Phone Number (if available)
              if (hasPhone) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: kAccentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          phoneNumber!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kBlackColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Message Seller Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final sellerId = car.sellerId?.toString();
                    final currentId = _currentUserId ?? await PreferencesHelper.getUserId();
                    if (sellerId == null || sellerId.isEmpty) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Seller info not available.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (currentId != null && currentId == sellerId) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('You cannot message yourself.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    try {
                      final res = await _chatService.getOrCreateConversation(
                        otherUserId: sellerId,
                        relatedType: 'vehicle',
                        relatedId: int.tryParse(car.id),
                      );
                      if (!parentContext.mounted) return;
                      Navigator.push(
                        parentContext,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: res['id'].toString(),
                            otherUserName: (res['other_user'] as Map<String, dynamic>)['name'] as String? ?? 'Seller',
                            otherUserId: sellerId,
                            currentUserId: currentId,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!parentContext.mounted) return;
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceFirst('Exception: ', '')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    'Message Seller',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              // Info Message (if no phone/email)
              if (!hasPhone && !hasEmail) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phone and email not shared by seller. You can request inspection or contact support.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Close Button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (mounted) setState(() => _loadingButtonKey = null);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final phoneUri = Uri.parse('tel:$cleanNumber');

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot make phone call to $phoneNumber'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making phone call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    try {
      final emailUri = Uri.parse(
        'mailto:$email?subject=Inquiry about ${widget.car.year} ${widget.car.make} ${widget.car.model}',
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot send email to $email'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void _showCancelBidDialog() {
    if (_currentBid == null) return;

    final bidId = _currentBid!['id'].toString();
    final bidAmount = _currentBid!['bid_amount'] is int
        ? (_currentBid!['bid_amount'] as int).toDouble()
        : (_currentBid!['bid_amount'] as double? ?? 0.0);

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Bid', style: TextStyle(fontSize: 18)),
        content: Text(
          'Are you sure you want to cancel your bid of \$${bidAmount.toStringAsFixed(0)}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (!mounted) return;
              setState(() => _loadingButtonKey = 'cancelBid');
              try {
                await _bidService.withdrawBid(bidId);
                if (mounted) {
                  await _checkBidStatus();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Bid cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error cancelling bid: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
              if (mounted) {
                setState(() => _loadingButtonKey = null);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
            child: const Text('Yes, Cancel', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}