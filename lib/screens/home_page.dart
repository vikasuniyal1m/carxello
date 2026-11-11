import 'dart:async';
import 'package:carauction/screens/filter_screen.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/utils/timezone_config.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/swap_offer_service.dart';
import 'package:carauction/screens/onboarding_screen.dart';
import 'package:carauction/utils/drawer_menu.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:carauction/screens/vehicle_shipping_screen.dart';
import 'package:carauction/screens/view_report_screen.dart';
import 'package:carauction/screens/transport_tracking_screen.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/screens/purchase_details_screen.dart';
import 'package:carauction/screens/inspection_request_screen.dart';
import 'package:carauction/screens/save_search_screen.dart';
import 'package:carauction/models/saved_search.dart';
import 'package:carauction/screens/valuation_tools_screen.dart';
import 'package:carauction/screens/valuation_report_screen.dart';
import 'package:carauction/screens/list_vehicle_screen.dart';
import 'package:carauction/services/contact_service.dart';
import 'package:carauction/screens/view_matches_screen.dart';
import 'package:carauction/screens/notifications_screen.dart';
import 'package:carauction/controllers/notification_controller.dart';
import 'package:carauction/screens/my_bids_screen.dart';
import 'package:carauction/screens/seller_bid_management_screen.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/controllers/watchlist_controller.dart';
import 'package:carauction/widgets/empty_state_widget.dart';
import 'package:carauction/widgets/auction_countdown_widget.dart';
import 'package:carauction/screens/watchlist_screen.dart';
import 'package:carauction/screens/chat_list_screen.dart';
import 'package:carauction/screens/seller_inspection_requests_screen.dart';
import 'package:carauction/screens/seller_transport_requests_screen.dart';
import 'package:carauction/screens/billing_history_screen.dart';
import 'package:carauction/screens/place_bid_screen.dart';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/utils/image_helper.dart';
import 'package:carauction/screens/buyer_inspection_status_screen.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/controllers/watchlist_controller.dart';
import 'package:carauction/controllers/notification_controller.dart';

// ============ AUTO SYNC SERVICE ============
class AutoSyncService extends GetxService {
  static AutoSyncService get to => Get.find();

  static const int SYNC_INTERVAL = 30;
  static const int NOTIFICATION_CHECK_INTERVAL = 15;

  Timer? _syncTimer;
  Timer? _notificationTimer;

  DateTime _lastFullSync = DateTime.now();
  DateTime _lastNotificationCheck = DateTime.now();

  @override
  void onInit() {
    super.onInit();
    // startAutoSync(); // Disabled - refresh only when data comes from database
  }

  void startAutoSync() {
    // DISABLED: Refresh only when data comes from database, not periodic polling
    stopAutoSync();
    print('✅ AutoSyncService disabled - refresh only when data comes from database');
    // _syncTimer = Timer.periodic(
    //   Duration(seconds: SYNC_INTERVAL),
    //       (timer) => _performFullSync(),
    // );

    // _notificationTimer = Timer.periodic(
    //   Duration(seconds: NOTIFICATION_CHECK_INTERVAL),
    //       (timer) => _checkNotifications(),
    // );

    // print('🔄 AutoSyncService started');
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _notificationTimer?.cancel();
  }

  Future<void> _performFullSync() async {
    try {
      if (Get.isRegistered<HomePageController>()) {
        final homeCtrl = Get.find<HomePageController>();
        if (homeCtrl.isBuyer.value) {
          await homeCtrl.fetchCars();
          await homeCtrl.fetchBuyerDashboardData();
        } else {
          await homeCtrl.fetchCars();
          await homeCtrl.fetchSellerDashboardData();
        }
        if (homeCtrl.isBuyer.value) {
          await homeCtrl.fetchWonVehicles();
          await homeCtrl.fetchPurchaseHistory();
        }
      }

      if (Get.isRegistered<BidController>()) {
        final bidCtrl = Get.find<BidController>();
        await bidCtrl.fetchMyBids();
        await bidCtrl.fetchSwapOffers();
      }

      if (Get.isRegistered<WatchlistController>()) {
        final watchCtrl = Get.find<WatchlistController>();
        await watchCtrl.fetchWatchlist();
      }

      _lastFullSync = DateTime.now();
    } catch (e) {
      print('❌ Auto sync error: $e');
    }
  }

  Future<void> _checkNotifications() async {
    try {
      if (Get.isRegistered<NotificationController>()) {
        final notifCtrl = Get.find<NotificationController>();
        await notifCtrl.fetchNotifications();
      }
      _lastNotificationCheck = DateTime.now();
    } catch (e) {
      print('❌ Notification check error: $e');
    }
  }

  Future<void> triggerManualSync() async {
    await _performFullSync();
  }

