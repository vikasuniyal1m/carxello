import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:carauction/screens/chat_screen.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/utils/drawer_menu.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../utils/preferences_helper.dart';

class TransporterDashboardScreen extends StatefulWidget {
  const TransporterDashboardScreen({super.key});

  @override
  State<TransporterDashboardScreen> createState() => _TransporterDashboardScreenState();
}

class _TransporterDashboardScreenState extends State<TransporterDashboardScreen> {
  int _selectedMainTab = 0;
  int _selectedDrawerIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentCarouselIndex = 0;
  final ScrollController _scrollController = ScrollController();

  final List<String> _carouselImages = [
    'assets/images/car1.png',
    'assets/images/car2.png',
    'assets/images/car3.png',
  ];

  Map<String, dynamic>? _dashboardData;
  bool _isLoading = false;
  final TransportService _transportService = TransportService();

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _userData;
  List<dynamic> _transportOrders = [];
  List<dynamic> _pickupSchedules = [];
  List<dynamic> _contacts = [];
  int _unreadMessagesCount = 0;

  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _orderIdController = TextEditingController();
  Map<String, dynamic>? _trackingData;

  String? _selectedOrderId;
  String? _selectedVIN;
  String? _selectedVehicleName;
  String? _selectedBuyerName;
  String? _selectedDeliveryAddress;
  File? _selectedImage;
  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _deliveryNotesController = TextEditingController();

  final TextEditingController _messageToController = TextEditingController();
  final TextEditingController _messageSubjectController = TextEditingController();
  final TextEditingController _messageContentController = TextEditingController();

  final List<String> defaultImages = [
    'assets/images/car1.png',
    'assets/images/car2.png',
    'assets/images/car3.png',
  ];

  Widget _buildVehicleImageWidget(String? imageUrl, {double width = 80, double height = 80, int index = 0}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl != null &&
            imageUrl.isNotEmpty &&
            (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))
            ? Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              defaultImages[index % defaultImages.length],
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        )
            : Image.asset(
          imageUrl ?? defaultImages[index % defaultImages.length],
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              defaultImages[index % defaultImages.length],
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureAuthAndRole();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vinController.dispose();
    _orderIdController.dispose();
    _recipientNameController.dispose();
    _deliveryNotesController.dispose();
    _messageToController.dispose();
    _messageSubjectController.dispose();
    _messageContentController.dispose();
    super.dispose();
  }

  Future<void> _ensureAuthAndRole() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }
      final role = await PreferencesHelper.getUserRole();
      if ((role ?? '').toLowerCase() != 'transporter') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transporter access required. Please login as transporter.')),
          );
        }
        return;
      }
      _loadDashboardData();
    } catch (_) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _transportService.getDashboard();
      setState(() {
        _dashboardData = data;
        _userData = data['user_data'] as Map<String, dynamic>?;
        _stats = data['stats'] as Map<String, dynamic>?;
        _transportOrders = data['transport_orders'] as List<dynamic>? ?? [];
        _contacts = data['contacts'] as List<dynamic>? ?? [];
        _unreadMessagesCount = (data['unread_messages'] as Map<String, dynamic>?)?['unread_count'] ?? 0;
      });
      try {
        final pickups = await _transportService.getPickupSchedule();
        setState(() {
          _pickupSchedules = pickups.map((order) {
            final vehicle = order['vehicle'] as Map<String, dynamic>? ?? {};
            return {
              ...order,
              'make': order['make'] ?? vehicle['make'],
              'model': order['model'] ?? vehicle['model'],
              'year': order['year'] ?? vehicle['year'],
              'vin': order['vin'] ?? vehicle['vin'],
              'photo_url': order['photo_url'] ?? vehicle['imageUrl'],
              'pickup_date': order['pickup_date'] ?? order['scheduled_pickup_date'],
              'pickup_city': order['pickup_city'] ?? order['pickup_location'] ?? '',
              'pickup_state': order['pickup_state'] ?? '',
              'pickup_zip': order['pickup_zip'] ?? '',
            };
          }).toList();
        });
      } catch (e) {
        print('⚠️ Failed to load pickup schedule from API, falling back to dashboard orders: $e');
        setState(() {
          _pickupSchedules = _transportOrders.where((order) {
            final s = (order['status'] ?? order['transport_status'] ?? 'pending').toString().toLowerCase();
            return s == 'pending' || s == 'pickup_scheduled';
          }).map((order) {
            return {
              ...order,
              'pickup_city': order['pickup_city'] ?? order['pickup_location'] ?? '',
              'pickup_state': order['pickup_state'] ?? '',
              'pickup_zip': order['pickup_zip'] ?? '',
            };
          }).toList();
        });
      }
      print('✅ Dashboard data loaded successfully');
    } catch (e) {
      print('❌ ERROR loading dashboard data: $e');
      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('unauthenticated') || errorStr.contains('401')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login required. Redirecting...')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else if (!errorStr.contains('404') || !errorStr.contains('transport order')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load dashboard data: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          print('⚠️ Transport order not found (404) - this is normal if no orders exist');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      drawer: DrawerMenu(
        selectedIndex: _selectedDrawerIndex,
        hideBuyerSellerSwitch: true,
        onItemSelected: (index) {
          setState(() {
            _selectedDrawerIndex = index;
          });
        },
      ),
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            const Text(
              'San Francisco',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: kAccentColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            children: [
              _buildCarouselBanner(),
              _buildCarouselIndicators(),
              _buildStatisticsCards(),
              _buildMainTabButtons(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselBanner() {
    return Stack(
      children: [
        CarouselSlider(
          carouselController: _carouselController,
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.35,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            viewportFraction: 1.0,
            onPageChanged: (index, reason) {
              setState(() => _currentCarouselIndex = index);
            },
          ),
          items: _carouselImages.map((image) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(image),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Partnership, value, and growth',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        Positioned(
          bottom: ResponsiveHelper.spacing(context, 10),
          left: ResponsiveHelper.spacing(context, 10),
          child: Container(
            padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_currentCarouselIndex + 1}/${_carouselImages.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _carouselImages.asMap().entries.map((entry) {
        return Container(
          width: ResponsiveHelper.spacing(context, 8),
          height: ResponsiveHelper.spacing(context, 8),
          margin: ResponsiveHelper.padding(context, horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentCarouselIndex == entry.key
                ? kAccentColor
                : Colors.grey[300],
          ),
        );
      }).toList(),
    );
  }

/*  Widget _buildStatisticsCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Orders',
              _stats!['total_orders']?.toString() ?? '0',
              kAccentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Active Transports',
              _stats!['active_transports']?.toString() ?? '0',
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Pending Pickups',
              _stats!['pending_pickups']?.toString() ?? '0',
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Deliveries Today',
              _stats!['deliveries_today']?.toString() ?? '0',
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }*/

  Widget _buildStatisticsCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Orders',
              _stats!['total_orders']?.toString() ?? '0',
              kAccentColor,
              Icons.shopping_bag_outlined,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStatCard(
              'Active Transports',
              _stats!['active_transports']?.toString() ?? '0',
              Colors.blue,
              Icons.local_shipping_outlined,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStatCard(
              'Pending Pickups',
              _stats!['pending_pickups']?.toString() ?? '0',
              Colors.orange,
              Icons.pending_actions_outlined,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStatCard(
              'Deliveries Today',
              _stats!['deliveries_today']?.toString() ?? '0',
              Colors.green,
              Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        children: [
          // Icon and Number
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

 /* Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }*/

  Widget _buildMainTabButtons() {
    final tabs = [
      'Pickup Schedules',
      'Delivery Timelines',
      'Proof of Delivery',
      'Communication',
      'Track Orders',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildTabButton(tabs[index], index),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedMainTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMainTab = index);
        if (_dashboardData == null) {
          _loadDashboardData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccentColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kAccentColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _dashboardData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dashboardData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: ResponsiveHelper.spacing(context, 64), color: Colors.red),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            const Text('Failed to load dashboard data'),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    switch (_selectedMainTab) {
      case 0:
        return _buildPickupSchedules();
      case 1:
        return _buildDeliveryTimelines();
      case 2:
        return _buildProofOfDelivery();
      case 3:
        return _buildCommunication();
      case 4:
        return _buildTrackOrders();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildPickupSchedules() {
    final pendingOrders = _pickupSchedules.where((order) {
      final s = (order['transport_status'] ?? order['status'] ?? 'pending').toString().toLowerCase();
      return s == 'pending' || s == 'pickup_scheduled';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Pickup Schedules',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (pendingOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.calendar_today, size: ResponsiveHelper.spacing(context, 64), color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pickup Schedules',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('You don\'t have any pending pickups scheduled.'),
                ],
              ),
            )
          else
            ...pendingOrders.map((order) => _buildPickupScheduleCard(
              Map<String, dynamic>.from(order as Map),
            )),
        ],
      ),
    );
  }

  Widget _buildPickupScheduleCard(Map<String, dynamic> order) {
    final make = order['make'] ?? 'N/A';
    final model = order['model'] ?? 'N/A';
    final year = order['year'] ?? '';
    final vin = order['vin'] ?? 'N/A';
    final photoUrl = order['photo_url'];
    final pickupCity = order['pickup_city'] ?? 'N/A';
    final pickupState = order['pickup_state'] ?? '';
    final pickupZip = order['pickup_zip'] ?? '';
    final pickupDate = order['pickup_date'];
    final scheduledDate = pickupDate != null
        ? DateTime.parse(pickupDate).toString().split(' ')[0]
        : 'Not Scheduled';
    final scheduledTime = pickupDate != null
        ? DateTime.parse(pickupDate).toString().split(' ')[1].substring(0, 5)
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildVehicleImageWidget(
                photoUrl,
                width: 60,
                height: 60,
                index: order['id'] ?? 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$make $model $year',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIN: $vin',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                        Expanded(
                          child: Text(
                            '$pickupCity, $pickupState $pickupZip',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Schedule: $scheduledDate $scheduledTime',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Text(
              'PENDING PICKUP',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final canClaim = order['can_claim'] == true;
                    final id = (order['id'] ?? '').toString();
                    if (canClaim) {
                      _claimAndMarkPickupComplete(id);
                    } else {
                      _confirmPickup(id);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Confirm Pickup',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showUpdateETADialog(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Update ETA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTimelines() {
    final activeOrders = _transportOrders.where((order) =>
    order['status'] == 'pending' || order['status'] == 'in_transit'
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Timelines',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (activeOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.local_shipping, size: ResponsiveHelper.spacing(context, 64), color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Deliveries',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('You don\'t have any active deliveries at the moment.'),
                ],
              ),
            )
          else
            ...activeOrders.map((order) => _buildDeliveryTimelineCard(order)),
        ],
      ),
    );
  }

  Widget _buildDeliveryTimelineCard(Map<String, dynamic> order) {
    final make = order['make'] ?? 'N/A';
    final model = order['model'] ?? 'N/A';
    final year = order['year'] ?? '';
    final vin = order['vin'] ?? 'N/A';
    final photoUrl = order['photo_url'];
    final status = order['status'] ?? 'in_transit';
    final deliveryDate = order['delivery_date'];
    final deliveryDateStr = deliveryDate != null
        ? DateTime.parse(deliveryDate).toString().split(' ')[0]
        : 'Not Set';

    final deliveryCity = order['delivery_city'] ?? '';
    final deliveryState = order['delivery_state'] ?? '';
    final deliveryLocation = (deliveryCity.isNotEmpty && deliveryState.isNotEmpty)
        ? '$deliveryCity, $deliveryState'
        : 'null, null';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildVehicleImageWidget(
                photoUrl,
                width: 60,
                height: 60,
                index: order['id'] ?? 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$make $model ($year)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIN: $vin',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current Location: In Transit',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Delivery To: $deliveryLocation',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estimated Delivery: $deliveryDateStr',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Text(
              'IN TRANSIT',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          if (deliveryCity.isNotEmpty && deliveryState.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showUpdateETADialog(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'UPDATE ETA',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showUpdateLocationDialog(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Update Location',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showUpdateETADialog(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'UPDATE ETA',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

 /* Widget _buildProofOfDelivery() {
    final deliverableOrders = _transportOrders.where((order) =>
    order['status'] == 'in_transit' && (order['has_pod'] == 0 || order['has_pod'] == false)
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proof of Delivery',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload delivery confirmation for vehicles in transit',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          if (deliverableOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'No Deliveries Ready',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All vehicles in transit already have proof of delivery',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Vehicle',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedOrderId,
                      isExpanded: true,
                      hint: const Text('-- Select Vehicle --'),
                      icon: const Icon(Icons.arrow_drop_down),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: deliverableOrders.map((order) {
                        final vin = order['vin'] ?? 'N/A';
                        final make = order['make'] ?? '';
                        final model = order['model'] ?? '';
                        return DropdownMenuItem<String>(
                          value: order['id'].toString(),
                          child: Text(
                            '$vin - $make $model',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final order = deliverableOrders.firstWhere((o) => o['id'].toString() == value);
                          setState(() {
                            _selectedOrderId = value;
                            _selectedVIN = order['vin'];
                            _selectedVehicleName = '${order['make']} ${order['model']}';
                            _selectedBuyerName = order['buyer_name'];
                            _selectedDeliveryAddress = '${order['delivery_city']}, ${order['delivery_state']}';
                          });
                        }
                      },
                    ),
                  ),

                  if (_selectedOrderId != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_car, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedVehicleName ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow('VIN', _selectedVIN ?? ''),
                          _buildDetailRow('Buyer', _selectedBuyerName ?? ''),
                          _buildDetailRow('Delivery', _selectedDeliveryAddress ?? ''),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recipient Information',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _recipientNameController,
                    decoration: InputDecoration(
                      labelText: 'Recipient Name',
                      hintText: 'Enter recipient name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _deliveryNotesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Delivery Notes',
                      hintText: 'Add any notes about the delivery...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Proof',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() => _selectedImage = File(image.path));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedImage != null ? Colors.green : Colors.grey[300]!,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedImage != null ? Icons.check_circle : Icons.cloud_upload,
                            size: 32,
                            color: _selectedImage != null ? Colors.green : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedImage != null
                                ? _selectedImage!.path.split('/').last
                                : 'Tap to select file',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedImage != null ? Colors.green : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedImage == null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Max 5 MB',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOrderId != null &&
                    _selectedVIN != null &&
                    _selectedImage != null &&
                    _recipientNameController.text.isNotEmpty
                    ? () => _submitProofOfDelivery()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Submit Proof of Delivery',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }*/


  Widget _buildProofOfDelivery() {
    final deliverableOrders = _transportOrders.where((order) =>
    order['status'] == 'in_transit' && (order['has_pod'] == 0 || order['has_pod'] == false)
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Proof of Delivery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'Upload delivery confirmation',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          if (deliverableOrders.isEmpty)
          // Empty State - Compact
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'No Deliveries Ready',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All vehicles have POD',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
          // Show all cards when orders exist
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Selection Card - Compact
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Vehicle',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Dropdown
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedOrderId,
                          isExpanded: true,
                          hint: const Text('-- Select --', style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          items: deliverableOrders.map((order) {
                            final vin = order['vin'] ?? 'N/A';
                            final make = order['make'] ?? '';
                            final model = order['model'] ?? '';
                            return DropdownMenuItem<String>(
                              value: order['id'].toString(),
                              child: Text(
                                '$vin - $make $model',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              final order = deliverableOrders.firstWhere((o) => o['id'].toString() == value);
                              setState(() {
                                _selectedOrderId = value;
                                _selectedVIN = order['vin'];
                                _selectedVehicleName = '${order['make']} ${order['model']}';
                                _selectedBuyerName = order['buyer_name'];
                                _selectedDeliveryAddress = '${order['delivery_city']}, ${order['delivery_state']}';
                              });
                            }
                          },
                        ),
                      ),

                      // Selected Vehicle Details - Compact
                      if (_selectedOrderId != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Column(
                            children: [
                              _buildCompactDetailRow(Icons.directions_car, _selectedVehicleName ?? ''),
                              const SizedBox(height: 4),
                              _buildCompactDetailRow(Icons.qr_code, 'VIN: ${_selectedVIN ?? ''}'),
                              const SizedBox(height: 4),
                              _buildCompactDetailRow(Icons.person, 'Buyer: ${_selectedBuyerName ?? ''}'),
                              const SizedBox(height: 4),
                              _buildCompactDetailRow(Icons.location_on, 'Deliver: ${_selectedDeliveryAddress ?? ''}'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Recipient Info Card - Compact
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recipient',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: _recipientNameController,
                        decoration: InputDecoration(
                          hintText: 'Recipient name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _deliveryNotesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Notes (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Upload Card - Compact
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proof Image',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setState(() => _selectedImage = File(image.path));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selectedImage != null ? Colors.green : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 6),
                              Icon(
                                _selectedImage != null ? Icons.check_circle : Icons.cloud_upload,
                                size: 18,
                                color: _selectedImage != null ? Colors.green : Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedImage != null
                                      ? _selectedImage!.path.split('/').last
                                      : 'Tap to select file',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _selectedImage != null ? Colors.green : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Submit Button - Compact
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedOrderId != null &&
                        _selectedVIN != null &&
                        _selectedImage != null &&
                        _recipientNameController.text.isNotEmpty
                        ? () => _submitProofOfDelivery()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Submit POD',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

// Helper for compact detail rows
  Widget _buildCompactDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.blue[700]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(':', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunication() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Communication',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_unreadMessagesCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_unreadMessagesCount unread',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: ResponsiveHelper.spacing(context, 64), color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Contacts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('You don\'t have any contacts yet.'),
                ],
              ),
            )
          else ...[
            const Text(
              'Your Contacts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._contacts.map((contact) => _buildContactCard(contact)),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kAccentColor,
            child: Text(
              (contact['full_name'] ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['full_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact['email'] ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: contact['role'] == 'buyer' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (contact['role']?.toString().toUpperCase() ?? 'UNKNOWN'),
                    style: TextStyle(
                      color: contact['role'] == 'buyer' ? Colors.blue : Colors.green,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.message, size: 18),
            onPressed: () async {
              try {
                final otherId = contact['id'].toString();
                final me = _userData?['id']?.toString();
                if (me != null && me.isNotEmpty && me == otherId) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot message yourself.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }
                final chatService = ChatService();
                final conversation = await chatService.getOrCreateConversation(
                  otherUserId: otherId,
                );
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversationId: conversation['id'].toString(),
                        otherUserName: contact['full_name'] ?? 'Unknown',
                        otherUserId: contact['id'].toString(),
                        currentUserId: _userData?['id']?.toString(),
                      ),
                    ),
                  );
                }
              } catch (e) {
                print('❌ ERROR opening chat: $e');
              }
            },
          ),
        ],
      ),
    );
  }

/*  Widget _buildTrackOrders() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Track Orders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vinController,
                  decoration: InputDecoration(
                    labelText: 'Search by VIN',
                    hintText: 'Enter VIN number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _orderIdController,
                  decoration: InputDecoration(
                    labelText: 'Search by Order ID',
                    hintText: 'Enter Order ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _searchOrders(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Search'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Transport Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_transportOrders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Orders',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('You don\'t have any transport orders.'),
                  ],
                ),
              ),
            )
          else
            ..._transportOrders.map((order) => _buildOrderTrackingCard(order)),
        ],
      ),
    );
  }*/

  Widget _buildTrackOrders() {
    final vinQuery = _vinController.text.trim().toLowerCase();
    final orderIdQuery = _orderIdController.text.trim();
    final visibleOrders = _transportOrders.where((order) {
      final vin = (order['vin'] ?? '').toString().toLowerCase();
      final idStr = (order['id'] ?? '').toString();
      final vinMatch = vinQuery.isEmpty || vin.contains(vinQuery);
      final idMatch = orderIdQuery.isEmpty || idStr == orderIdQuery;
      return vinMatch && idMatch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Track Orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'Search and monitor all transport orders',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // Search Section - Compact
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // VIN Search
                TextField(
                  controller: _vinController,
                  decoration: InputDecoration(
                    hintText: 'Search by VIN',
                    prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Order ID Search
                TextField(
                  controller: _orderIdController,
                  decoration: InputDecoration(
                    hintText: 'Search by Order ID',
                    prefixIcon: Icon(Icons.numbers, size: 16, color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _searchOrders,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Search Orders',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Orders Header with Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Orders',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${visibleOrders.length} total',
                  style: TextStyle(
                    fontSize: 10,
                    color: kAccentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (visibleOrders.isEmpty)
          // Empty State - Compact
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'No Orders',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No transport orders found',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
          // Orders List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleOrders.length,
              itemBuilder: (context, index) {
                final order = visibleOrders[index];
                return _buildCompactOrderCard(order);
              },
            ),
        ],
      ),
    );
  }

// Compact Order Card
  Widget _buildCompactOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusColor = status == 'delivered'
        ? Colors.green
        : status == 'in_transit'
        ? Colors.blue
        : Colors.orange;

    final statusText = status.toString().replaceAll('_', ' ').toUpperCase();
    final pickupLocation = '${order['pickup_city'] ?? 'N/A'}, ${order['pickup_state'] ?? ''}';
    final deliveryLocation = '${order['delivery_city'] ?? 'N/A'}, ${order['delivery_state'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Top Row - Image + Basic Info + Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              _buildVehicleImageWidget(
                order['photo_url'],
                width: 50,
                height: 50,
                index: order['id'] ?? 0,
              ),
              const SizedBox(width: 10),

              // Vehicle Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order['make'] ?? ''} ${order['model'] ?? ''} (${order['year'] ?? ''})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIN: ${order['vin'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order: ${order['id'] ?? ''}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Location Row
          Row(
            children: [
              // Pickup
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 10, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PICKUP',
                            style: TextStyle(fontSize: 7, color: Colors.grey),
                          ),
                          Text(
                            pickupLocation,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (order['pickup_date'] != null)
                            Text(
                              _formatDateShort(order['pickup_date']),
                              style: TextStyle(fontSize: 7, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(Icons.arrow_forward, size: 12, color: Colors.grey[400]),

              // Delivery
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 10, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DELIVERY',
                            style: TextStyle(fontSize: 7, color: Colors.grey),
                          ),
                          Text(
                            deliveryLocation,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                          if (order['delivery_date'] != null)
                            Text(
                              _formatDateShort(order['delivery_date']),
                              style: TextStyle(fontSize: 7, color: Colors.grey[500]),
                              textAlign: TextAlign.end,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Cancel Button for Pending Orders
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelOrder(order['id'].toString()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Cancel Order',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

// Helper function for date formatting
  String _formatDateShort(dynamic date) {
    try {
      if (date is String) {
        return DateTime.parse(date).toString().split(' ')[0];
      }
      return date.toString().split(' ')[0];
    } catch (e) {
      return '';
    }
  }

  Widget _buildOrderTrackingCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusColor = status == 'delivered'
        ? Colors.green
        : status == 'in_transit'
        ? Colors.blue
        : Colors.orange;
    final notesStr = (order['notes'] ?? '').toString().toLowerCase();
    final bool isCancelledByMe = notesStr.contains('cancelled by transporter');
    final bool showCancelButton = status == 'pending' && !isCancelledByMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildVehicleImageWidget(
                order['photo_url'],
                width: 50,
                height: 50,
                index: order['id'] ?? 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order['make']} ${order['model']} (${order['year']})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIN: ${order['vin']}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ID: ${order['id']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status.toString().replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PICKUP',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      '${order['pickup_city']}, ${order['pickup_state']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order['pickup_date'] != null)
                      Text(
                        DateTime.parse(order['pickup_date']).toString().split(' ')[0],
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'DELIVERY',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      '${order['delivery_city']}, ${order['delivery_state']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    if (order['delivery_date'] != null)
                      Text(
                        DateTime.parse(order['delivery_date']).toString().split(' ')[0],
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        textAlign: TextAlign.end,
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (showCancelButton) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelOrder(order['id'].toString()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Cancel Order',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPickup(String orderId) async {
    try {
      await _transportService.markPickupComplete(orderId);
      print('✅ Pickup confirmed for order: $orderId');
      _loadDashboardData();
    } catch (e) {
      print('❌ ERROR confirming pickup: $e');
    }
  }

  Future<void> _claimAndMarkPickupComplete(String orderId) async {
    try {
      await _transportService.markPickupComplete(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order claimed and pickup marked as complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showUpdateETADialog(Map<String, dynamic> order) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update ETA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Select Date'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  selectedDate = date;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    selectedTime = time;
                    Navigator.pop(context, {
                      'date': selectedDate,
                      'time': selectedTime,
                    });
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && result['date'] != null && result['time'] != null) {
      try {
        final date = result['date'] as DateTime;
        final time = result['time'] as TimeOfDay;
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final combined = '$dateStr $timeStr';

        // Send combined field for compatibility with web UI; backend also accepts split
        await _transportService.confirmDeliveryTimelineFlexible(
          order['id'].toString(),
          deliveryDateTime: combined,
        );
        print('✅ ETA updated for order: ${order['id']}');
        _loadDashboardData();
      } catch (e) {
        print('❌ ERROR updating ETA: $e');
      }
    }
  }

  Future<void> _showUpdateLocationDialog(Map<String, dynamic> order) async {
    final locationController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Current Location'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'Current Location',
            hintText: 'Enter current location',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (locationController.text.isNotEmpty) {
                Navigator.pop(context, locationController.text);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _transportService.updateLocation(
          order['id'].toString(),
          result,
          '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated')),
          );
        }
        _loadDashboardData();
      } catch (e) {
        print('❌ ERROR updating location: $e');
      }
    }
  }

  Future<void> _submitProofOfDelivery() async {
    if (_selectedOrderId == null || _selectedVIN == null || _selectedImage == null) {
      print('❌ ERROR: Please select order, VIN, and image');
      return;
    }

    try {
      await _transportService.uploadProof(
        _selectedOrderId!,
        _selectedVIN!,
        _selectedImage!,
      );
      print('✅ Proof of delivery submitted successfully');
      setState(() {
        _selectedOrderId = null;
        _selectedVIN = null;
        _selectedImage = null;
        _recipientNameController.clear();
        _deliveryNotesController.clear();
      });
      _loadDashboardData();
    } catch (e) {
      print('❌ ERROR submitting proof of delivery: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageToController.text.isEmpty || _messageContentController.text.isEmpty) {
      print('❌ ERROR: Please fill in recipient and message');
      return;
    }

    try {
      final contact = _contacts.firstWhere(
            (c) => c['full_name'] == _messageToController.text,
      );

      final chatService = ChatService();
      final conversation = await chatService.getOrCreateConversation(
        otherUserId: contact['id'].toString(),
      );

      await chatService.sendMessage(
        conversationId: conversation['id'].toString(),
        message: _messageContentController.text,
      );

      print('✅ Message sent successfully');
      setState(() {
        _messageToController.clear();
        _messageSubjectController.clear();
        _messageContentController.clear();
      });
      _loadDashboardData();
    } catch (e) {
      print('❌ ERROR sending message: $e');
    }
  }

  Future<void> _searchOrders() async {
    setState(() {});
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this transport order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _transportService.cancelOrder(orderId);
      if (mounted) {
        print('✅ Order cancelled successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        print('❌ ERROR cancelling order: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