  @override
  void onClose() {
    stopAutoSync();
    super.onClose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  double _getCarCardTitleSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.headingSmall;
    }
    return 16.0;
  }

  double _getCarCardLocationSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.textSmall;
    }
    return 11.0;
  }

  double _getCarCardLabelSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.textMedium;
    }
    return 12.0;
  }

  double _getCarCardValueSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.textLarge;
    }
    return 15.0;
  }

  double _getCarCardButtonTextSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.textMedium;
    }
    return 12.0;
  }

  EdgeInsets _getCarCardButtonPadding(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return EdgeInsets.symmetric(
        vertical: ScreenSize.paddingMedium,
        horizontal: ScreenSize.paddingMedium,
      );
    }
    return const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0);
  }

  double _getCarCardImageHeight(BuildContext context) {
    return ScreenSize.carCardImageHeight * 0.7;
  }

  double _getCarCardIconSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.iconMedium;
    }
    return 14.0;
  }

  double _getCarCardSmallIconSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.iconSmall;
    }
    return 12.0;
  }

  double _getTabButtonTextSize(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.textMedium;
    }
    return 12.0;
  }

  EdgeInsets _getTabButtonPadding(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return EdgeInsets.symmetric(
        vertical: ScreenSize.paddingMedium,
        horizontal: ScreenSize.paddingLarge,
      );
    }
    return const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0);
  }

  double _getTabButtonSpacing(BuildContext context) {
    if (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) {
      return ScreenSize.spacingExtraSmall;
    }
    return 2.0;
  }

  double _getAppBarHeight(BuildContext context) {
    if (ResponsiveHelper.isTabletOrIPad(context)) {
      if (ResponsiveHelper.isLargeTablet(context)) {
        return 72.0; // Compact height for large tablets
      } else if (ResponsiveHelper.isIPadDevice(context)) {
        return 68.0; // Compact height for iPads
      } else {
        return 64.0; // Compact height for tablets
      }
    }
    return ResponsiveHelper.appBarHeight(context) * 0.85; // Mobile - keep as is
  }

  double _getAppBarIconSize(BuildContext context) {
    if (ResponsiveHelper.isTabletOrIPad(context)) {
      if (ResponsiveHelper.isLargeTablet(context)) {
        return 28.0; // Responsive icon size for large tablets
      } else if (ResponsiveHelper.isIPadDevice(context)) {
        return 26.0; // Responsive icon size for iPads
      } else {
        return 24.0; // Responsive icon size for tablets
      }
    }
    return 24.0; // Mobile - keep as is
  }

  double _getAppBarTitleSize(BuildContext context) {
    if (ResponsiveHelper.isTabletOrIPad(context)) {
      if (ResponsiveHelper.isLargeTablet(context)) {
        return 22.0; // Compact title size for large tablets
      } else if (ResponsiveHelper.isIPadDevice(context)) {
        return 20.0; // Compact title size for iPads
      } else {
        return 19.0; // Compact title size for tablets
      }
    }
    return 20.0; // Mobile - keep as is
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App', style: TextStyle(fontSize: 16)),
          content: const Text('Do you want to exit the app?', style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(fontSize: 13)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Exit', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  int _selectedIndex = 0;
  late final HomePageController controller;
  late final ScrollController _sellerListingScrollController;
  ScrollController? _upcomingAuctionsScrollController;
  final GlobalKey _mainScrollViewKey = GlobalKey();
  final GlobalKey _buyerVehicleListSectionKey = GlobalKey();
  bool _navigatingToMyBids = false;
  bool _navigatingToWatchlist = false;
  final RxBool _isFirstLoad = true.obs;
  double _savedScrollPosition = 0.0;
  bool _shouldRestoreScroll = false;
  int? _lastFetchedSellerTab;
  String? _selectedSortOption;
  String? _selectedStatFilter; // Track selected stat filter: 'live', 'upcoming', 'total', 'myBids'
  final List<String> _sortOptions = [
    'Price: Low to High',
    'Price: High to Low',
    'Year: Newest First',
    'Year: Oldest First',
    'Reset',
  ];
  final TextEditingController _sellerSearchController = TextEditingController();
  String _sellerSearchQuery = '';
  String _sellerSortKey = 'newest';

  final _contactFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: '+1 012 3456 789');
  final _messageController = TextEditingController();
  String _selectedSubject = 'General Inquiry';
  bool _isSubmittingContact = false;
  final ContactService _contactService = ContactService();
  final TransportService _transportService = TransportService();
  Map<String, bool> _wonVehicleTransportExists = {};

  @override
  void initState() {
    super.initState();
    print('🏠 HomePage initState called');
    try {
      if (Get.isRegistered<HomePageController>()) {
        controller = Get.find<HomePageController>();
      } else {
        controller = Get.put(HomePageController(), permanent: true);
      }
      if (!Get.isRegistered<WatchlistController>()) {
        Get.put(WatchlistController(), permanent: true);
      }
      if (!Get.isRegistered<AutoSyncService>()) {
        Get.put(AutoSyncService(), permanent: true);
      }

      _sellerListingScrollController = ScrollController();
      _upcomingAuctionsScrollController ??= ScrollController();
      _upcomingAuctionsScrollController?.addListener(() {
        if (_upcomingAuctionsScrollController?.hasClients == true) {
          final currentOffset = _upcomingAuctionsScrollController!.offset;
          if (currentOffset > 0) {
            _savedScrollPosition = currentOffset;
          }
        }
      });
      controller.initAnimation(this);

      if (!Get.isRegistered<BidController>()) {
        Get.put(BidController(), permanent: true);
      }

      ever(controller.carList, (_) {
        if (!_isFirstLoad.value && _savedScrollPosition > 0) {
          _shouldRestoreScroll = true;
        }
      });

      _checkUserRole();
    } catch (e) {
      print('❌ Error in HomePage initState: $e');
    }
  }

  Future<void> _checkUserRole() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('user_role')?.toLowerCase();
      if (userRole == 'inspector' && mounted) {
        Get.offAllNamed('/inspector-home');
      } else if (userRole == 'transporter' && mounted) {
        Get.offAllNamed('/transporter-home');
      }
    } catch (e) {
      print('⚠️ Error checking user role: $e');
    }
  }

  Future<void> _loadWonVehiclesTransportStatus() async {
    for (final car in controller.wonVehicles) {
      if (_wonVehicleTransportExists.containsKey(car.id)) continue;
      try {
        final status = await _transportService.getTransportOrder(car.id);
        final hasTransport = status['order'] != null && status['order']['id'] != null;
        if (mounted) setState(() => _wonVehicleTransportExists[car.id] = hasTransport);
      } catch (e) {
        if (mounted) setState(() => _wonVehicleTransportExists[car.id] = false);
      }
    }
  }

  void _scrollToTop() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_upcomingAuctionsScrollController?.hasClients == true) {
        _upcomingAuctionsScrollController!.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
      if (_sellerListingScrollController.hasClients) {
        _sellerListingScrollController.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
      try {
        final scrollContext = _mainScrollViewKey.currentContext;
        if (scrollContext != null) {
          final scrollable = Scrollable.of(scrollContext);
          if (scrollable != null) {
            scrollable.position.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
          }
        }
      } catch (e) {
        print('⚠️ Error scrolling to top: $e');
      }
    });
  }

  void _onExploreNowPressed() {
    if (controller.isBuyer.value) {
      controller.updateSelectedTab(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _buyerVehicleListSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.0);
        }
      });
    } else {
      final ctx = _buyerVehicleListSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.0);
      }
    }
  }

  @override
  void dispose() {
    controller.disposeAnimation();
    _sellerListingScrollController.dispose();
    _upcomingAuctionsScrollController?.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _showExitConfirmation(context);
      },
      child: Scaffold(
        backgroundColor: kWhiteColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: kAccentColor,
          elevation: 0,
          toolbarHeight: _getAppBarHeight(context),
          iconTheme: IconThemeData(color: Colors.white, size: _getAppBarIconSize(context)),
          title: Text(
            _selectedIndex == 1 ? 'About Us' : _selectedIndex == 2 ? 'Contact Us' : 'CarXello',
            style: TextStyle(fontSize: _getAppBarTitleSize(context), color: kWhiteColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: ResponsiveHelper.isTabletOrIPad(context),
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, size: _getAppBarIconSize(context)),
              padding: EdgeInsets.all(ResponsiveHelper.isTabletOrIPad(context) ? 8.0 : 4.0),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            GetBuilder<NotificationController>(
              builder: (notificationController) => Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications, size: _getAppBarIconSize(context)),
                    color: Colors.white,
                    padding: EdgeInsets.all(ResponsiveHelper.isTabletOrIPad(context) ? 8.0 : 4.0),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                  ),
                  Obx(() => notificationController.unreadCount.value > 0
                      ? Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        notificationController.unreadCount.value > 99 ? '99+' : '${notificationController.unreadCount.value}',
                        style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
        drawer: DrawerMenu(
          selectedIndex: _selectedIndex,
          controller: controller,
          onItemSelected: (index) {
            setState(() => _selectedIndex = index);
            if (index == 4) {
              AuthService().logout().then((_) {
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              });
            }
          },
        ),
        body: Obx(() {
          if (controller.isLoading.value && _isFirstLoad.value) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(height: 12),
                  Text('Loading...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          return SafeArea(
            child: _selectedIndex == 1 ? _buildAboutUsContent()
                : _selectedIndex == 2 ? _buildContactUsContent()
                : Obx(() => controller.isBuyer.value ? _buildCompactBuyerContent() : _buildCompactSellerContent()),
          );
        }),
      ),
    );
  }

  // ============ COMPACT BUYER CONTENT ============
  Widget _buildCompactBuyerContent() {
    return Obx(() {
      final showPinnedActionBar = controller.isBuyer.value && controller.selectedTab.value == 0;
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          controller.scrollOffset.value = scrollInfo.metrics.pixels;
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshCars();
            await controller.fetchBuyerDashboardData();
            await AutoSyncService.to.triggerManualSync();
          },
          color: kAccentColor,
          child: CustomScrollView(
            key: _mainScrollViewKey,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildCompactCarousel()),
              SliverToBoxAdapter(child: _buildCompactTabSection()),
              SliverToBoxAdapter(child: _buildCompactWelcomeMessage()),
              if (showPinnedActionBar)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedActionBarDelegate(
                    minExtent: 48,
                    maxExtent: 48,
                    child: Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: _buildCompactActionBar(),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  key: _buyerVehicleListSectionKey,
                  child: _buildBuyerContent(),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ============ COMPACT SELLER CONTENT ============
  Widget _buildCompactSellerContent() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        controller.scrollOffset.value = scrollInfo.metrics.pixels;
        return false;
      },
      child: Obx(() {
        // Manage bids uses a CustomScrollView internally and must be height-bounded.
        if (controller.selectedSellerTab.value == 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactCarousel(),
              _buildCompactSellerTabSection(),
              Expanded(child: _buildSellerTabContent()),
            ],
          );
        }
        return SingleChildScrollView(
          controller: _sellerListingScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactCarousel(),
              _buildCompactSellerTabSection(),
              _buildSellerTabContent(),
            ],
          ),
        );
      }),
    );
  }

  // ============ COMPACT CAROUSEL ============
  Widget _buildCompactCarousel() {
    return Obx(() {
      return Stack(
        children: [
          CarouselSlider(
            carouselController: controller.carouselController,
            options: CarouselOptions(
              height: ResponsiveHelper.isMobile(context) ? 160 : 200,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 3),
              autoPlayAnimationDuration: const Duration(milliseconds: 600),
              autoPlayCurve: Curves.easeInOut,
              aspectRatio: 16 / 9,
              enlargeCenterPage: true,
              viewportFraction: 1.0,
              onPageChanged: (index, reason) => controller.updateCarouselIndex(index),
            ),
            items: controller.imgList.map((item) => Builder(
              builder: (context) => Container(
                width: ScreenSize.screenWidth,
                decoration: BoxDecoration(
                  image: DecorationImage(image: AssetImage(item), fit: BoxFit.cover),
                ),
              ),
            )).toList(),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.30),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(
                  '${controller.currentCarouselIndex.value + 1}/${controller.imgList.length} Special Offers',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                )),
                const SizedBox(height: 4),
                Text(
                  controller.isBuyer.value ? 'Drive your dream car' : 'Sell your vehicle',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            right: 16,
            child: ElevatedButton(
              onPressed: _onExploreNowPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.isBuyer.value ? kAccentColor : Colors.orange,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(80, 30),
              ),
              child: const Text('Explore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    });
  }

  // ============ COMPACT TAB SECTION ============
  Widget _buildCompactTabSection() {
    return Obx(() => controller.isBuyer.value
        ? Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildCompactTabButton('Upcoming', 0),
            _buildCompactTabButton('My Bids', 4),
            _buildCompactTabButton('Won', 1),
            _buildCompactTabButton('History', 2),
            _buildCompactTabButton('Saved', 3),
            _buildCompactTabButton('Watchlist', 5),
          ],
        ),
      ),
    )
        : const SizedBox.shrink());
  }

  // ============ COMPACT SELLER TAB SECTION ============
  Widget _buildCompactSellerTabSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildCompactSellerTabButton('Home', 0),
            _buildCompactSellerTabButton('Listing', 1),
            _buildCompactSellerTabButton('Manage bids', 2),
            _buildCompactSellerTabButton('Inventory', 3),
            _buildCompactSellerTabButton('Analytics', 4),
          ],
        ),
      ),
    );
  }

  // ============ COMPACT TAB BUTTON ============
  Widget _buildCompactTabButton(String title, int index) {
    return Obx(() {
      final isSelected = controller.selectedTab.value == index;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedStatFilter = null; // Reset filter when tab changes
              });
              final prevTab = controller.selectedTab.value;
              controller.updateSelectedTab(index);
              // Coming back to Upcoming from My Bids etc. — reload bids so "Update Bid" matches inner screens
              if (controller.isBuyer.value && index == 0 && prevTab != 0) {
                try {
                  Get.find<BidController>().fetchMyBids();
                } catch (_) {}
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? kAccentColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: kAccentColor.withOpacity(0.3)),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  // ============ COMPACT SELLER TAB BUTTON ============
  Widget _buildCompactSellerTabButton(String title, int index) {
    return Obx(() {
      final isSelected = controller.selectedSellerTab.value == index;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => controller.updateSelectedSellerTab(index),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? kAccentColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: kAccentColor.withOpacity(0.3)),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  // ============ COMPACT ACTION BAR ============
  Widget _buildCompactActionBar() {
    return Obx(() => controller.isBuyer.value && controller.selectedTab.value == 0
        ? Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickFilterChip(label: 'Filters', icon: Icons.filter_alt_outlined, sectionIndex: 1, highlighted: true),
            _buildQuickFilterChip(label: 'Sort by', icon: Icons.sort, sectionIndex: 0),
            _buildQuickFilterChip(label: 'Price', icon: Icons.attach_money, sectionIndex: 2, highlighted: true),
            _buildQuickFilterChip(label: 'Make', icon: Icons.directions_car_outlined, sectionIndex: 1),
            _buildQuickFilterChip(label: 'Year', icon: Icons.calendar_month_outlined, sectionIndex: 3),
            _buildQuickFilterChip(label: 'Condition', icon: Icons.thumb_up_alt_outlined, sectionIndex: 4),
            _buildQuickFilterChip(label: 'Title', icon: Icons.description_outlined, sectionIndex: 5),
            _buildQuickFilterChip(label: 'Fuel', icon: Icons.local_gas_station_outlined, sectionIndex: 6),
            _buildQuickFilterChip(label: 'Engine', icon: Icons.engineering_outlined, sectionIndex: 7),
            _buildQuickFilterChip(label: 'Drive', icon: Icons.settings_outlined, sectionIndex: 8),
            _buildQuickFilterChip(label: 'Kms', icon: Icons.speed_outlined, sectionIndex: 9),
            _buildQuickFilterChip(label: 'Color', icon: Icons.palette_outlined, sectionIndex: 10),
            _buildQuickFilterChip(label: 'Location', icon: Icons.location_on_outlined, sectionIndex: 11),
            _buildQuickFilterChip(label: 'Value', icon: Icons.menu_book_outlined, sectionIndex: 12),
            _buildQuickFilterChip(label: 'Status', icon: Icons.info_outline, sectionIndex: 13),
            _buildQuickFilterChip(label: 'Misc', icon: Icons.tune_outlined, sectionIndex: 14),
          ],
        ),
      ),
    )
        : Container());
  }

  Widget _buildQuickFilterChip({
    required String label,
    required IconData icon,
    required int sectionIndex,
    bool highlighted = false,
  }) {
    final activeCount = _getActiveFilterCount();
    final isFiltersTab = label == 'Filters';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFilterBottomSheet(context, initialSection: sectionIndex),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: highlighted ? kAccentColor.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highlighted ? kAccentColor : Colors.grey[300]!,
                width: highlighted ? 1.5 : 1,
              ),
              boxShadow: highlighted ? [
                BoxShadow(color: kAccentColor.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: highlighted ? kAccentColor : Colors.black54),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                    color: highlighted ? kAccentColor : Colors.black87,
                  ),
                ),
                if (isFiltersTab && activeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: kAccentColor, shape: BoxShape.circle),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ COMPACT WELCOME MESSAGE ============
  Widget _buildCompactWelcomeMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.isBuyer.value ? 'Welcome Back!' : 'Welcome Seller!',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAccentColor),
          ),
          const SizedBox(height: 2),
          Text(
            controller.isBuyer.value ? 'Discover amazing vehicles' : 'Manage your listings',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ============ BUYER STATS CARDS ============
  Widget _buildBuyerStatsCards() {
    return Obx(() {
      if (!controller.isBuyer.value || controller.selectedTab.value != 0) {
        return const SizedBox.shrink();
      }

      final isTablet = ResponsiveHelper.isTabletOrIPad(context);
      final carList = controller.carList;
      final liveCars = carList.where((car) => 
        (car.status.toLowerCase() == 'live' || car.status.toLowerCase() == 'active') &&
        car.auctionEndTime.isAfter(DateTime.now())
      ).toList();
      final upcomingCars = carList.where((car) => 
        car.auctionEndTime.isAfter(DateTime.now()) &&
        !(car.status.toLowerCase() == 'live' || car.status.toLowerCase() == 'active')
      ).toList();
      
      // Get my bids count
      int myBidsCount = 0;
      try {
        final bidController = Get.find<BidController>();
        myBidsCount = bidController.myBids.length;
      } catch (_) {}

      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedStatFilter == 'live') {
                      _selectedStatFilter = null; // Toggle off if already selected
                    } else {
                      _selectedStatFilter = 'live';
                    }
                  });
                },
                child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  title: 'Live',
                  value: liveCars.length.toString(),
                  color: Colors.green,
                  isTablet: isTablet,
                  isSelected: _selectedStatFilter == 'live',
                ),
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedStatFilter == 'upcoming') {
                      _selectedStatFilter = null; // Toggle off if already selected
                    } else {
                      _selectedStatFilter = 'upcoming';
                    }
                  });
                },
                child: _buildStatCard(
                  icon: Icons.upcoming,
                  title: 'Upcoming',
                  value: upcomingCars.length.toString(),
                  color: Colors.blue,
                  isTablet: isTablet,
                  isSelected: _selectedStatFilter == 'upcoming',
                ),
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedStatFilter == 'total') {
                      _selectedStatFilter = null; // Toggle off if already selected
                    } else {
                      _selectedStatFilter = 'total';
                    }
                  });
                },
                child: _buildStatCard(
                  icon: Icons.directions_car,
                  title: 'Total',
                  value: carList.length.toString(),
                  color: kAccentColor,
                  isTablet: isTablet,
                  isSelected: _selectedStatFilter == 'total',
                ),
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Navigate to My Bids tab
                  controller.updateSelectedTab(4);
                  setState(() {
                    _selectedStatFilter = null; // Reset filter when navigating
                  });
                },
                child: _buildStatCard(
                  icon: Icons.gavel,
                  title: 'My Bids',
                  value: myBidsCount.toString(),
                  color: Colors.orange,
                  isTablet: isTablet,
                  isSelected: false, // Don't show selected for My Bids as it navigates
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isTablet,
    bool isSelected = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isTablet ? 24 : 20),
          SizedBox(height: isTablet ? 6 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: isTablet ? 2 : 1),
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 11 : 10,
              color: Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============ COMPACT SORT BOTTOM SHEET ============
  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ..._sortOptions.map((option) => ListTile(
              title: Text(option, style: const TextStyle(fontSize: 13)),
              leading: Icon(
                option == 'Reset' ? Icons.restart_alt : Icons.sort,
                size: 16,
                color: option == 'Reset' ? Colors.grey : kAccentColor,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                final selected = option == 'Reset' ? null : option;
                // Update local UI sort selection and controller preference,
                // but do NOT refetch here (keeps the full list visible).
                setState(() => _selectedSortOption = selected);
                controller.currentSortBy = selected;
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerContent() {
    return Obx(() {
      if (controller.isLoading.value && controller.selectedTab.value == 0) {
        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
      } else if (controller.isLoadingWonVehicles.value && controller.selectedTab.value == 1) {
        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
      } else if (controller.isLoadingPurchaseHistory.value && controller.selectedTab.value == 2) {
        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
      } else {
        if (controller.selectedTab.value == 2) return _buildPurchaseHistoryContent();
        if (controller.selectedTab.value == 3) return _buildSavedSearchesContent();

        if (controller.selectedTab.value == 5) {
          if (!_navigatingToWatchlist) {
            _navigatingToWatchlist = true;
            Future.microtask(() {
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WatchlistScreen())).then((_) {
                  controller.updateSelectedTab(0);
                  _navigatingToWatchlist = false;
                });
              } else {
                _navigatingToWatchlist = false;
              }
            });
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.selectedTab.value == 4) {
          if (!_navigatingToMyBids) {
            _navigatingToMyBids = true;
            Future.microtask(() {
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MyBidsScreen())).then((_) {
                  controller.updateSelectedTab(0);
                  _navigatingToMyBids = false;
                });
              }
            });
          }
          return const Center(child: CircularProgressIndicator());
        }

        final filteredCarList = _getFilteredCarList();
        if (filteredCarList.isEmpty) {
          String emptyMessage = 'No cars available';
          if (controller.selectedTab.value == 1) emptyMessage = 'No won vehicles yet.';
          else if (controller.selectedTab.value == 2) emptyMessage = 'No purchase history yet.';

          return EmptyStateWidget(
            type: controller.selectedTab.value == 2 ? EmptyStateType.emptyPurchaseHistory
                : controller.selectedTab.value == 1 ? EmptyStateType.emptyWonVehicles
                : EmptyStateType.emptyCars,
            title: controller.selectedTab.value == 2 ? 'No Purchase History'
                : controller.selectedTab.value == 1 ? 'No Won Vehicles'
                : 'No Vehicles Available',
            message: emptyMessage,
            actionButton: controller.selectedTab.value == 0
                ? ElevatedButton.icon(
              onPressed: () => controller.refreshCars(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            )
                : null,
          );
        } else {
          if (controller.selectedTab.value == 0) {
            _upcomingAuctionsScrollController ??= ScrollController();

            if (_shouldRestoreScroll && _savedScrollPosition > 0) {
              _shouldRestoreScroll = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_upcomingAuctionsScrollController?.hasClients == true) {
                  final currentOffset = _upcomingAuctionsScrollController!.offset;
                  if (currentOffset < 50 && _savedScrollPosition > 50) {
                    _upcomingAuctionsScrollController!.jumpTo(_savedScrollPosition);
                  }
                }
              });
            }

            return RefreshIndicator(
              onRefresh: () async {
                final scrollPosition = _upcomingAuctionsScrollController?.hasClients == true ? _upcomingAuctionsScrollController!.offset : 0.0;
                await controller.refreshCars();
                try {
                  final bidCtrl = Get.find<BidController>();
                  await bidCtrl.fetchMyBids();
                } catch (_) {}
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_upcomingAuctionsScrollController?.hasClients == true && scrollPosition > 0) {
                    _upcomingAuctionsScrollController!.jumpTo(scrollPosition);
                  }
                });
              },
              child: _buildResponsiveCarList(
                carList: filteredCarList,
                selectedTab: controller.selectedTab.value,
                controller: _upcomingAuctionsScrollController,
              ),
            );
          } else {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCarList.length,
              itemBuilder: (context, index) => _buildCarCard(filteredCarList[index], controller.selectedTab.value, controller),
            );
          }
        }
      }
    });
  }

  Widget _buildSavedSearchesContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SaveSearchScreen()));
                  if (result != null && result is SavedSearch) await controller.addSavedSearch(result);
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create New Search', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),
          Obx(() {
            if (controller.savedSearches.isEmpty) {
              return EmptyStateWidget(
                type: EmptyStateType.emptySavedSearches,
                title: 'No Saved Searches',
                message: 'Create your first search to get started!',
                actionButton: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SaveSearchScreen())),
                  icon: const Icon(Icons.search),
                  label: const Text('Create Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.savedSearches.length,
              itemBuilder: (context, index) {
                final search = controller.savedSearches[index];
                final car = Car(
                  id: search.id,
                  make: search.make ?? 'Any Make',
                  model: search.model ?? 'Any Model',
                  year: search.yearFrom ?? 0,
                  imageUrl: 'assets/images/car1.png',
                  startingBid: 0,
                  buyNowPrice: 0,
                  mileage: 0,
                  location: '',
                  distance: '',
                  auctionEndTime: DateTime.now(),
                  status: 'active',
                  description: search.getDescription().isEmpty ? search.searchName : search.getDescription(),
                  lastMatch: search.lastMatch ?? 'Never',
                  currentMatches: search.currentMatches,
                  alerts: search.enableEmailAlerts,
                );
                return _buildSavedSearchCard(car, controller.selectedTab.value, search);
              },
            );
          }),
        ],
      ),
    );
  }

  // ============ UPDATED PURCHASE HISTORY CONTENT ============
  Widget _buildPurchaseHistoryContent() {
    return Obx(() {
      if (controller.isLoadingPurchaseHistory.value && controller.purchaseHistory.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (controller.purchaseHistory.isEmpty) {
        return EmptyStateWidget(
          type: EmptyStateType.emptyPurchaseHistory,
          title: 'No Purchase History',
          message: 'You haven\'t purchased any vehicles yet.',
          actionButton: ElevatedButton.icon(
            onPressed: () => controller.refreshCars(),
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: controller.purchaseHistory.length,
        itemBuilder: (context, index) {
          final car = controller.purchaseHistory[index];
          return _buildCompactPurchaseHistoryCard(car);
        },
      );
    });
  }

  Widget _buildCompactPurchaseHistoryCard(Car car) {
    // Determine purchase method
    String purchaseMethod = 'bidding';
    if (car.purchaseMethod != null) {
      purchaseMethod = car.purchaseMethod!;
    } else if (car.status == 'buy_now') {
      purchaseMethod = 'buy_now';
    }

    final methodColor = _getPurchaseMethodColor(purchaseMethod);
    final methodIcon = _getPurchaseMethodIcon(purchaseMethod);
    final methodLabel = _getPurchaseMethodLabel(purchaseMethod);

    // Get inspection status
    String inspectionStatus = _getInspectionStatusDisplay(car.inspectionStatus);
    Color inspectionColor = _getStatusColor(inspectionStatus);
    bool hasInspectionRequest = inspectionStatus != 'Not yet';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseDetailsScreen(car: car),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // Top row with method badge and inspection status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Purchase Method Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: methodColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: methodColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          methodIcon,
                          size: 10,
                          color: methodColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          methodLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: methodColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Inspection Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: inspectionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: inspectionColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasInspectionRequest ? Icons.verified_user : Icons.pending,
                          size: 10,
                          color: inspectionColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          inspectionStatus,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: inspectionColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Car image and details
              Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCarImage(
                      car.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${car.year} ${car.make} ${car.model}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Price
                        Text(
                          '\$${_formatNumberWithCommas(car.purchaseAmount ?? car.price ?? car.startingBid)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: methodColor,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Status chips
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildStatusChip(
                              label: 'Vin: ${car.vin ?? 'N/A'}',
                              color: Colors.grey,
                            ),
                            if (car.expectedDeliveryDate != null)
                              _buildStatusChip(
                                label: 'Delivery: ${_formatShortDate(car.expectedDeliveryDate!)}',
                                color: Colors.blue,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PurchaseDetailsScreen(car: car),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccentColor,
                        side: const BorderSide(color: kAccentColor),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // INSPECTION BUTTON - WITH CONDITION
                  Expanded(
                    child: hasInspectionRequest
                        ? OutlinedButton(
                      onPressed: () async {
                        try {
                          final service = InspectionService();
                          final result = await service.getVehicleInspection(car.id);
                          final initial = result['inspection'] as Map<String, dynamic>?;
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BuyerInspectionStatusScreen(car: car, initialInspection: initial),
                              ),
                            );
                          }
                        } catch (e) {
                          _showInspectionDetails(car);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: inspectionColor,
                        side: BorderSide(color: inspectionColor),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 12,
                            color: inspectionColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: inspectionColor,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InspectionRequestScreen(car: car),
                          ),
                        ).then((_) {
                          // Refresh after returning
                          controller.fetchPurchaseHistory();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Request',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  /*Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice downloading...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(
                        Icons.download_outlined,
                        size: 14,
                      ),
                    ),
                  ),*/
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Add this helper function to show inspection details
  void _showInspectionDetails(Car car) {
    final navContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.verified_user,
              size: 20,
              color: _getStatusColor(_getInspectionStatusDisplay(car.inspectionStatus)),
            ),
            const SizedBox(width: 8),
            const Text(
              'Inspection Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Vehicle', '${car.year} ${car.make} ${car.model}'),
            const SizedBox(height: 8),
            _buildDetailRow('Status', _getInspectionStatusDisplay(car.inspectionStatus)),
            // const SizedBox(height: 8),
            // if (car.inspectionDate != null)
            //   _buildDetailRow('Date', _formatDate(car.inspectionDate!)),
            // if (car.inspectorName != null)
            //   _buildDetailRow('Inspector', car.inspectorName!),
            const SizedBox(height: 12),
            if (car.inspectionStatus == 'completed' || car.inspectionStatus == 'approved')
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vehicle has been inspected and approved',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(fontSize: 13)),
          ),
          if (car.inspectionStatus == 'completed' || car.inspectionStatus == 'approved')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  navContext,
                  MaterialPageRoute(
                    builder: (context) => ViewReportScreen(car: car),
                  ),
                );
              },
              child: const Text(
                'View Report',
                style: TextStyle(color: kAccentColor, fontSize: 13),
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
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
  // ============ NEW COMPACT PURCHASE HISTORY CARD ============
 /* Widget _buildCompactPurchaseHistoryCard(Car car) {
    // Determine purchase method (you might need to adjust this based on your data)
    String purchaseMethod = 'bidding'; // default
    if (car.purchaseMethod != null) {
      purchaseMethod = car.purchaseMethod!;
    } else if (car.status == 'buy_now') {
      purchaseMethod = 'buy_now';
    }

    final methodColor = _getPurchaseMethodColor(purchaseMethod);
    final methodIcon = _getPurchaseMethodIcon(purchaseMethod);
    final methodLabel = _getPurchaseMethodLabel(purchaseMethod);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseDetailsScreen(car: car),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // Top row with method badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: methodColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: methodColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          methodIcon,
                          size: 10,
                          color: methodColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          methodLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: methodColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(car.auctionEndTime),
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Car image and details
              Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCarImage(
                      car.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${car.year} ${car.make} ${car.model}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Price
                        Text(
                          '\$${_formatNumberWithCommas(car.purchaseAmount ?? car.price ?? car.startingBid)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: methodColor,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Status chips
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildStatusChip(
                              label: 'Vin: ${car.vin ?? 'N/A'}',
                              color: Colors.grey,
                            ),
                            if (car.expectedDeliveryDate != null)
                              _buildStatusChip(
                                label:
                                'Delivery: ${_formatShortDate(car.expectedDeliveryDate!)}',
                                color: Colors.blue,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PurchaseDetailsScreen(car: car),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccentColor,
                        side: const BorderSide(color: kAccentColor),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InspectionRequestScreen(car: car),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Inspect',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),
*//*
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Show invoice/download option
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice downloading...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(
                        Icons.download_outlined,
                        size: 14,
                      ),
                    ),
                  ),*//*
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }*/

  // ============ HELPER FUNCTION FOR DATE FORMATTING ============
  String _formatShortDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // ============ HELPER FUNCTION FOR STATUS CHIP ============
  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Car> _getFilteredCarList() {
    switch (controller.selectedTab.value) {
      case 0:
        final now = DateTime.now();
        // Default Home list (before sort/filter):
        // - include all normal listings (don't over-filter by status)
        // - only hide auctions that are already ended for live/active items
        // This keeps Home's vehicle count stable, while sort/filter only reorders or filters.
        var fromCarList = controller.carList.where((car) {
          final status = car.status.toLowerCase();

          // Hide auctions that already ended for live/active items.
          if (status == 'active' || status == 'live') {
            try {
              return car.auctionEndTime.isAfter(now);
            } catch (_) {
              return false;
            }
          }

          // For other statuses (sold/won/upcoming/etc), keep them visible.
          return true;
        }).toList();

        // Apply stat filter if selected
        if (_selectedStatFilter != null) {
          if (_selectedStatFilter == 'live') {
            // Filter for live auctions only
            fromCarList = fromCarList
                .where((car) =>
                    (car.status.toLowerCase() == 'live' || car.status.toLowerCase() == 'active') &&
                    car.auctionEndTime.isAfter(now))
                .toList();
          } else if (_selectedStatFilter == 'upcoming') {
            // Filter for upcoming auctions only (not live yet)
            fromCarList = fromCarList
                .where((car) =>
                    car.auctionEndTime.isAfter(now) &&
                    !(car.status.toLowerCase() == 'live' || car.status.toLowerCase() == 'active'))
                .toList();
          } else if (_selectedStatFilter == 'total') {
            // Show all cars (no additional filtering)
            // fromCarList remains as is
          } else if (_selectedStatFilter == 'myBids') {
            // Filter cars where user has placed bids
            try {
              final bidController = Get.find<BidController>();
              final bidVehicleIds = bidController.myBids
                  .map((bid) => bid['vehicle_id']?.toString() ?? bid['vehicleId']?.toString())
                  .where((id) => id != null)
                  .toSet();
              fromCarList = fromCarList
                  .where((car) => bidVehicleIds.contains(car.id.toString()))
                  .toList();
            } catch (_) {
              // If BidController not found, return empty list
              fromCarList = [];
            }
          }
        }

        // Merge won vehicles into the list (so Home matches previous behavior).
        final seenIds = fromCarList.map((c) => c.id.toString()).toSet();
        for (final won in controller.wonVehicles) {
          final id = won.id.toString();
          if (id.isNotEmpty && !seenIds.contains(id)) {
            seenIds.add(id);
            fromCarList.add(won);
          }
        }

        final wonById = <String, Car>{};
        for (final w in controller.wonVehicles) {
          wonById[w.id.toString()] = w;
        }
        fromCarList = fromCarList.map((car) => wonById[car.id.toString()] ?? car).toList();

        // Apply client-side filtering for supported fields.
        // This guarantees filtering works even if backend doesn't support some keys.
        final localFilters = controller.currentFilters;
        if (localFilters != null && localFilters.isNotEmpty) {
          int? _parseInt(dynamic v) {
            if (v == null) return null;
            final s = v.toString().trim();
            if (s.isEmpty) return null;
            return int.tryParse(s);
          }

          double? _parseDouble(dynamic v) {
            if (v == null) return null;
            final s = v.toString().trim();
            if (s.isEmpty) return null;
            return double.tryParse(s);
          }

          String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
          bool _containsCI(String? a, String? b) {
            if (a == null || b == null) return false;
            return a.toLowerCase().contains(b.toLowerCase());
          }

          bool _matchStringCI(String? a, String? b) {
            if (a == null || b == null) return false;
            return a.toLowerCase() == b.toLowerCase();
          }

          List<String> _splitTokens(dynamic raw) {
            if (raw == null) return const [];
            final s = raw.toString().trim();
            if (s.isEmpty) return const [];
            // Allow multi-value filters like "Toyota,Honda" or "10|20"
            return s
                .split(RegExp(r'[,\n;|/]+'))
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
          }

          final minYear = _parseInt(localFilters['year_min']);
          final maxYear = _parseInt(localFilters['year_max']);
          final makeTokens = _splitTokens(localFilters['make']);
          final modelTokens = _splitTokens(localFilters['model']);
          final minPrice = _parseDouble(localFilters['price_min']);
          final maxPrice = _parseDouble(localFilters['price_max']);
          final minOdo = _parseInt(localFilters['odometer_min']);
          final maxOdo = _parseInt(localFilters['odometer_max']);
          final fuelTokens = _splitTokens(localFilters['fuel_type']);
          final exteriorColorTokens = _splitTokens(localFilters['exterior_color']);
          final interiorColorTokens = _splitTokens(localFilters['interior_color']);
          final driveTrainTokens = _splitTokens(localFilters['drive_train']);
          final locationZipTokens = _splitTokens(localFilters['location_zip']);
          final radius = _parseDouble(localFilters['radius']);

          fromCarList = fromCarList.where((car) {
            if (minYear != null && car.year < minYear) return false;
            if (maxYear != null && car.year > maxYear) return false;

            if (makeTokens.isNotEmpty) {
              final cm = car.make.toLowerCase();
              final ok = makeTokens.any((t) => cm.contains(t.toLowerCase()));
              if (!ok) return false;
            }
            if (modelTokens.isNotEmpty) {
              final cm = car.model.toLowerCase();
              final ok = modelTokens.any((t) => cm.contains(t.toLowerCase()));
              if (!ok) return false;
            }

            double priceForFilter = car.startingBid;
            if (car.buyNowPrice > 0) priceForFilter = car.buyNowPrice;
            if (car.price != null && car.price! > 0) priceForFilter = car.price!;

            if (minPrice != null && priceForFilter < minPrice) return false;
            if (maxPrice != null && priceForFilter > maxPrice) return false;

            if (minOdo != null && car.mileage < minOdo) return false;
            if (maxOdo != null && car.mileage > maxOdo) return false;

            if (fuelTokens.isNotEmpty) {
              final ct = car.fuelType?.toLowerCase().trim();
              // If API didn't return fuelType, don't over-filter client-side.
              if (ct != null && ct.isNotEmpty) {
                final ok = fuelTokens.any((t) => ct == t.toLowerCase().trim());
                if (!ok) return false;
              }
            }
            final wantExterior = exteriorColorTokens.isNotEmpty;
            final wantInterior = interiorColorTokens.isNotEmpty;
            if (wantExterior || wantInterior) {
              final hasAnyColorField = (car.exteriorColor != null && car.exteriorColor!.isNotEmpty) ||
                  (car.interiorColor != null && car.interiorColor!.isNotEmpty);

              if (!hasAnyColorField) {
                // skip color constraint
              } else {
                final carExterior = car.exteriorColor?.toLowerCase().trim() ?? '';
                final carInterior = car.interiorColor?.toLowerCase().trim() ?? '';

                final exteriorOk = wantExterior &&
                    exteriorColorTokens.any((t) => carExterior.contains(t.toLowerCase().trim()));
                final interiorOk = wantInterior &&
                    interiorColorTokens.any((t) => carInterior.contains(t.toLowerCase().trim()));

                if (!(exteriorOk || interiorOk)) return false;
              }
            }

            if (driveTrainTokens.isNotEmpty) {
              final dc = car.driveTrain?.toLowerCase().trim();
              if (dc != null && dc.isNotEmpty) {
                final ok = driveTrainTokens.any((t) => dc.contains(t.toLowerCase().trim()) || t.toLowerCase().trim().contains(dc));
                if (!ok) return false;
              }
            }

            if (locationZipTokens.isNotEmpty) {
              final carZip = _digitsOnly(car.location);
              if (carZip.isNotEmpty) {
                final wantZips = locationZipTokens
                    .map((z) => _digitsOnly(z))
                    .where((z) => z.isNotEmpty)
                    .toList();
                if (wantZips.isNotEmpty && !wantZips.contains(carZip)) return false;
              }
            }

            if (radius != null && radius > 0) {
              final distStr = car.distance;
              if (distStr.isEmpty) {
                // Can't evaluate distance from API/DB; don't over-filter.
              } else {
                final distNumStr = _digitsOnly(distStr);
                final dist = double.tryParse(distNumStr);
                if (dist != null && dist > radius) return false;
              }
            }

            return true;
          }).toList();
        }

        // Apply local sort so the UI reorders immediately based on selection.
        // Sorting happens only when user selected an option (otherwise keep original order).
        final sortOption = _selectedSortOption;
        if (sortOption != null) {
          fromCarList = List<Car>.from(fromCarList);
          double _displayBidPrice(Car c) {
            // Card UI displays starting bid, so sort by the same value.
            if (c.startingBid > 0) return c.startingBid;
            // fallback only when starting bid missing
            if (c.currentBid != null && c.currentBid! > 0) return c.currentBid!;
            if (c.buyNowPrice > 0) return c.buyNowPrice;
            if (c.price != null && c.price! > 0) return c.price!;
            return 0;
          }

          fromCarList.sort((a, b) {
            switch (sortOption) {
              case 'Price: Low to High': {
                final v = _displayBidPrice(a).compareTo(_displayBidPrice(b));
                if (v != 0) return v;
                final y = b.year.compareTo(a.year);
                if (y != 0) return y;
                return a.id.compareTo(b.id);
              }
              case 'Price: High to Low': {
                final v = _displayBidPrice(b).compareTo(_displayBidPrice(a));
                if (v != 0) return v;
                final y = b.year.compareTo(a.year);
                if (y != 0) return y;
                return a.id.compareTo(b.id);
              }
              case 'Year: Newest First':
                {
                  final y = b.year.compareTo(a.year);
                  if (y != 0) return y;
                  final p = _displayBidPrice(b).compareTo(_displayBidPrice(a));
                  if (p != 0) return p;
                  return a.id.compareTo(b.id);
                }
              case 'Year: Oldest First':
                {
                  final y = a.year.compareTo(b.year);
                  if (y != 0) return y;
                  final p = _displayBidPrice(a).compareTo(_displayBidPrice(b));
                  if (p != 0) return p;
                  return a.id.compareTo(b.id);
                }
              default:
                return 0;
            }
          });
        }

        return fromCarList;
      case 1:
        _loadWonVehiclesTransportStatus();
        if (controller.isLoadingWonVehicles.value && controller.wonVehicles.isEmpty) return [];
        return controller.wonVehicles;
      case 2:
        return controller.purchaseHistory;
      case 3:
        return [];
      default:
        return [];
    }
  }

  Widget _buildBidTile(dynamic bid) {
    final vehicle = bid['vehicle'] as Map<String, dynamic>?;
    final imageUrl = vehicle?['imageUrl'] as String? ?? vehicle?['image_url'] as String? ?? 'assets/images/car1.png';
    final title = vehicle != null ? '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim() : 'Vehicle';
    final yourBid = (bid['bid_amount'] is int) ? (bid['bid_amount'] as int).toDouble() : (bid['bid_amount'] as double? ?? 0.0);
    final currentBid = vehicle?['current_bid'] is int ? (vehicle?['current_bid'] as int).toDouble() : (vehicle?['current_bid'] as double?);

    return InkWell(
      onTap: vehicle != null ? () {
        try {
          final endStr = vehicle['auction_end_time'] as String?;
          final endTime = endStr != null ? DateTime.parse(endStr) : DateTime.now().add(const Duration(days: 7));
          final startingBid = (vehicle['startingBid'] is num) ? (vehicle['startingBid'] as num).toDouble()
              : (vehicle['starting_bid'] is num) ? (vehicle['starting_bid'] as num).toDouble() : 0.0;
          final buyNowPrice = (vehicle['buyNowPrice'] is num) ? (vehicle['buyNowPrice'] as num).toDouble()
              : (vehicle['buy_now_price'] is num) ? (vehicle['buy_now_price'] as num).toDouble() : 0.0;
          final mileage = (vehicle['mileage'] is int) ? vehicle['mileage'] as int
              : ((vehicle['mileage'] is String) ? int.tryParse(vehicle['mileage']) ?? 0 : 0);
          final car = Car(
            id: vehicle['id'].toString(),
            make: vehicle['make'] as String? ?? 'Unknown',
            model: vehicle['model'] as String? ?? 'Vehicle',
            year: (vehicle['year'] is int) ? vehicle['year'] as int : ((vehicle['year'] is String) ? int.tryParse(vehicle['year']) ?? 0 : 0),
            imageUrl: imageUrl,
            startingBid: startingBid,
            buyNowPrice: buyNowPrice,
            mileage: mileage,
            location: vehicle['location'] as String? ?? '',
            distance: vehicle['distance'] as String? ?? '',
            auctionEndTime: endTime,
            status: vehicle['status'] as String? ?? 'active',
            vin: vehicle['vin'] as String?,
            description: vehicle['description'] as String?,
          );
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car)));
        } catch (e) {
          print('❌ Error navigating to product: $e');
        }
      } : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  _buildVehicleImageThumb(imageUrl, 240, 100),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (currentBid == null || yourBid >= (currentBid ?? 0)) ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        (currentBid == null || yourBid >= (currentBid ?? 0)) ? 'Leading' : 'Outbid',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('\$${_formatNumberWithCommas(yourBid)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLostBidTile(Map<String, dynamic> item) {
    final imageUrl = item['photo_url'] as String? ?? 'assets/images/car1.png';
    final title = '${item['year'] ?? ''} ${item['make'] ?? ''} ${item['model'] ?? ''}'.trim();
    final yourBid = (item['amount'] is int) ? (item['amount'] as int).toDouble() : (item['amount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                _buildVehicleImageThumb(imageUrl, 200, 90),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)),
                    child: const Text('Lost', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isNotEmpty ? title : 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('\$${_formatNumberWithCommas(yourBid)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleImageThumb(String imageUrl, double width, double height) {
    final isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final isAsset = imageUrl.startsWith('assets/');
    if (isNetwork) {
      return Image.network(imageUrl, width: width, height: height, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(width: width, height: height, color: Colors.grey[200]));
    } else if (isAsset) {
      return Image.asset(imageUrl, width: width, height: height, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(width: width, height: height, color: Colors.grey[200]));
    } else {
      try {
        final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        final fullUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
        return Image.network(fullUrl, width: width, height: height, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(width: width, height: height, color: Colors.grey[200]));
      } catch (e) {
        return Container(width: width, height: height, color: Colors.grey[200]);
      }
    }
  }

  // Widget _buildSellerContent() {
  //   return NotificationListener<ScrollNotification>(
  //     onNotification: (scrollInfo) {
  //       controller.scrollOffset.value = scrollInfo.metrics.pixels;
  //       return false;
  //     },
  //     child: Obx(() {
  //       // Manage bids: needs bounded height + own CustomScrollView so the list scrolls.
  //       // Nesting SingleChildScrollViews (outer seller page + inner manage bids) prevented scrolling.
  //       if (controller.selectedSellerTab.value == 2) {
  //         return Column(
  //           crossAxisAlignment: CrossAxisAlignment.stretch,
  //           children: [
  //             _buildCompactCarousel(),
  //             _buildCompactSellerTabSection(),
  //             Expanded(
  //               child: Obx(() {
  //                 if (controller.isLoading.value && controller.sellerListings.isEmpty) {
  //                   return const Center(
  //                     child: Padding(
  //                       padding: EdgeInsets.all(24),
  //                       child: CircularProgressIndicator(),
  //                     ),
  //                   );
  //                 }
  //                 return _buildSellerActiveSales();
  //               }),
  //             ),
  //           ],
  //         );
  //       }
  //       return SingleChildScrollView(
  //         controller: _sellerListingScrollController,
  //         physics: const AlwaysScrollableScrollPhysics(),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             _buildCompactCarousel(),
  //             _buildCompactSellerTabSection(),
  //             _buildSellerTabContent(),
  //           ],
  //         ),
  //       );
  //     }),
  //   );
  // }

  Widget _buildSellerTabContent() {
    return Obx(() {
      final currentTab = controller.selectedSellerTab.value;

      if (_lastFetchedSellerTab != currentTab) {
        final tabToFetch = currentTab;
        _lastFetchedSellerTab = currentTab;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_lastFetchedSellerTab != tabToFetch) return;
          bool shouldFetch = false;
          switch (tabToFetch) {
            case 0: shouldFetch = controller.sellerStats.value == null; break;
            case 1: shouldFetch = controller.sellerListings.isEmpty; break;
            // Manage bids: always refresh — live-auctions API can miss listings; sellerListings fills gaps.
            case 2: shouldFetch = true; break;
            case 3: shouldFetch = controller.sellerListings.isEmpty; break;
            case 4: shouldFetch = controller.sellerStats.value == null; break;
          }
          if (!shouldFetch) return;
          switch (tabToFetch) {
            case 0: controller.fetchSellerDashboardData(); break;
            case 1: controller.fetchCars(); break;
            case 2:
              controller.fetchSellerDashboardData();
              controller.fetchCars();
              break;
            case 3: controller.fetchCars(); break;
            case 4: controller.fetchSellerDashboardData(); break;
          }
        });
      }

      if (controller.isLoading.value && currentTab != 0) {
        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
      }

      switch (currentTab) {
        case 0: return _buildSellerHome();
        case 1: return _buildSellerNewListing();
        case 2: return _buildSellerActiveSales();
        case 3: return _buildSellerInventory();
        case 4: return _buildSellerPerformance();
        default: return _buildSellerHome();
      }
    });
  }

  Widget _buildCarImage(String imageUrl, {double width = double.infinity, double height = 200, BoxFit fit = BoxFit.cover}) {
    final bool isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final bool isAsset = imageUrl.startsWith('assets/');

    if (isNetwork) {
      return Image.network(imageUrl, width: width, height: height, fit: fit,
          errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/car1.png', width: width, height: height, fit: fit));
    } else if (isAsset) {
      return Image.asset(imageUrl, width: width, height: height, fit: fit,
          errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/car1.png', width: width, height: height, fit: fit));
    } else {
      try {
        final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        final fullUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
        return Image.network(fullUrl, width: width, height: height, fit: fit,
            errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/car1.png', width: width, height: height, fit: fit));
      } catch (e) {
        return Image.asset('assets/images/car1.png', width: width, height: height, fit: fit);
      }
    }
  }

  void _showFullScreenCarImage(BuildContext context, String imageUrl) {
    final url = ImageHelper.normalizeImageUrl(imageUrl);
    final isAsset = url.startsWith('assets/');
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: isAsset
                    ? Image.asset(url, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 64, color: Colors.red))
                    : Image.network(url, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 64, color: Colors.red)),
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

  Widget _buildWonVehicleCard(Car car) {
    _loadWonVehiclesTransportStatus();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _buildCarImage(car.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(color: kAccentColor, borderRadius: BorderRadius.circular(2)),
                          child: const Text('Won', style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${car.year} ${car.make} ${car.model}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.emoji_events, size: 10, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text('\$${_formatNumberWithCommas(car.wonAmount ?? 0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[700])),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
             /*     Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewReportScreen(car: car))),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccentColor,
                        side: const BorderSide(color: kAccentColor),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Report', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),*/
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        bool hasTransport = _wonVehicleTransportExists[car.id] ?? false;
                        if (!hasTransport) {
                          try {
                            final status = await _transportService.getTransportOrder(car.id);
                            hasTransport = status['order'] != null && status['order']['id'] != null;
                            if (mounted) setState(() => _wonVehicleTransportExists[car.id] = hasTransport);
                          } catch (e) {
                            hasTransport = false;
                          }
                        }
                        if (hasTransport) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => TransportTrackingScreen(vehicleId: car.id)));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => VehicleShippingScreen(car: car)));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _wonVehicleTransportExists[car.id] == true ? kAccentColor : kAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _wonVehicleTransportExists[car.id] == true ? 'Track' : 'Ship',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildMinimalBadge(
                    icon: Icons.verified_user_outlined,
                    text: 'Insp: ${_getInspectionStatusDisplay(car.inspectionStatus)}',
                    color: _getStatusColor(_getInspectionStatusDisplay(car.inspectionStatus).toLowerCase()),
                  ),
                  if (car.transportStatus != null && car.transportStatus!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _buildMinimalBadge(
                      icon: Icons.local_shipping_outlined,
                      text: car.transportStatus!,
                      color: _getStatusColor(car.transportStatus!),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalBadge({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: color),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ============ IS CAR PURCHASED CHECK - YAHAN PE CHECK KARTE HAIN ============
  bool _isCarPurchased(Car car, {HomePageController? controller}) {
    final hc = controller ?? Get.find<HomePageController>();
    BidController? bc;
    try { bc = Get.find<BidController>(); } catch (_) {}

    final carId = car.id.toString();
    final inWonBids = bc != null && bc.wonBids.any((b) {
      final v = b['vehicle'];
      if (v is! Map) return false;
      final id = (v['id'] ?? v['vehicle_id'])?.toString();
      return id == carId;
    });

    // Priority checks for SOLD/WON status
    return car.status.toLowerCase() == 'sold' || 
        car.status.toLowerCase() == 'won' ||
        hc.wonVehicles.any((v) => v.id.toString() == carId) || 
        inWonBids ||
        hc.purchaseHistory.any((v) => v.id.toString() == carId);
  }

  /// Helper to build dynamic status badges (SOLD, ENDING, ACTIVE)
  Widget _buildDynamicStatusBadge(Car car, bool isTablet, [HomePageController? homeController]) {
    // 1. Priority: SOLD
    if (_isCarPurchased(car, controller: homeController)) {
      return _buildStatusBadgeContainer('SOLD', Colors.red, isTablet, icon: Icons.gavel);
    }

    // 2. Featured
    if (car.isFeatured) {
      return _buildStatusBadgeContainer('FEATURED', const Color(0xFF673AB7), isTablet, icon: Icons.auto_awesome);
    }

    // 3. Priority: ACTIVE or ENDING
    final status = car.status.toLowerCase();
    if (status == 'live' || status == 'active') {
      if (car.isEndingSoon) {
        return _buildStatusBadgeContainer('ENDING SOON', Colors.orange[800]!, isTablet, icon: Icons.timer_outlined);
      } else {
        return _buildStatusBadgeContainer('LIVE', Colors.green[700]!, isTablet, icon: Icons.sensors);
      }
    }

    return const SizedBox.shrink();
  }

  /// Helper to build the badge container
  Widget _buildStatusBadgeContainer(String label, Color color, bool isTablet, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 10 : 8,
        vertical: isTablet ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isTablet ? 12 : 10, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 10 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============ RESPONSIVE CAR LIST - GRID FOR TABLETS, LISTVIEW FOR MOBILE ============
  Widget _buildResponsiveCarList({
    required List<Car> carList,
    required int selectedTab,
    ScrollController? controller,
  }) {
    final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                     ResponsiveHelper.isTablet(context) ||
                     ResponsiveHelper.isIPhone12Size(context) ||
                     ResponsiveHelper.screenWidth(context) >= 600;
    
    // Use GridView for tablets/iPads, ListView for mobile
    if (isTablet) {
      // Calculate crossAxisCount based on screen width for tablets
      final screenWidth = ResponsiveHelper.screenWidth(context);
      int crossAxisCount = 2; // Default 2 columns
      if (screenWidth >= 1200) {
        crossAxisCount = 3; // 3 columns for large tablets
      } else if (screenWidth >= 900) {
        crossAxisCount = 2; // 2 columns for medium tablets
      } else {
        crossAxisCount = 2; // 2 columns for small tablets
      }

      return GridView.builder(
        controller: controller,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(16), // Compact padding for tablets
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16, // Compact spacing between columns
          mainAxisSpacing: 16, // Compact spacing between rows
          childAspectRatio: 0.75, // Compact aspect ratio for cards
        ),
        itemCount: carList.length,
        itemBuilder: (context, index) => _buildCarCard(carList[index], selectedTab, this.controller),
      );
    } else {
      // ListView for mobile devices
      return ListView.builder(
        controller: controller,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        itemCount: carList.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildCarCard(carList[index], selectedTab, this.controller),
        ),
      );
    }
  }

  // ============ MAIN CAR CARD WITH LIVE/SOLD LOGIC ============
  Widget _buildCarCard(Car car, int selectedTab, [HomePageController? homeController]) {
    if (selectedTab == 1) return _buildWonVehicleCard(car);
    if (selectedTab == 2) return _buildPurchaseHistoryCard(car);
    if (selectedTab == 3) return _buildSavedSearchCard(car, selectedTab);

    // Check if we're in grid layout (tablets/iPads)
    final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                     ResponsiveHelper.isTablet(context) ||
                     ResponsiveHelper.isIPhone12Size(context) ||
                     ResponsiveHelper.screenWidth(context) >= 600;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car))),
      child: Container(
        margin: EdgeInsets.zero, // ListView padding handles spacing - professional layout
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () => _showFullScreenCarImage(context, car.imageUrl),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      // Reverted to original card image sizing.
                      height: isTablet ? 200 : 140,
                      width: double.infinity,
                      child: _buildCarImage(
                        car.imageUrl,
                        width: double.infinity,
                        height: isTablet ? 200 : 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // Dynamic Status Badge (SOLD, ENDING, ACTIVE)
                Positioned(
                  top: isTablet ? 8 : 6,
                  left: isTablet ? 8 : 6,
                  child: _buildDynamicStatusBadge(car, isTablet, homeController),
                ),

                // Timer - Top Right
                Positioned(
                  top: isTablet ? 8 : 6,
                  right: isTablet ? 8 : 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 8 : 6,
                      vertical: isTablet ? 4 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(isTablet ? 4 : 3),
                    ),
                    child: AuctionCountdownWidget(auctionEndTime: car.auctionEndTime, isCompact: true),
                  ),
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.all(isTablet ? 12 : 8), // Compact padding for tablets
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with title and location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${car.year} ${car.make} ${car.model}',
                            style: TextStyle(
                              fontSize: isTablet ? _getCarCardTitleSize(context) : 13,
                              fontWeight: FontWeight.bold
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),

                    ],
                  ),

                  SizedBox(height: isTablet ? 4 : 6), // Compact spacing for tablets

                  // Specs chips
                  Wrap(spacing: isTablet ? 6 : 4, children: [
                    if (car.location.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(2)),
                        child: Text(
                          car.location,
                          style: TextStyle(
                            fontSize: isTablet ? _getCarCardLocationSize(context) : 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    _buildSpecChip('${_formatNumberWithCommas(car.mileage)} mi', isTablet),
                    if (car.fuelType != null) _buildSpecChip(car.fuelType!, isTablet),
                    if (car.driveTrain != null) _buildSpecChip(car.driveTrain!, isTablet),
                  ]),

                  SizedBox(height: isTablet ? 6 : 6), // Compact spacing for tablets

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_formatNumberWithCommas(car.startingBid)}',
                        style: TextStyle(
                          fontSize: isTablet ? _getCarCardValueSize(context) : 16,
                          fontWeight: FontWeight.bold
                        )
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          'Starting Bid',
                          style: TextStyle(
                            fontSize: isTablet ? _getCarCardLocationSize(context) : 10,
                            color: Colors.grey
                          )
                        )
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 6 : 6), // Compact spacing for tablets

                  // Verification + Inspection
                  Row(
                    children: [
                      Icon(Icons.verified, size: isTablet ? 12 : 10, color: Colors.green[700]),
                      const SizedBox(width: 2),
                      Text('Verified', style: TextStyle(fontSize: isTablet ? _getCarCardLabelSize(context) : 12)),
                      const SizedBox(width: 8),
                      Icon(Icons.verified_user, size: isTablet ? 14 : 12, color: Colors.orange),
                      const SizedBox(width: 2),
                      Text(
                        'Insp: ${_getInspectionStatusDisplay(car.inspectionStatus)}',
                        style: TextStyle(fontSize: isTablet ? 9 : 8)
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 10 : 8), // Professional spacing for tablets

                  // Bid Details Container
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 8,
                      vertical: isTablet ? 8 : 4
                    ),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bid: \$${_formatNumberWithCommas(car.startingBid)}',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w600
                          )
                        ),
                        Text(
                          'Buy: ${car.buyNowPrice > 0 ? '\$${_formatNumberWithCommas(car.buyNowPrice)}' : 'N/A'}',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w600,
                            color: car.buyNowPrice > 0 ? Colors.green : Colors.grey
                          )
                        ),
                        Text(
                          'Mi: ${_formatNumberWithCommas(car.mileage)}',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Buttons
                  Row(
                    children: [
                      Expanded(child: _buildCompactBidButton(car, homeController)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCompactWatchButton(car)),
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

  Widget _buildSpecChip(String label, [bool isTablet = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(2)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isTablet ? _getCarCardLocationSize(context) : 10,
          color: Colors.grey,
          fontWeight: FontWeight.w500
        )
      ),
    );
  }

/*
  Widget _buildCompactBidButton(Car car, HomePageController? homeController) {
    return Obx(() {
      final hc = homeController ?? Get.find<HomePageController>();
      BidController? bidCtrl;
      try { bidCtrl = Get.find<BidController>(); } catch (_) {}

      final carId = car.id.toString();
      final inWonBids = bidCtrl != null && bidCtrl.wonBids.any((b) {
        final v = b['vehicle'];
        if (v is! Map) return false;
        return (v['id'] ?? v['vehicle_id'])?.toString() == carId;
      });


      final isSoldOrWon = car.status == 'sold' || car.status == 'won' ||
          hc.wonVehicles.any((v) => v.id.toString() == carId) || inWonBids ||
          hc.purchaseHistory.any((v) => v.id.toString() == carId);

      bool hasUserBid = false;
      bool hasBuyNowBid = false;

      if (bidCtrl != null) {
        final matchBid = (b) {
          final v = b['vehicle'];
          return v is Map && ((v['id']?.toString() == carId) || (v['vehicle_id']?.toString() == carId));
        };
        final buyNowCheck = (b) => (b['is_buy_now'] == true) || ((b['bid_type'] ?? '') == 'buy_now');
        hasUserBid = bidCtrl.activeBids.any(matchBid) || bidCtrl.myBids.any(matchBid);
        hasBuyNowBid = (bidCtrl.activeBids.any((b) => matchBid(b) && buyNowCheck(b))) ||
            (bidCtrl.myBids.any((b) => matchBid(b) && buyNowCheck(b)));
      }

      final buttonLabel = hasUserBid ? 'Update' : (isSoldOrWon ? 'View' : (hasBuyNowBid ? 'Status' : 'Bid'));

      // DEBUG - yeh daal de
      print('🔍 Car ID: ${car.id}, hasUserBid: $hasUserBid, buttonLabel: $buttonLabel');

      return ElevatedButton(
        onPressed: () {
          if (isSoldOrWon || hasBuyNowBid || !hasUserBid) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceBidScreen(car: car)));
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSoldOrWon ? Colors.grey : kAccentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(buttonLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      );
    });
  }
*/
  Widget _buildCompactBidButton(Car car, HomePageController? homeController) {
    return Obx(() {
      final hc = homeController ?? Get.find<HomePageController>();

      // Get BidController
      BidController? bidCtrl;
      try {
        bidCtrl = Get.find<BidController>();
      } catch (_) {
        bidCtrl = Get.put(BidController(), permanent: true);
      }

      final carId = car.id.toString();
      final now = DateTime.now();

      // Check if auction is ended
      final bool isAuctionEnded = car.auctionEndTime != null &&
          car.auctionEndTime.isBefore(now);

      // Check if car is in won bids
      final inWonBids = bidCtrl != null && bidCtrl.wonBids.any((b) {
        final v = b['vehicle'];
        if (v is! Map) return false;
        final id = (v['id'] ?? v['vehicle_id'])?.toString();
        return id == carId;
      });

      // Check if car is sold/won
      final isSoldOrWon = car.status == 'sold' || car.status == 'won' ||
          car.status == 'ended' || isAuctionEnded ||
          hc.wonVehicles.any((v) => v.id.toString() == carId) || inWonBids ||
          hc.purchaseHistory.any((v) => v.id.toString() == carId);

      // Check if user has placed a bid on this car
      bool hasUserBid = false;
      bool hasBuyNowBid = false;

      if (bidCtrl != null && !isSoldOrWon) {  // Sirf active auctions ke liye check karo
        bool matchBid(dynamic b) {
          final v = b['vehicle'];
          if (v is! Map) return false;
          final bidCarId = (v['id']?.toString() ?? v['vehicle_id']?.toString());
          return bidCarId == carId;
        }

        bool isBuyNowBid(dynamic b) {
          return (b['is_buy_now'] == true) || ((b['bid_type'] ?? '') == 'buy_now');
        }

        // Check active bids and my bids
        for (var bid in bidCtrl.activeBids) {
          if (matchBid(bid)) {
            hasUserBid = true;
            if (isBuyNowBid(bid)) hasBuyNowBid = true;
          }
        }

        for (var bid in bidCtrl.myBids) {
          if (matchBid(bid)) {
            hasUserBid = true;
            if (isBuyNowBid(bid)) hasBuyNowBid = true;
          }
        }
      }

      // ✅ FINAL LOGIC - As per your requirement
      String buttonLabel;
      Color buttonColor;

      if (isSoldOrWon) {
        // 1. Agar sold/won/ended hai → Sirf VIEW
        buttonLabel = 'View';
        buttonColor = Colors.grey;
      } else if (hasUserBid) {
        // 2. Agar bid hai aur auction active hai → UPDATE
        buttonLabel = 'Update Bid';
        buttonColor = kAccentColor;
      } else if (hasBuyNowBid) {
        // 3. Agar Buy Now bid hai → STATUS
        buttonLabel = 'SOLD';
        buttonColor = Colors.orange;
      } else {
        // 4. Naya auction → BID
        buttonLabel = 'Bid';
        buttonColor = kAccentColor;
      }

      // Debug
      print('🎯 Car: ${car.id} - ${car.make} ${car.model}');
      print('   Status: ${car.status}, Ended: $isAuctionEnded');
      print('   hasUserBid: $hasUserBid, isSoldOrWon: $isSoldOrWon');
      print('   Button: $buttonLabel');

      return ElevatedButton(
        onPressed: () {
          // Hamesha product details screen par bhejo
          // Agar update karna hai to wahan se option milega
          Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car))
          ).then((_) {
            // Refresh bids after returning so card shows "Update Bid" (same as inside My Bids / details)
            bidCtrl?.fetchMyBids();
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
            buttonLabel,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)
        ),
      );
    });
  }

  Widget _buildCompactWatchButton(Car car) {
    return Builder(
      builder: (context) {
        WatchlistController watchlistController;
        try {
          watchlistController = Get.find<WatchlistController>();
        } catch (e) {
          watchlistController = Get.put(WatchlistController(), permanent: true);
        }
        return Obx(() {
          final isWatched = watchlistController.isWatched(car.id);
          final isWatchLoading = watchlistController.loadingVehicleId.value == car.id;
          return OutlinedButton(
            onPressed: isWatchLoading ? null : () => watchlistController.toggleWatchlist(car.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccentColor,
              side: const BorderSide(color: kAccentColor),
              minimumSize: const Size(0, 26),
              padding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isWatchLoading ? '...' : (isWatched ? '★' : '☆'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          );
        });
      },
    );
  }

  Widget _buildCustomCard({required EdgeInsetsGeometry margin, required double elevation, required RoundedRectangleBorder shape, required Widget child, Color? color}) {
    return Card(margin: margin, elevation: elevation, shape: shape, color: color, child: child);
  }

/*  Widget _buildSavedSearchCard(Car car, int selectedTab, [SavedSearch? savedSearch]) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(car.description ?? '${car.make} ${car.model}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: car.alerts ?? false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (value) {
                          if (savedSearch != null) {
                            final updatedSearch = SavedSearch(
                              id: savedSearch.id,
                              searchName: savedSearch.searchName,
                              make: savedSearch.make,
                              model: savedSearch.model,
                              yearFrom: savedSearch.yearFrom,
                              yearTo: savedSearch.yearTo,
                              priceMin: savedSearch.priceMin,
                              priceMax: savedSearch.priceMax,
                              maxMileage: savedSearch.maxMileage,
                              condition: savedSearch.condition,
                              zipCode: savedSearch.zipCode,
                              searchRadius: savedSearch.searchRadius,
                              enableEmailAlerts: value ?? false,
                              alertFrequency: savedSearch.alertFrequency,
                              createdAt: savedSearch.createdAt,
                              lastMatch: savedSearch.lastMatch,
                              currentMatches: savedSearch.currentMatches,
                            );
                            controller.addSavedSearch(updatedSearch);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text('Alerts', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            if (car.description != null) ...[
              const SizedBox(height: 4),
              Text(car.description!, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Last: ${car.lastMatch ?? 'N/A'}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text('${car.currentMatches ?? 0} matches', style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: savedSearch != null ? () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ViewMatchesScreen(savedSearch: savedSearch!)));
                  } : null,
                  child: const Text('Matches', style: TextStyle(fontSize: 10, color: kAccentColor)),
                ),
                TextButton(
                  onPressed: savedSearch != null ? () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SaveSearchScreen(existingSearch: savedSearch)),
                    );
                    if (result != null && result is SavedSearch) controller.addSavedSearch(result);
                  } : null,
                  child: const Text('Edit', style: TextStyle(fontSize: 10, color: kAccentColor)),
                ),
                TextButton(
                  onPressed: savedSearch != null ? () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Delete', style: TextStyle(fontSize: 16)),
                        content: Text('Delete "${savedSearch.searchName}"?', style: const TextStyle(fontSize: 12)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
                          TextButton(
                            onPressed: () {
                              controller.deleteSavedSearch(savedSearch.id);
                              Navigator.pop(context);
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  } : null,
                  child: const Text('Del', style: TextStyle(fontSize: 10, color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }*/

  Widget _buildSavedSearchCard(Car car, int selectedTab, [SavedSearch? savedSearch]) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Name Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    savedSearch?.searchName ?? '${car.make} ${car.model}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Alerts checkbox
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Alerts',
                      style: TextStyle(
                        fontSize: 10,
                        color: car.alerts == true ? kAccentColor : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: car.alerts ?? false,
                        onChanged: (value) {
                          if (savedSearch != null) {
                            final updatedSearch = SavedSearch(
                              id: savedSearch.id,
                              searchName: savedSearch.searchName,
                              make: savedSearch.make,
                              model: savedSearch.model,
                              yearFrom: savedSearch.yearFrom,
                              yearTo: savedSearch.yearTo,
                              priceMin: savedSearch.priceMin,
                              priceMax: savedSearch.priceMax,
                              maxMileage: savedSearch.maxMileage,
                              condition: savedSearch.condition,
                              zipCode: savedSearch.zipCode,
                              searchRadius: savedSearch.searchRadius,
                              enableEmailAlerts: value ?? false,
                              alertFrequency: savedSearch.alertFrequency,
                              createdAt: savedSearch.createdAt,
                              lastMatch: savedSearch.lastMatch,
                              currentMatches: savedSearch.currentMatches,
                            );
                            controller.addSavedSearch(updatedSearch);
                          }
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Search Criteria
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (savedSearch?.make != null && savedSearch!.make!.isNotEmpty)
                  _buildSearchChip(savedSearch.make!),
                if (savedSearch?.model != null && savedSearch!.model!.isNotEmpty && savedSearch.model != 'Any Model')
                  _buildSearchChip(savedSearch.model!),
                if (savedSearch?.yearFrom != null)
                  _buildSearchChip('${savedSearch?.yearFrom}-${savedSearch?.yearTo ?? 'Present'}'),
                if (savedSearch?.priceMin != null || savedSearch?.priceMax != null)
                  _buildSearchChip(
                      '\$${savedSearch?.priceMin?.toStringAsFixed(0) ?? '0'}-\$${savedSearch?.priceMax?.toStringAsFixed(0) ?? '∞'}'
                  ),
                if (savedSearch?.condition != null && savedSearch!.condition != 'Any Condition')
                  _buildSearchChip(savedSearch.condition!),
              ],
            ),

            const SizedBox(height: 8),

            // Last Match & Matches Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last match: ${savedSearch?.lastMatch ?? 'Never'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${savedSearch?.currentMatches ?? 0} matches',
                    style: TextStyle(
                      fontSize: 10,
                      color: kAccentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: savedSearch != null
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewMatchesScreen(savedSearch: savedSearch),
                        ),
                      );
                    }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: kAccentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Matches',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: savedSearch != null
                        ? () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SaveSearchScreen(existingSearch: savedSearch),
                        ),
                      );
                      if (result != null && result is SavedSearch) {
                        controller.addSavedSearch(result);
                      }
                    }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: kAccentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: savedSearch != null
                        ? () {
                      _showDeleteSearchDialog(savedSearch);
                    }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Helper widget for search criteria chips
  Widget _buildSearchChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

// Delete confirmation dialog
  void _showDeleteSearchDialog(SavedSearch search) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Search', style: TextStyle(fontSize: 16)),
        content: Text(
          'Delete "${search.searchName}"?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              controller.deleteSavedSearch(search.id);
              Navigator.pop(dialogContext);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Search deleted'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseHistoryCard(Car car) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kAccentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('PURCHASED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kAccentColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildCarImage(car.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${car.year} ${car.make} ${car.model}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
                      const SizedBox(height: 4),
                      Text('\$${_formatNumberWithCommas(car.purchaseAmount ?? car.price ?? 0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kAccentColor)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 8, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(car.expectedDeliveryDate ?? 'Mar 2024', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PurchaseDetailsScreen(car: car))),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAccentColor,
                      side: const BorderSide(color: kAccentColor),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InspectionRequestScreen(car: car))),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Inspect', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumberWithCommas(num number) {
    final formatter = number.toStringAsFixed(0);
    return formatter.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('done') || lowerStatus.contains('received') || lowerStatus.contains('completed') || lowerStatus == 'inspected') {
      return Colors.green;
    } else if (lowerStatus.contains('pending') || lowerStatus.contains('transit')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  // ============ SELLER UI SECTIONS ============

/*
  Widget _buildSellerHome() {
    return Obx(() {
      if (controller.isLoading.value && controller.sellerStats.value == null) {
        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
      }

      if (controller.selectedSellerTab.value == 0 && controller.sellerStats.value == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => controller.fetchSellerDashboardData());
      }

      final stats = controller.sellerStats.value;
      final allListings = controller.sellerListings;
      final liveAuctionVehicleIds = controller.liveAuctions
          .map((auction) => (auction['vehicle'] as Map<String, dynamic>)['id'].toString()).toSet();
      final existingListingIds = allListings.map((l) => l.id).toSet();

      int activeListingsCount = allListings.where((car) => car.status == 'active').length;
      for (var auction in controller.liveAuctions) {
        final vehicle = auction['vehicle'] as Map<String, dynamic>;
        final vehicleId = vehicle['id'].toString();
        final vehicleStatus = vehicle['status']?.toString() ?? 'active';
        if (vehicleStatus == 'active' && !existingListingIds.contains(vehicleId)) activeListingsCount++;
      }

      final draftListingsCount = allListings.where((car) => car.status == 'draft').length;
      final pendingListingsCount = allListings.where((car) => car.status == 'pending').length;
      final soldListingsCount = allListings.where((car) => car.status == 'sold').length;
      final pendingOffersCount = stats?['pendingOffers'] ?? controller.pendingOffers.length;
      final pendingTransportCount = stats?['pendingTransport'] ?? controller.pendingTransport.length;
      final totalSales = stats?['totalSales'] ?? soldListingsCount;
      final totalRevenue = (stats?['totalRevenue'] ?? 0.0).toDouble();

      return RefreshIndicator(
        onRefresh: () async {
          await controller.fetchCars();
          await controller.fetchSellerDashboardData();
          await AutoSyncService.to.triggerManualSync();
        },
        color: kAccentColor,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kAccentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.dashboard, color: kAccentColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Seller Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(
                      onPressed: () async {
                        await controller.fetchCars();
                        await controller.fetchSellerDashboardData();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed'), duration: Duration(seconds: 1)));
                      },
                      icon: Icon(Icons.refresh, color: kAccentColor, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Active', activeListingsCount.toString(), Colors.blue[50]!, Colors.blue[700]!)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Sold', totalSales.toString(), Colors.green[50]!, Colors.green[700]!)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Revenue', '\$${_formatNumberWithCommas(totalRevenue)}', Colors.purple[50]!, Colors.purple[700]!)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Listings', allListings.length.toString(), Colors.orange[50]!, Colors.orange[700]!)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoCard(icon: Icons.monetization_on, iconColor: Colors.red, title: 'Pending Offers', value: '$pendingOffersCount', description: 'Buy Now requests', borderColor: Colors.red,
                    onTap: () => controller.updateSelectedSellerTab(2)),
                const SizedBox(height: 8),
                _buildInfoCard(icon: Icons.local_fire_department, iconColor: Colors.blue, title: 'Active', value: '$activeListingsCount', description: 'Live auctions', borderColor: Colors.blue,
                    onTap: () { controller.updateSelectedSellerTab(1); controller.updateSelectedSellerSubTab(3); }),
                const SizedBox(height: 8),
                _buildInfoCard(icon: Icons.local_shipping, iconColor: Colors.orange, title: 'Transport', value: '$pendingTransportCount', description: 'Pending pickup', borderColor: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerTransportRequestsScreen()))),
                const SizedBox(height: 8),
                _buildInfoCard(icon: Icons.verified_user, iconColor: Colors.teal, title: 'Inspections', value: 'View', description: 'Inspection requests', borderColor: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerInspectionRequestsScreen()))),
              ],
            ),
          ),
        ),
      );
    });
  }
*/

  // Line ~3720 ke around - _buildSellerHome function mein yeh changes karo:

  Widget _buildSellerHome() {
    return Obx(() {
      if (controller.isLoading.value && controller.sellerStats.value == null) {
        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
      }

      if (controller.selectedSellerTab.value == 0 && controller.sellerStats.value == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => controller.fetchSellerDashboardData());
      }

      final stats = controller.sellerStats.value;
      final allListings = controller.sellerListings;
      final liveAuctionVehicleIds = controller.liveAuctions
          .map((auction) => (auction['vehicle'] as Map<String, dynamic>)['id'].toString()).toSet();
      final existingListingIds = allListings.map((l) => l.id).toSet();

      int activeListingsCount = allListings.where((car) => car.status == 'active').length;
      for (var auction in controller.liveAuctions) {
        final vehicle = auction['vehicle'] as Map<String, dynamic>;
        final vehicleId = vehicle['id'].toString();
        final vehicleStatus = vehicle['status']?.toString() ?? 'active';
        if (vehicleStatus == 'active' && !existingListingIds.contains(vehicleId)) activeListingsCount++;
      }

      final draftListingsCount = allListings.where((car) => car.status == 'draft').length;
      final pendingListingsCount = allListings.where((car) => car.status == 'pending').length;
      final soldListingsCount = allListings.where((car) => car.status == 'sold').length;
      final pendingOffersCount = stats?['pendingOffers'] ?? controller.pendingOffers.length;
      final pendingTransportCount = stats?['pendingTransport'] ?? controller.pendingTransport.length;
      final totalSales = stats?['totalSales'] ?? soldListingsCount;
      final totalRevenue = (stats?['totalRevenue'] ?? 0.0).toDouble();

      return RefreshIndicator(
        onRefresh: () async {
          await controller.fetchCars();
          await controller.fetchSellerDashboardData();
          await AutoSyncService.to.triggerManualSync();
        },
        color: kAccentColor,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kAccentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.dashboard, color: kAccentColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Seller Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(
                      onPressed: () async {
                        await controller.fetchCars();
                        await controller.fetchSellerDashboardData();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed'), duration: Duration(seconds: 1)));
                      },
                      icon: Icon(Icons.refresh, color: kAccentColor, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats Cards Row 1
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Active',
                        value: activeListingsCount.toString(),
                        icon: Icons.local_fire_department,
                        color: Colors.blue,
                        onTap: () {
                          controller.updateSelectedSellerTab(1);
                          controller.updateSelectedSellerSubTab(3);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Sold',
                        value: totalSales.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                        onTap: () {
                          controller.updateSelectedSellerTab(3);
                          controller.updateSelectedSellerSubTab(1);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Stats Cards Row 2
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Revenue',
                        value: '\$${_formatNumberWithCommas(totalRevenue)}',
                        icon: Icons.attach_money,
                        color: Colors.purple,
                        onTap: () {
                          controller.updateSelectedSellerTab(4);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Listings',
                        value: allListings.length.toString(),
                        icon: Icons.inventory,
                        color: Colors.orange,
                        onTap: () {
                          controller.updateSelectedSellerTab(1);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Info Cards
                _buildInfoCard(
                  icon: Icons.monetization_on,
                  iconColor: Colors.red,
                  title: 'Pending Offers',
                  value: '$pendingOffersCount',
                  description: 'Buy Now requests',
                  borderColor: Colors.red,
                  onTap: () => controller.updateSelectedSellerTab(2),
                ),
                const SizedBox(height: 8),

                _buildInfoCard(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.blue,
                  title: 'Active Listings',
                  value: '$activeListingsCount',
                  description: 'Live auctions',
                  borderColor: Colors.blue,
                  onTap: () {
                    controller.updateSelectedSellerTab(1);
                    controller.updateSelectedSellerSubTab(3);
                  },
                ),
                const SizedBox(height: 8),

                _buildInfoCard(
                  icon: Icons.local_shipping,
                  iconColor: Colors.orange,
                  title: 'Transport',
                  value: '$pendingTransportCount',
                  description: 'Pending pickup',
                  borderColor: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerTransportRequestsScreen())),
                ),
                const SizedBox(height: 8),

                _buildInfoCard(
                  icon: Icons.verified_user,
                  iconColor: Colors.teal,
                  title: 'Inspections',
                  value: 'View',
                  description: 'Inspection requests',
                  borderColor: Colors.teal,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerInspectionRequestsScreen())),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

// Add this new dashboard card widget
  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String title, required String value, required String description, required Color borderColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(4)), child: Icon(icon, color: Colors.white, size: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor)),
                  Text(description, style: const TextStyle(fontSize: 7, color: Colors.grey), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

/*
  Widget _buildStatCard(String title, String value, Color bgColor, Color textColor, {VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: textColor.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis, maxLines: 1),
      ]),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: content) : content;
  }
*/

  Widget _buildSellerNewListing() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: ResponsiveHelper.isIPadDevice(context) ? 4 : 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'My Listings',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isIPadDevice(context) 
                        ? 20 
                        : (ResponsiveHelper.isTablet(context) || ResponsiveHelper.isIPadOrTabletDevice(context) 
                            ? 22 
                            : 16),
                    fontWeight: FontWeight.bold
                  )
                )
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListVehicleScreen())).then((_) => controller.fetchCars()),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: kAccentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: const Size(0, 30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: ResponsiveHelper.isIPadDevice(context) ? 4 : 0,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSellerSubTabButton('All', 0),
                const SizedBox(width: 4),
                _buildSellerSubTabButton('Draft', 1),
                const SizedBox(width: 4),
                _buildSellerSubTabButton('Pending', 2),
                const SizedBox(width: 4),
                _buildSellerSubTabButton('Live', 3),
              ],
            ),
          ),
        ),
        SizedBox(height: ResponsiveHelper.isIPadDevice(context) ? 4 : 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sellerSearchController,
                  onChanged: (v) => setState(() => _sellerSearchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _sellerSearchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 14), onPressed: () { _sellerSearchController.clear(); setState(() => _sellerSearchQuery = ''); }) : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: kAccentColor)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[300]!)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sellerSortKey,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('New', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'oldest', child: Text('Old', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'price_high', child: Text('High', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'price_low', child: Text('Low', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _sellerSortKey = v); },
                    icon: const Icon(Icons.arrow_drop_down, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveHelper.isIPadDevice(context) ? 4 : 8),
        _buildNewListingList(),
      ],
    );
  }

  Widget _buildNewListingList() {
    return RefreshIndicator(
      onRefresh: () async {
        await controller.fetchCars();
        await AutoSyncService.to.triggerManualSync();
      },
      color: kAccentColor,
      child: Obx(() {
        final listings = _getNewListingCars();
        if (listings.isEmpty) {
          return const Padding(padding: EdgeInsets.all(20), child: EmptyStateWidget(type: EmptyStateType.emptyListings, title: 'No Listings', message: 'Create your first listing'));
        }

        final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                         ResponsiveHelper.isTablet(context) ||
                         ResponsiveHelper.isIPhone12Size(context) ||
                         ResponsiveHelper.screenWidth(context) >= 600;

        // Use GridView for tablets/iPads, ListView for mobile
        if (isTablet) {
          final screenWidth = ResponsiveHelper.screenWidth(context);
          final isIPadAir = ResponsiveHelper.isIPadDevice(context);
          int crossAxisCount = 2;
          if (screenWidth >= 1200) {
            crossAxisCount = 3;
          } else if (screenWidth >= 900) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 2;
          }

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.all(isIPadAir ? 8 : (isTablet ? 12 : 16)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isIPadAir ? 8 : (isTablet ? 12 : 16),
              mainAxisSpacing: isIPadAir ? 8 : (isTablet ? 12 : 16),
              childAspectRatio: isIPadAir ? 3.0 : (isTablet ? 1.8 : 0.75),
            ),
            itemCount: listings.length,
            itemBuilder: (context, index) => _buildNewListingCard(listings[index]),
          );
        } else {
          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            itemCount: listings.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildNewListingCard(listings[index]),
            ),
          );
        }
      }),
    );
  }

  List<Car> _getNewListingCars() {
    List<Car> base;
    switch (controller.selectedSellerSubTab.value) {
      case 0: base = _getAllNewListings(); break;
      case 1: base = _getAllNewListings().where((c) => c.status == 'draft').toList(); break;
      case 2: base = _getAllNewListings().where((c) => c.status == 'pending').toList(); break;
      case 3: base = _getAllNewListings().where((c) => c.status == 'active').toList(); break;
      default: base = [];
    }
    final query = _sellerSearchQuery.toLowerCase();
    List<Car> filtered = base.where((c) {
      if (query.isEmpty) return true;
      return [c.make, c.model, c.vin ?? '', c.location, c.status, c.year.toString()].join(' ').toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      switch (_sellerSortKey) {
        case 'oldest': return 1;
        case 'price_high': {
          final ap = (a.buyNowPrice > 0 ? a.buyNowPrice : a.startingBid);
          final bp = (b.buyNowPrice > 0 ? b.buyNowPrice : b.startingBid);
          return bp.compareTo(ap);
        }
        case 'price_low': {
          final ap = (a.buyNowPrice > 0 ? a.buyNowPrice : a.startingBid);
          final bp = (b.buyNowPrice > 0 ? b.buyNowPrice : b.startingBid);
          return ap.compareTo(bp);
        }
        case 'year_new': return b.year.compareTo(a.year);
        case 'year_old': return a.year.compareTo(b.year);
        default: return -1;
      }
    });
    return filtered;
  }

  List<Car> _getAllNewListings() {
    final listings = controller.sellerListings;
    final existingListingIds = listings.map((l) => l.id).toSet();
    final missingActiveListings = <Car>[];

    for (var auction in controller.liveAuctions) {
      try {
        final vehicle = auction['vehicle'] as Map<String, dynamic>;
        final vehicleId = vehicle['id'].toString();
        if (!existingListingIds.contains(vehicleId)) {
          final mappedVehicle = _mapBackendToFlutterFields(vehicle);
          final car = Car.fromJson(mappedVehicle);
          if (car.status == 'active') missingActiveListings.add(car);
        }
      } catch (e) {}
    }

    return [...listings, ...missingActiveListings];
  }

  Map<String, dynamic> _mapBackendToFlutterFields(Map<String, dynamic> item) {
    final mappedItem = Map<String, dynamic>.from(item);
    if (mappedItem.containsKey('fixed_price')) mappedItem['buyNowPrice'] = mappedItem['fixed_price'];
    if (mappedItem.containsKey('opening_bid')) mappedItem['startingBid'] = mappedItem['opening_bid'];
    if (mappedItem.containsKey('image_url')) mappedItem['imageUrl'] = mappedItem['image_url'];
    if (mappedItem.containsKey('auction_end_time')) mappedItem['auctionEndTime'] = mappedItem['auction_end_time'];
    if (!mappedItem.containsKey('buyNowPrice') && mappedItem.containsKey('buy_now_price')) mappedItem['buyNowPrice'] = mappedItem['buy_now_price'];
    if (!mappedItem.containsKey('startingBid') && mappedItem.containsKey('starting_bid')) mappedItem['startingBid'] = mappedItem['starting_bid'];
    if (!mappedItem.containsKey('imageUrl') && mappedItem.containsKey('image_url')) mappedItem['imageUrl'] = mappedItem['image_url'];
    if (!mappedItem.containsKey('status') || mappedItem['status'] == null) mappedItem['status'] = 'draft';
    return mappedItem;
  }

  /*Widget _buildNewListingCard(Car car) {
    final statusColor = car.status == 'draft' ? Colors.orange : car.status == 'pending' ? Colors.blue : Colors.green;
    final statusText = car.status == 'draft' ? 'Draft' : car.status == 'pending' ? 'Pending' : 'Active';

    return InkWell(
      onTap: () {
        showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car)));
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(6), child: _buildCarImage(car.imageUrl, width: 60, height: 60, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${car.year} ${car.make} ${car.model}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))),
                            child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('\$${_formatNumberWithCommas(car.startingBid)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (car.status == 'draft')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListVehicleScreen(car: car))),
                      style: ElevatedButton.styleFrom(backgroundColor: kAccentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Edit', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showDeleteConfirmation(car),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Delete', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              )
            else if (car.status == 'pending')
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 12, color: Colors.blue), SizedBox(width: 4), Text('Under Review', style: TextStyle(fontSize: 10, color: Colors.blue))]),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.trending_up, size: 12, color: Colors.green), SizedBox(width: 4), Text('Live Auction', style: TextStyle(fontSize: 10, color: Colors.green))]),
              ),
          ],
        ),
      ),
    );
  }*/

  // Line ~3960 ke around - _buildNewListingCard function replace karo:

  Widget _buildNewListingCard(Car car) {
    final statusColor = car.status == 'draft' ? Colors.orange :
    car.status == 'pending' ? Colors.blue :
    car.status == 'active' ? Colors.green :
    car.status == 'sold' ? Colors.red : 
    car.status == 'rejected' ? Colors.grey[700]! : Colors.grey;

    final statusText = car.status == 'draft' ? 'Draft' :
    car.status == 'pending' ? 'Pending Review' :
    car.status == 'active' ? 'Live Auction' :
    car.status == 'sold' ? 'Sold' : 
    car.status == 'rejected' ? 'Rejected' : car.status;

    // Check if we're in grid layout (tablets/iPads)
    final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                         ResponsiveHelper.isTablet(context) ||
                         ResponsiveHelper.isIPhone12Size(context) ||
                         ResponsiveHelper.screenWidth(context) >= 600;
    final isIPadAir = ResponsiveHelper.isIPadDevice(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(car: car),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.zero, // ListView padding handles spacing - professional layout
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isIPadAir ? 10 : (isTablet ? 14 : 12)), // Compact padding for tablets/iPads
          child: Column(
            children: [
              // Top row - Image and basic info
              Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCarImage(
                      car.imageUrl,
                      width: isIPadAir ? 75 : (isTablet ? 90 : 70), // More compact image size for tablets/iPads
                      height: isIPadAir ? 75 : (isTablet ? 90 : 70),
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: isIPadAir ? 10 : (isTablet ? 12 : 12)), // Compact spacing for tablets/iPads

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${car.year} ${car.make} ${car.model}',
                                style: TextStyle(
                                  fontSize: isIPadAir ? 13 : (isTablet ? _getCarCardTitleSize(context) : 14),
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isIPadAir ? 4 : (isTablet ? 5 : 6)),

                        // Price
                        Text(
                          '\$${_formatNumberWithCommas(car.startingBid)}',
                          style: TextStyle(
                            fontSize: isIPadAir ? 14 : (isTablet ? 15 : 15),
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        SizedBox(height: isIPadAir ? 2 : (isTablet ? 3 : 4)),

                        // Details row
                        Wrap(
                          spacing: isIPadAir ? 6 : 8,
                          children: [
                            // Mileage
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed, size: isIPadAir ? 10 : 12, color: Colors.grey[600]),
                                SizedBox(width: isIPadAir ? 2 : 2),
                                Text(
                                  '${_formatNumberWithCommas(car.mileage)} mi',
                                  style: TextStyle(
                                    fontSize: isIPadAir ? 9 : (isTablet ? _getCarCardLocationSize(context) : 10),
                                    color: Colors.grey[600]
                                  ),
                                ),
                              ],
                            ),

                            // Location
                            if (car.location.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: isIPadAir ? 10 : 12, color: Colors.grey[600]),
                                  SizedBox(width: isIPadAir ? 2 : 2),
                                  Text(
                                    car.location.length > 15
                                        ? '${car.location.substring(0, 15)}...'
                                        : car.location,
                                    style: TextStyle(
                                      fontSize: isIPadAir ? 9 : (isTablet ? _getCarCardLocationSize(context) : 10),
                                      color: Colors.grey[600]
                                    ),
                                  ),
                                ],
                              ),

                            // VIN (if available)
                            if (car.vin != null && car.vin!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code, size: isIPadAir ? 10 : 12, color: Colors.grey[600]),
                                  SizedBox(width: isIPadAir ? 2 : 2),
                                  Text(
                                    'VIN: ${car.vin!.substring(car.vin!.length - 4)}',
                                    style: TextStyle(
                                      fontSize: isIPadAir ? 9 : (isTablet ? _getCarCardLocationSize(context) : 10),
                                      color: Colors.grey[600]
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isIPadAir ? 8 : (isTablet ? 10 : 12)),

              // Action buttons based on status
              if (car.status == 'draft')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListVehicleScreen(car: car),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isIPadAir ? 6 : 8),
                          minimumSize: Size(0, isIPadAir ? 28 : 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Edit Listing',
                          style: TextStyle(
                            fontSize: isIPadAir ? 10 : (isTablet ? _getCarCardButtonTextSize(context) : 11),
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isIPadAir ? 6 : 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showDeleteConfirmation(car),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: isIPadAir ? 6 : 8),
                          minimumSize: Size(0, isIPadAir ? 28 : 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(fontSize: isIPadAir ? 10 : 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                )
              else if (car.status == 'pending')
                Container(
                  padding: EdgeInsets.all(isIPadAir ? 6 : 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, size: isIPadAir ? 12 : 14, color: Colors.blue),
                      SizedBox(width: isIPadAir ? 4 : 6),
                      Text(
                        'Under Review - Pending Approval',
                        style: TextStyle(
                          fontSize: isIPadAir ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                )
              else if (car.status == 'active')
                  Container(
                    padding: EdgeInsets.all(isIPadAir ? 6 : 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: isIPadAir ? 12 : 14, color: Colors.green),
                            SizedBox(width: isIPadAir ? 4 : 6),
                            Text(
                              'Live Auction',
                              style: TextStyle(
                                fontSize: isIPadAir ? 10 : 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Ends: ${_formatAuctionDateTime(car.auctionEndTime)}',
                          style: TextStyle(
                            fontSize: isIPadAir ? 9 : 10,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (car.status == 'sold')
                    Container(
                      padding: EdgeInsets.all(isIPadAir ? 6 : 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: isIPadAir ? 12 : 14, color: Colors.red),
                          SizedBox(width: isIPadAir ? 4 : 6),
                          Text(
                            'Sold for \$${_formatNumberWithCommas(car.price ?? car.startingBid)}',
                            style: TextStyle(
                              fontSize: isIPadAir ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerSubTabButton(String title, int index) {
    return Obx(() {
      final isSelected = controller.selectedSellerSubTab.value == index;
      final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                       ResponsiveHelper.isTablet(context) ||
                       ResponsiveHelper.screenWidth(context) >= 600;
      final isIPadAir = ResponsiveHelper.isIPadDevice(context);
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              controller.updateSelectedSellerSubTab(index);
              Future.delayed(const Duration(milliseconds: 50), () {
                if (_sellerListingScrollController.hasClients) {
                  _sellerListingScrollController.animateTo(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                }
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isIPadAir ? 5 : (isTablet ? 7 : 6),
                horizontal: isIPadAir ? 12 : (isTablet ? 16 : 14),
              ),
              decoration: BoxDecoration(
                color: isSelected ? kAccentColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: kAccentColor.withOpacity(0.3)),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isIPadAir ? 10 : (isTablet ? 12 : 11),
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black
                )
              ),
            ),
          ),
        ),
      );
    });
  }

  Car? _carFromSellerListingsById(String id) {
    for (final c in controller.sellerListings) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Vehicles with at least one bid (seller dashboard API) — matches website "Pending bids".
  List<Car> _sellerCarsWithPendingBids() {
    final out = <Car>[];
    final seen = <String>{};
    for (final raw in controller.sellerVehicles) {
      if (raw is! Map) continue;
      final st = (raw['status'] ?? '').toString().toLowerCase();
      if (st != 'active') continue;
      final bc = raw['bid_count'];
      final n = bc is int ? bc : int.tryParse('$bc') ?? 0;
      if (n < 1) continue;
      final id = raw['id']?.toString();
      if (id == null || seen.contains(id)) continue;
      final car = _carFromSellerListingsById(id);
      if (car != null) {
        seen.add(id);
        out.add(car);
      }
    }
    return out;
  }

  List<Car> _sellerSoldCars() {
    return controller.sellerListings
        .where((c) => c.status.toLowerCase() == 'sold')
        .toList();
  }

  static const _manageBidsFilterDefs = <(String, String)>[
    ('all', 'All activity'),
    ('pending_bids', 'Pending bids'),
    ('active_auctions', 'Active auctions'),
    ('swap', 'Swap requests'),
    ('direct_sales', 'Direct sales'),
    ('sold', 'Sold'),
  ];

  String _manageBidsEntriesLabel(String filterKey) {
    for (final e in _manageBidsFilterDefs) {
      if (e.$1 == filterKey) return e.$2;
    }
    return 'Pending bids';
  }

  Widget _buildManageBidsFilterChips() {
    return Obx(() => _buildManageBidsFilterRow(controller.manageBidsFilter.value));
  }

  Widget _buildManageBidsFilterRow(String sel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in _manageBidsFilterDefs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                showCheckmark: false,
                label: Text(
                  e.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel == e.$1 ? kWhiteColor : kBlackColor,
                  ),
                ),
                selected: sel == e.$1,
                onSelected: (_) => controller.setManageBidsFilter(e.$1),
                selectedColor: kAccentColor,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: sel == e.$1 ? kAccentColor : Colors.grey[300]!,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManageBidsTableColumnHeaders() {
    Text h(String t) => Text(
          t,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.grey[700],
            letterSpacing: 0.3,
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(flex: 11, child: h('VEHICLE')),
          Expanded(flex: 6, child: h('BID')),
          Expanded(flex: 7, child: h('STATUS')),
          Expanded(flex: 8, child: h('ACTIONS')),
        ],
      ),
    );
  }

  /// Active listings not returned by live-auctions API (timezone/auction_end_time mismatch).
  /// Uses full [sellerListings] from my-listings so notification-opened vehicles also appear here after refresh.
  List<Car> _extraSellerManageBidCars() {
    final shown = <String>{};
    for (final a in controller.liveAuctions) {
      final v = a['vehicle'];
      if (v is Map) {
        final id = v['id']?.toString();
        if (id != null) shown.add(id);
      }
    }
    final out = <Car>[];
    for (final car in controller.sellerListings) {
      if (shown.contains(car.id)) continue;
      if (car.status.toLowerCase() != 'active') continue;
      out.add(car);
    }
    return out;
  }

  Widget _buildManageBidListingRow(Car car) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildCarImage(car.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${car.year} ${car.make} ${car.model}',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${_formatNumberWithCommas(car.currentBid ?? car.startingBid)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellerBidManagementScreen(vehicle: car),
                  ),
                );
              },
              icon: const Icon(Icons.gavel, size: 14, color: kAccentColor),
              label: const Text('Manage', style: TextStyle(fontSize: 11, color: kAccentColor, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kAccentColor, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scrollable body items for Manage bids (used inside [SliverList]).
  List<Widget> _gatherManageBidsBodyItems(String filter) {
    final pendingOffers = controller.pendingOffers;
    final liveAuctions = controller.liveAuctions;
    final extraCars = _extraSellerManageBidCars();
    final swapOffers = pendingOffers.where((offer) => offer['type'] == 'swap').toList();
    final purchaseOffers = pendingOffers.where((offer) => offer['type'] == 'buy_now').toList();
    final pendingBidCars = _sellerCarsWithPendingBids();
    final soldCars = _sellerSoldCars();

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        );

    List<Widget> buildActiveAuctionRows() {
      // 1. Filter liveAuctions to only show those with bids
      final activeWithBids = liveAuctions.where((auction) {
        final bc = auction['bid_count'] ?? 0;
        final count = bc is int ? bc : int.tryParse('$bc') ?? 0;
        return count > 0;
      }).toList();

      // 2. Filter extraCars (from sellerListings) to only show those with bids
      // Since Car model doesn't have bid_count, we match with sellerVehicles data
      final extraWithBids = extraCars.where((car) {
        final raw = controller.sellerVehicles.firstWhere(
          (v) => (v != null && v is Map) && (v['id']?.toString() == car.id),
          orElse: () => null,
        );
        if (raw == null) return false;
        final bc = raw['bid_count'] ?? 0;
        final count = bc is int ? bc : int.tryParse('$bc') ?? 0;
        return count > 0;
      }).toList();

      if (activeWithBids.isEmpty && extraWithBids.isEmpty) {
        return [
          const EmptyStateWidget(
            type: EmptyStateType.emptyCars,
            title: 'No auctions with bids',
            message: 'Active listings with bids will appear here.',
          ),
        ];
      }
      return [
        ...activeWithBids.map((auction) {
          final vehicle = auction['vehicle'] as Map<String, dynamic>;
          final car = Car.fromJson(vehicle);
          return _buildManageBidListingRow(car);
        }),
        if (extraWithBids.isNotEmpty && activeWithBids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              'Other active listings with bids',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700]),
            ),
          ),
        ...extraWithBids.map(_buildManageBidListingRow),
      ];
    }

    List<Widget> buildSoldRows() {
      if (soldCars.isEmpty) {
        return [
          const EmptyStateWidget(
            type: EmptyStateType.emptyCars,
            title: 'No sold vehicles',
            message: '',
          ),
        ];
      }
      return soldCars.map(_buildManageBidListingRow).toList();
    }

    List<Widget> buildPendingBidRows() {
      if (pendingBidCars.isEmpty) {
        return [
          const EmptyStateWidget(
            type: EmptyStateType.emptyCars,
            title: 'No pending bids',
            message: 'Listings with bids will show here.',
          ),
        ];
      }
      return pendingBidCars.map(_buildManageBidListingRow).toList();
    }

    final out = <Widget>[];
    switch (filter) {
      case 'all':
        out.addAll([
          sectionTitle('Active auctions'),
          ...buildActiveAuctionRows(),
        ]);
        if (swapOffers.isNotEmpty) {
          out.add(const SizedBox(height: 12));
          out.add(sectionTitle('Swap requests'));
          out.addAll(
            swapOffers.map(
              (offer) => _buildPendingOfferCard(
                car: Car.fromJson(offer['vehicle'] as Map<String, dynamic>),
                offerBy: offer['offerBy'] ?? 'Unknown',
                offerType: offer['type'],
              ),
            ),
          );
        }
        if (purchaseOffers.isNotEmpty) {
          out.add(const SizedBox(height: 12));
          out.add(sectionTitle('Direct sales'));
          out.addAll(
            purchaseOffers.map(
              (offer) => _buildPendingOfferCard(
                car: Car.fromJson(offer['vehicle'] as Map<String, dynamic>),
                offerBy: offer['offerBy'] ?? 'Unknown',
                offerType: offer['type'],
              ),
            ),
          );
        }
        if (soldCars.isNotEmpty) {
          out.add(const SizedBox(height: 12));
          out.add(sectionTitle('Sold'));
          out.addAll(buildSoldRows());
        }
        break;
      case 'pending_bids':
        out.add(sectionTitle('Pending bids'));
        out.addAll(buildPendingBidRows());
        break;
      case 'active_auctions':
        out.add(sectionTitle('Active auctions'));
        out.addAll(buildActiveAuctionRows());
        break;
      case 'swap':
        out.add(sectionTitle('Swap requests'));
        if (swapOffers.isEmpty) {
          out.add(
            const EmptyStateWidget(
              type: EmptyStateType.emptyCars,
              title: 'No swap requests',
              message: '',
            ),
          );
        } else {
          out.addAll(
            swapOffers.map(
              (offer) => _buildPendingOfferCard(
                car: Car.fromJson(offer['vehicle'] as Map<String, dynamic>),
                offerBy: offer['offerBy'] ?? 'Unknown',
                offerType: offer['type'],
              ),
            ),
          );
        }
        break;
      case 'direct_sales':
        out.add(sectionTitle('Direct sales'));
        if (purchaseOffers.isEmpty) {
          out.add(
            const EmptyStateWidget(
              type: EmptyStateType.emptyCars,
              title: 'No direct sale requests',
              message: 'Buy-now offers appear here.',
            ),
          );
        } else {
          out.addAll(
            purchaseOffers.map(
              (offer) => _buildPendingOfferCard(
                car: Car.fromJson(offer['vehicle'] as Map<String, dynamic>),
                offerBy: offer['offerBy'] ?? 'Unknown',
                offerType: offer['type'],
              ),
            ),
          );
        }
        break;
      case 'sold':
        out.add(sectionTitle('Sold'));
        out.addAll(buildSoldRows());
        break;
      default:
        out.add(sectionTitle('Active auctions'));
        out.addAll(buildActiveAuctionRows());
        break;
    }
    return out;
  }

  int _manageBidsSummaryCount(
    String filter,
    int activeCount,
    int swapLen,
    int purchaseLen,
    int soldLen,
    int pendingBidLen,
  ) {
    switch (filter) {
      case 'all':
        return activeCount + swapLen + purchaseLen + soldLen;
      case 'pending_bids':
        return pendingBidLen;
      case 'active_auctions':
        return activeCount;
      case 'swap':
        return swapLen;
      case 'direct_sales':
        return purchaseLen;
      case 'sold':
        return soldLen;
      default:
        return 0;
    }
  }

  Widget _buildSellerActiveSales() {
    return Obx(() {
      final filter = controller.manageBidsFilter.value;
      final pendingOffers = controller.pendingOffers;
      final liveAuctions = controller.liveAuctions;
      final extraCars = _extraSellerManageBidCars();
      final swapOffers = pendingOffers.where((offer) => offer['type'] == 'swap').toList();
      final purchaseOffers = pendingOffers.where((offer) => offer['type'] == 'buy_now').toList();
      final pendingBidCars = _sellerCarsWithPendingBids();
      final soldCars = _sellerSoldCars();

      // Filter active auctions to only those with bids (matching buildActiveAuctionRows logic)
      final activeWithBidsCount = liveAuctions.where((a) {
        final bc = a['bid_count'] ?? 0;
        return (bc is int ? bc : int.tryParse('$bc') ?? 0) > 0;
      }).length + extraCars.where((car) {
        final raw = controller.sellerVehicles.firstWhere(
          (v) => (v != null && v is Map) && (v['id']?.toString() == car.id),
          orElse: () => null,
        );
        if (raw == null) return false;
        final bc = raw['bid_count'] ?? 0;
        return (bc is int ? bc : int.tryParse('$bc') ?? 0) > 0;
      }).length;

      final summaryCount = _manageBidsSummaryCount(
        filter,
        activeWithBidsCount,
        swapOffers.length,
        purchaseOffers.length,
        soldCars.length,
        pendingBidCars.length,
      );

      final bodyItems = _gatherManageBidsBodyItems(filter);
      const stickyExtent = 130.0;
      // final double stickyExtent = _calculateStickyHeaderHeight();

      return RefreshIndicator(
        onRefresh: () async {
          await controller.fetchCars();
          await controller.fetchSellerDashboardData();
          await AutoSyncService.to.triggerManualSync();
        },
        color: kAccentColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _ManageBidsStickyHeaderDelegate(
                extent: stickyExtent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // Must match SliverPersistentHeader fixed extent to keep sliver geometry valid.
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      _buildManageBidsFilterRow(filter),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: kWhiteColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.grey[800]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                summaryCount == 0
                                    ? 'Pull down to refresh. Data updates from your listings and seller dashboard APIs.'
                                    : '${summaryCount == 1 ? '1 entry' : '$summaryCount entries'} — Use Manage on a row to open bids (accept/reject, history).',
                                style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Showing: ${_manageBidsEntriesLabel(filter)} entries',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                        ),
                      ),
                      // const SizedBox(height: 6),
                      // _buildManageBidsTableColumnHeaders(),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: bodyItems[index],
                    );
                  },
                  childCount: bodyItems.length,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Add this method to calculate header height
  double _calculateStickyHeaderHeight() {
    // Calculate based on your actual content
    double height = 0;

    // Filter row height (approximate)
    height += 50; // Adjust based on your _buildManageBidsFilterRow height

    // Spacing
    height += 8;

    // Info container height (approximate)
    height += 60; // Adjust based on actual content

    // Spacing
    height += 6;

    // "Showing:" text height
    height += 20;

    // Spacing
    height += 6;

    // Column headers height
    height += 40; // Adjust based on _buildManageBidsTableColumnHeaders height

    // Padding
    height += 16; // Padding from the Padding widget (top+bottom)

    return height;
  }

  Widget _buildPendingOfferCard({required Car car, required String offerBy, String? offerType}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: _buildCarImage(car.imageUrl, width: 40, height: 40, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${car.year} ${car.make} ${car.model}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
                Text('By: $offerBy', style: const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              offerType == 'swap' ? 'SWAP' : (offerType == 'buy_now' ? 'BUY NOW' : (offerType?.toUpperCase() ?? 'OFFER')),
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerInventory() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: ResponsiveHelper.isIPadDevice(context) ? 4 : 8,
          ),
          child: Row(
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  fontSize: ResponsiveHelper.isIPadDevice(context) 
                      ? 20 
                      : (ResponsiveHelper.isTablet(context) || ResponsiveHelper.isIPadOrTabletDevice(context) 
                          ? 22 
                          : 16),
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(

            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSellerSubTabButton('Active', 0),
                const SizedBox(width: 4),
                _buildSellerSubTabButton('Sold', 1),
                const SizedBox(width: 4),
                _buildSellerSubTabButton('Draft', 2),
                const SizedBox(width: 4),
                _buildSellerSubTabButton('Rejected', 3),
              ],
            ),
          ),
        ),
        _buildInventoryList(),
      ],
    );
  }

  Widget _buildInventoryList() {
    return RefreshIndicator(
      onRefresh: () async {
        await controller.fetchCars();
        await AutoSyncService.to.triggerManualSync();
      },
      color: kAccentColor,
      child: Obx(() {
        final cars = _getSellerInventoryCars();
        if (cars.isEmpty) {
          return const Padding(padding: EdgeInsets.all(20), child: EmptyStateWidget(type: EmptyStateType.emptyInventory, title: 'No Items', message: ''));
        }

        final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                         ResponsiveHelper.isTablet(context) ||
                         ResponsiveHelper.isIPhone12Size(context) ||
                         ResponsiveHelper.screenWidth(context) >= 600;

        // Use GridView for tablets/iPads, ListView for mobile
        if (isTablet) {
          final screenWidth = ResponsiveHelper.screenWidth(context);
          int crossAxisCount = 2;
          if (screenWidth >= 1200) {
            crossAxisCount = 3;
          } else if (screenWidth >= 900) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 2;
          }

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: cars.length,
            itemBuilder: (context, index) => _buildInventoryCard(cars[index]),
          );
        } else {
          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            itemCount: cars.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildInventoryCard(cars[index]),
            ),
          );
        }
      }),
    );
  }


  Widget _buildInventoryCard(Car car) {
    final isSold = controller.selectedSellerSubTab.value == 1;
    final isDraft = controller.selectedSellerSubTab.value == 2;
    final isActive = controller.selectedSellerSubTab.value == 0;

    // Check if we're in grid layout (tablets/iPads)
    final isTablet = ResponsiveHelper.isIPadOrTabletDevice(context) ||
                         ResponsiveHelper.isTablet(context) ||
                         ResponsiveHelper.isIPhone12Size(context) ||
                         ResponsiveHelper.screenWidth(context) >= 600;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 10), // Professional padding for tablets
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row with image and details
          Row(
            children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildCarImage(
                      car.imageUrl,
                      width: isTablet ? 80 : 50, // Professional image size for tablets
                      height: isTablet ? 80 : 50,
                      fit: BoxFit.cover,
                    ),
                  ),
              SizedBox(width: isTablet ? 16 : 10), // Professional spacing for tablets
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${car.year} ${car.make} ${car.model}',
                      style: TextStyle(
                        fontSize: isTablet ? _getCarCardTitleSize(context) : 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_formatNumberWithCommas(isSold ? (car.price ?? car.startingBid) : car.startingBid)}',
                      style: TextStyle(
                        fontSize: isTablet ? _getCarCardValueSize(context) : 11,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Mileage
                    Row(
                      children: [
                        Icon(Icons.speed, size: 8, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          '${_formatNumberWithCommas(car.mileage)} mi',
                          style: TextStyle(
                            fontSize: isTablet ? _getCarCardLocationSize(context) : 8,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Text(
                  isSold ? 'SOLD' : (isDraft ? 'DRAFT' : 'ACTIVE'),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isActive ? kAccentColor : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // View / Edit / Delete (same pattern as seller-inventory.php)
          _inventoryThreeActionsRow(car: car, isTablet: isTablet),
          if (isDraft) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleListNow(car),
                icon: const Icon(Icons.publish_outlined, size: 18),
                label: Text(
                  'List for auction',
                  style: TextStyle(
                    fontSize: isTablet ? _getCarCardButtonTextSize(context) : 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: kWhiteColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Car> _getSellerInventoryCars() {
    final allListings = controller.sellerListings;
    switch (controller.selectedSellerSubTab.value) {
      case 0: return allListings.where((car) => car.status == 'active').toList();
      case 1: return allListings.where((car) => car.status == 'sold').toList();
      case 2: return allListings.where((car) => car.status == 'draft').toList();
      case 3: return allListings.where((car) => car.status == 'rejected').toList();
      default: return [];
    }
  }

/*  Widget _buildInventoryCard(Car car) {
    final isSold = controller.selectedSellerSubTab.value == 1;
    final isDraft = controller.selectedSellerSubTab.value == 2;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(6), child: _buildCarImage(car.imageUrl, width: 50, height: 50, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${car.year} ${car.make} ${car.model}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1),
                    const SizedBox(height: 2),
                    Text('\$${_formatNumberWithCommas(isSold ? (car.price ?? car.startingBid) : car.startingBid)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSold ? kAccentColor : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          if (isDraft)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleListNow(car),
                      style: ElevatedButton.styleFrom(backgroundColor: kAccentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('List', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListVehicleScreen(car: car))),
                      style: OutlinedButton.styleFrom(foregroundColor: kAccentColor, side: const BorderSide(color: kAccentColor), padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Edit', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }*/

  Widget _buildSellerPerformance() {
    return Obx(() {
      if (controller.isLoading.value && controller.sellerStats.value == null) {
        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
      }

      return RefreshIndicator(
        onRefresh: () async {
          await controller.fetchSellerDashboardData();
          await AutoSyncService.to.triggerManualSync();
        },
        color: kAccentColor,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isIPadDevice(context) 
                        ? 20 
                        : (ResponsiveHelper.isTablet(context) || ResponsiveHelper.isIPadOrTabletDevice(context) 
                            ? 22 
                            : 16),
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final stats = controller.sellerStats.value;
                  final totalRevenue = stats?['totalRevenue'] ?? 0.0;
                  final totalSales = stats?['totalSales'] ?? 0;
                  final activeListings = stats?['activeListings'] ?? 0;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('Revenue', '\$${_formatNumberWithCommas(totalRevenue)}', Icons.attach_money, Colors.green)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Sales', totalSales.toString(), Icons.sell, Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('Active', activeListings.toString(), Icons.local_fire_department, Colors.blue)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricCard('Sold', totalSales.toString(), Icons.check_circle, Colors.green)),
                        ],
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 4), Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey))]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => TimezoneConfig.formatDateTime(date, format: 'MM/dd/yyyy, hh:mm:ss a');

  String _formatAuctionDateTime(DateTime dateTime) => TimezoneConfig.formatDateTime(dateTime, format: 'MMM d, y h:mm a');

  String _formatRemainingTime(DateTime auctionEndTime) {
    final difference = auctionEndTime.difference(DateTime.now());
    if (difference.isNegative) return 'Ended';
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    else if (hours > 0) return '${hours}h ${minutes}m';
    else return '${minutes}m';
  }

  Widget _buildAboutUsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Stack(
            children: [
              Container(height: 180, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/car1.png'), fit: BoxFit.cover)),
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.7)]))),
              ),
              Positioned(bottom: 20, left: 16, child: const Text('About CarXello', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Our Story', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/images/car2.png', width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 60, height: 60, color: Colors.grey[300]))),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('From San Francisco, we curate the world\'s most desired automobiles.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Why Choose us?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildFeatureCard(icon: Icons.gavel, text: 'Bid confidently from anywhere')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFeatureCard(icon: Icons.search, text: 'Every car is verified')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFeatureCard(icon: Icons.smartphone, text: 'Find cars on your phone')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: Column(children: [Icon(icon, size: 24, color: Colors.black), const SizedBox(height: 6), Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)]),
    );
  }

  Widget _buildContactUsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Stack(
            children: [
              Container(height: 160, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/car1.png'), fit: BoxFit.cover)),
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.7)]))),
              ),
              Positioned(bottom: 20, left: 16, child: const Text('Contact CarXello', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How Can we Help You?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildHelpCard(icon: Icons.email, text: 'Message')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHelpCard(icon: Icons.help_outline, text: 'FAQ')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHelpCard(icon: Icons.phone, text: 'Call')),
                  ],
                ),
                const SizedBox(height: 20),
                Form(
                  key: _contactFormKey,
                  child: Column(
                    children: [
                      _buildFormField(label: 'First Name', controller: _firstNameController, hint: 'John'),
                      const SizedBox(height: 12),
                      _buildFormField(label: 'Last Name', controller: _lastNameController, hint: 'Doe'),
                      const SizedBox(height: 12),
                      _buildFormField(label: 'Email', controller: _emailController, hint: 'email@example.com'),
                      const SizedBox(height: 12),
                      _buildFormField(label: 'Message', controller: _messageController, hint: 'Your message...', maxLines: 3),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmittingContact ? null : () async {
                            if (_contactFormKey.currentState!.validate()) {
                              setState(() => _isSubmittingContact = true);
                              try {
                                await _contactService.sendContactForm(
                                  firstName: _firstNameController.text,
                                  lastName: _lastNameController.text,
                                  email: _emailController.text,
                                  message: _messageController.text, subject: '',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent!'), backgroundColor: Colors.green));
                                  _firstNameController.clear();
                                  _lastNameController.clear();
                                  _emailController.clear();
                                  _messageController.clear();
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              } finally {
                                if (mounted) setState(() => _isSubmittingContact = false);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kAccentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          child: _isSubmittingContact ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: Column(children: [Icon(icon, size: 20, color: Colors.black), const SizedBox(height: 4), Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey))]),
    );
  }

  Widget _buildFormField({required String label, required TextEditingController controller, required String hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccentColor)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 12),
          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context, {int? initialSection}) {
    final initialFilters = _convertBackendFiltersToFrontend(controller.currentFilters);
    final dynamicOptions = _buildDynamicFilterOptions();

    final initialWithSort = <String, dynamic>{
      ...initialFilters,
      if (controller.currentSortBy != null) 'sortBy': controller.currentSortBy,
      if (initialSection != null) '_initialSection': initialSection,
    };

    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialFilters: initialWithSort,
          dynamicOptions: dynamicOptions,
        ),
      ),
    ).then((filterResults) {
      if (filterResults != null && filterResults is Map<String, dynamic>) {
        // ── Sort ──
        final selectedSort = (filterResults['sort'] ?? filterResults['sortBy'])?.toString();
        if (selectedSort != null && selectedSort.isNotEmpty) {
          setState(() => _selectedSortOption = selectedSort);
          controller.currentSortBy = selectedSort;
        }

        final filters = <String, dynamic>{};

        // Helper to read value from new or old key
        String? _v(String newKey, [String? oldKey]) {
          final val = filterResults[newKey] ?? (oldKey != null ? filterResults[oldKey] : null);
          if (val == null) return null;
          final s = val.toString().trim();
          return s.isEmpty ? null : s;
        }

        // ── Year ──
        final yearMin = _v('year_min', 'minYear');
        final yearMax = _v('year_max', 'maxYear');
        if (yearMin != null) filters['year_min'] = int.tryParse(yearMin) ?? 0;
        if (yearMax != null) filters['year_max'] = int.tryParse(yearMax) ?? 9999;

        // ── Make & Model ──
        if (filterResults['makes'] is List && (filterResults['makes'] as List).isNotEmpty) {
          filters['make'] = (filterResults['makes'] as List).join(',');
        } else if (_v('make') != null) {
          filters['make'] = _v('make');
        }
        if (filterResults['models'] is List && (filterResults['models'] as List).isNotEmpty) {
          filters['model'] = (filterResults['models'] as List).join(',');
        } else if (_v('model') != null) {
          filters['model'] = _v('model');
        }

        // ── Price & Mileage ──
        final priceMin = _v('price_min', 'minPrice');
        final priceMax = _v('price_max', 'maxPrice');
        if (priceMin != null) filters['price_min'] = double.tryParse(priceMin) ?? 0;
        if (priceMax != null) filters['price_max'] = double.tryParse(priceMax) ?? 999999;
        final odoMin = _v('mileage_min', 'fromOdometer');
        final odoMax = _v('mileage_max', 'toOdometer');
        if (odoMin != null) filters['odometer_min'] = int.tryParse(odoMin) ?? 0;
        if (odoMax != null) filters['odometer_max'] = int.tryParse(odoMax) ?? 999999;

        // ── Fuel & Transmission ──
        final fuel = _v('fuel_type', 'engineFuelType');
        if (fuel != null) filters['fuel_type'] = fuel;
        final trans = _v('transmission', 'driveTrain');
        if (trans != null) filters['drive_train'] = trans;

        // ── Colors ──
        final extColor = _v('exterior_color', 'exteriorInteriorColor');
        if (extColor != null) filters['exterior_color'] = extColor;
        final intColor = _v('interior_color');
        if (intColor != null) filters['interior_color'] = intColor;

        // ── Location ──
        final loc = _v('location', 'zipCode');
        if (loc != null) filters['location_zip'] = loc;
        final dist = _v('distance');
        if (dist != null) filters['radius'] = double.tryParse(dist) ?? 0;
        final radius = _v('radius');
        if (radius != null) filters['radius'] = double.tryParse(radius) ?? 0;

        // ── New backend filters ──
        final condition = _v('condition');
        if (condition != null) filters['condition'] = condition;
        final bodyStyle = _v('body_style', 'bodyStyle');
        if (bodyStyle != null) filters['body_style'] = bodyStyle;
        final sellerType = _v('seller_type', 'sellerType');
        if (sellerType != null) filters['seller_type'] = sellerType;
        final doors = _v('doors');
        if (doors != null) filters['doors'] = doors;
        final openingPrice = _v('opening_price', 'openingPrice');
        if (openingPrice != null) filters['opening_price'] = double.tryParse(openingPrice) ?? 0;
        final plantCountry = _v('plant_country');
        if (plantCountry != null) filters['plant_country'] = plantCountry;

        // ── Legacy / additional boolean filters ──
        if (filterResults['third_party_inspected'] == true || filterResults['thirdPartyInspection'] == true) filters['third_party_inspected'] = true;
        if (filterResults['exclude_red_light'] == true || filterResults['excludeRedLight'] == true) filters['exclude_red_light'] = true;
        if (filterResults['exclude_smoker'] == true || filterResults['excludeSmokers'] == true) filters['exclude_smokers'] = true;
        if (filterResults['exclude_reviewed'] == true || filterResults['excludeReviewedVehicles'] == true) filters['exclude_reviewed'] = true;

        // Spread & Max Book Value & Book Type (legacy)
        if (_v('spread') != null) filters['spread'] = double.tryParse(_v('spread')!) ?? 0;
        if (_v('maxBookValue', 'max_book_value') != null) filters['max_book_value'] = double.tryParse(_v('maxBookValue', 'max_book_value')!) ?? 0;
        if (_v('bookValue', 'book_value') != null) filters['book_value'] = _v('bookValue', 'book_value');

        if (filterResults['oneHundredOpeningPrice'] == true) filters['opening_price_100'] = true;
        if (filterResults['newReducedPrice'] == true) filters['new_reduced_price'] = true;
        if (filterResults['excludeMyPostings'] == true) filters['exclude_my_postings'] = true;

        controller.fetchCars(filters: filters.isEmpty ? null : filters, sortBy: controller.currentSortBy);
      } else if (filterResults != null && filterResults is Map<String, dynamic> && filterResults.isEmpty) {
        controller.fetchCars(filters: null, sortBy: controller.currentSortBy);
      }
    });
  }

  Map<String, dynamic> _buildDynamicFilterOptions() {
    // Build options from all locally available vehicle sources so user sees
    // maximum available makes/models/colors in filter UI.
    final allCars = <Car>[
      ...controller.carList,
      ...controller.wonVehicles,
      ...controller.purchaseHistory,
      ...controller.sellerListings,
    ];
    final seenIds = <String>{};
    final cars = <Car>[];
    for (final c in allCars) {
      if (seenIds.add(c.id)) {
        cars.add(c);
      }
    }

    List<String> _sortedUnique(Iterable<String?> values) {
      final list = values
          .whereType<String>()
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return list;
    }

    final makes = _sortedUnique(cars.map((c) => c.make));
    final models = _sortedUnique(cars.map((c) => c.model));
    final fuels = _sortedUnique(cars.map((c) => c.fuelType));
    final transmissions = _sortedUnique(cars.map((c) => c.driveTrain));
    Iterable<String> _splitColorTokens(String? raw) sync* {
      if (raw == null) return;
      final tokens = raw
          .split(RegExp(r'[,/|;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final t in tokens) {
        yield t;
      }
    }

    final colorCounts = <String, int>{};
    for (final c in cars) {
      for (final token in _splitColorTokens(c.exteriorColor)) {
        colorCounts[token] = (colorCounts[token] ?? 0) + 1;
      }
      for (final token in _splitColorTokens(c.interiorColor)) {
        colorCounts[token] = (colorCounts[token] ?? 0) + 1;
      }
    }
    final colors = colorCounts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final years = cars
        .map((c) => c.year)
        .where((y) => y > 0)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final makeModels = <String, Set<String>>{};
    final makeCounts = <String, int>{};
    final modelCounts = <String, int>{};
    for (final c in cars) {
      final make = c.make.trim();
      final model = c.model.trim();
      if (make.isNotEmpty) {
        makeCounts[make] = (makeCounts[make] ?? 0) + 1;
      }
      if (model.isNotEmpty) {
        modelCounts[model] = (modelCounts[model] ?? 0) + 1;
      }
      if (make.isNotEmpty && model.isNotEmpty) {
        makeModels.putIfAbsent(make, () => <String>{}).add(model);
      }
    }

    return {
      'makes': makes,
      'models': models,
      'fuels': fuels,
      'transmissions': transmissions,
      'colors': colors,
      'color_counts': colorCounts,
      'years': years.map((y) => y.toString()).toList(),
      'make_models': makeModels.map((k, v) {
        final list = v.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return MapEntry(k, list);
      }),
      'make_counts': makeCounts,
      'model_counts': modelCounts,
      'cars_for_count': cars.map((c) {
        return {
          'id': c.id,
          'year': c.year,
          'make': c.make,
          'model': c.model,
          'price': c.price,
          'starting_bid': c.startingBid,
          'buy_now_price': c.buyNowPrice,
          'mileage': c.mileage,
          'fuel_type': c.fuelType,
          'drive_train': c.driveTrain,
          'exterior_color': c.exteriorColor,
          'interior_color': c.interiorColor,
          'location': c.location,
          'distance': c.distance,
          'condition': c.condition,
          'title_status': c.titleStatus,
          'engine_type': c.engineType,
          'status': c.status,
        };
      }).toList(),
    };
  }

  int _getActiveFilterCount() {
    int count = 0;
    final filters = controller.currentFilters;
    if (filters == null || filters.isEmpty) return 0;

    filters.forEach((key, value) {
      if (value != null) {
        if (value is String && value.isNotEmpty) {
          // If it's a comma separated list, maybe count differently? No, let's keep it simple: any filter = 1
          count++;
        } else if (value is bool && value == true) {
          count++;
        } else if (value is num && value != 0) {
          // Radius 0, Year 0/9999 etc are defaults
          if (key == 'year_min' && value == 0) return;
          if (key == 'year_max' && value == 9999) return;
          if (key == 'price_min' && value == 0) return;
          if (key == 'price_max' && value == 999999) return;
          count++;
        }
      }
    });
    return count;
  }

  Map<String, dynamic> _convertBackendFiltersToFrontend(Map<String, dynamic>? backendFilters) {
    if (backendFilters == null || backendFilters.isEmpty) return {};
    final frontendFilters = <String, dynamic>{};

    // Pass backend keys directly — the new FilterScreen reads both formats
    backendFilters.forEach((key, value) {
      if (value != null) frontendFilters[key] = value;
    });

    // Also map old frontend key aliases for backward compat
    if (backendFilters['year_min'] != null) frontendFilters['minYear'] = backendFilters['year_min'].toString();
    if (backendFilters['year_max'] != null) frontendFilters['maxYear'] = backendFilters['year_max'].toString();
    if (backendFilters['make'] != null) frontendFilters['make'] = backendFilters['make'].toString();
    if (backendFilters['model'] != null) frontendFilters['model'] = backendFilters['model'].toString();
    if (backendFilters['price_min'] != null) frontendFilters['minPrice'] = backendFilters['price_min'].toString();
    if (backendFilters['price_max'] != null) frontendFilters['maxPrice'] = backendFilters['price_max'].toString();
    if (backendFilters['odometer_min'] != null) frontendFilters['fromOdometer'] = backendFilters['odometer_min'].toString();
    if (backendFilters['odometer_max'] != null) frontendFilters['toOdometer'] = backendFilters['odometer_max'].toString();
    if (backendFilters['fuel_type'] != null) frontendFilters['engineFuelType'] = backendFilters['fuel_type'].toString();
    if (backendFilters['exterior_color'] != null) frontendFilters['exteriorInteriorColor'] = backendFilters['exterior_color'].toString();
    if (backendFilters['drive_train'] != null) frontendFilters['driveTrain'] = backendFilters['drive_train'].toString();
    if (backendFilters['radius'] != null) frontendFilters['radius'] = backendFilters['radius'].toString();
    if (backendFilters['location_zip'] != null) frontendFilters['zipCode'] = backendFilters['location_zip'].toString();

    if (backendFilters['exclude_reviewed'] == true) frontendFilters['excludeReviewedVehicles'] = true;
    if (backendFilters['exclude_smokers'] == true) frontendFilters['excludeSmokers'] = true;
    if (backendFilters['exclude_red_light'] == true) frontendFilters['excludeRedLight'] = true;
    if (backendFilters['third_party_inspected'] == true) frontendFilters['thirdPartyInspection'] = true;

    return frontendFilters;
  }

  void _handleAcceptOffer(Car car, String offerBy, {String? offerId, String? offerType}) {}
  void _handleDeclineOffer(Car car, String offerBy, {String? offerId, String? offerType}) {}
  void _handleFinalizeSale(Car car) {}
  void _handleViewBids(Car car) {}
  void _handleListNow(Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ListVehicleScreen(car: car)),
    ).then((_) {
      controller.fetchCars();
      controller.fetchSellerDashboardData();
    });
  }
  void _handleEndAuction(Car car) {}

  void _openInventoryView(Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductDetailsScreen(car: car)),
    );
  }

  void _openInventoryEdit(Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ListVehicleScreen(car: car)),
    ).then((_) {
      controller.fetchCars();
      controller.fetchSellerDashboardData();
    });
  }

  Widget _inventoryThreeActionsRow({
    required Car car,
    required bool isTablet,
  }) {
    final iconSize = isTablet ? 20.0 : 18.0;
    final fontSize = isTablet ? _getCarCardButtonTextSize(context) : 10.0;
    ButtonStyle outlinedStyle(bool destructive) => OutlinedButton.styleFrom(
          foregroundColor: destructive ? Colors.grey[800] : kAccentColor,
          side: BorderSide(color: destructive ? Colors.grey[500]! : kAccentColor, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openInventoryView(car),
            icon: Icon(Icons.visibility_outlined, size: iconSize),
            label: Text('View', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
            style: outlinedStyle(false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openInventoryEdit(car),
            icon: Icon(Icons.edit_outlined, size: iconSize),
            label: Text('Edit', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
            style: outlinedStyle(false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showDeleteConfirmation(car),
            icon: Icon(Icons.delete_outline, size: iconSize),
            label: Text('Delete', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
            style: outlinedStyle(true),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(Car car) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Vehicle?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Remove ${car.year} ${car.make} ${car.model}?\n\nNote: If this vehicle has active bids, it can only be archived.', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              _handleListingRemoval(car, false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleListingRemoval(Car car, bool forceArchive) async {
    final messenger = ScaffoldMessenger.of(context);
    
    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      if (forceArchive) {
        await CarService().archiveVehicle(car.id);
      } else {
        try {
          await CarService().deleteVehicle(car.id);
        } catch (e) {
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('auction/bid history') || errorMsg.contains('archive')) {
            // If delete fails because of history, suggest archive
            if (mounted) {
              Navigator.pop(context); // Close loading
              _showArchiveSuggestion(car);
              return;
            }
          }
          rethrow;
        }
      }
      
      await controller.fetchCars();
      await controller.fetchSellerDashboardData();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        messenger.showSnackBar(
          SnackBar(
            content: Text(forceArchive ? 'Listing archived' : 'Listing removed'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: kBlackColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.grey[900],
          ),
        );
      }
    }
  }

  void _showArchiveSuggestion(Car car) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Action Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          'This vehicle has bid history and cannot be fully deleted.\n\n'
          'Would you like to archive it instead? It will be removed from your active list but remain in system history.',
          style: TextStyle(fontSize: 13)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleListingRemoval(car, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor, foregroundColor: Colors.white),
            child: const Text('Archive Instead', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Color _getPurchaseMethodColor(String? method) => method == 'bidding' ? Colors.green : method == 'buy_now' ? Colors.blue : method == 'swap' ? Colors.orange : Colors.grey;
  IconData _getPurchaseMethodIcon(String? method) => method == 'bidding' ? Icons.gavel : method == 'buy_now' ? Icons.shopping_cart : method == 'swap' ? Icons.swap_horiz : Icons.info;
  String _getPurchaseMethodLabel(String? method) => method == 'bidding' ? 'Bidding' : method == 'buy_now' ? 'Buy Now' : method == 'swap' ? 'Swap' : 'Purchase';
}

/// Pinned filters + summary + table headers for Manage bids (matches web seller-bids sticky bar).
class _ManageBidsStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ManageBidsStickyHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.grey[50],
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black26,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ManageBidsStickyHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}

class _PinnedActionBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedActionBarDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final Widget child;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedActionBarDelegate oldDelegate) {
    return maxExtent != oldDelegate.maxExtent ||
        minExtent != oldDelegate.minExtent ||
        child != oldDelegate.child;
  }
}
