import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/image_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/inspector_inspection_screen.dart';
import 'package:carauction/screens/continue_inspection_screen.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/screens/view_report_screen.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/utils/drawer_menu.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:get/get.dart';

class InspectorDashboardScreen extends StatefulWidget {
  const InspectorDashboardScreen({super.key});

  @override
  State<InspectorDashboardScreen> createState() => _InspectorDashboardScreenState();
}

class _InspectorDashboardScreenState extends State<InspectorDashboardScreen> {
  int _selectedTab = 0;
  int _selectedDrawerIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentCarouselIndex = 0;

  final List<String> _carouselImages = [
    'assets/images/car1.png',
    'assets/images/car2.png',
    'assets/images/car3.png',
    'assets/images/car1.png',
    'assets/images/car2.png',
  ];

  final Rx<Map<String, dynamic>?> _dashboardData = Rx<Map<String, dynamic>?>(null);
  final RxList<Map<String, dynamic>> _assignedInspections = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _completedInspections = <Map<String, dynamic>>[].obs;
  final RxBool _isLoadingInspections = false.obs;
  final InspectionService _inspectionService = InspectionService();
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;
  final RxInt _itemsToShow = 5.obs;

  final RxMap<int, bool> _expandedCards = <int, bool>{}.obs;
  String? _lastInspectionHash;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted && !_isRefreshing) await _loadDashboard();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredInspections(List<Map<String, dynamic>> inspections) {
    if (_searchQuery.value.isEmpty) return inspections;
    final query = _searchQuery.value.toLowerCase();
    return inspections.where((inspection) {
      final car = inspection['car'] as Car?;
      if (car == null) return false;
      return car.make?.toLowerCase().contains(query) == true ||
          car.model?.toLowerCase().contains(query) == true ||
          car.year?.toString().contains(query) == true ||
          car.vin?.toLowerCase().contains(query) == true;
    }).toList();
  }

  List<Map<String, dynamic>> _getDisplayedInspections(List<Map<String, dynamic>> inspections) {
    return _getFilteredInspections(inspections).take(_itemsToShow.value).toList();
  }

  Future<void> _loadDashboard() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _isLoadingInspections.value = true;

    try {
      final dashboardData = await _inspectionService.getDashboard();
      if (!mounted) return;
      _dashboardData.value = dashboardData;

      final inspections = dashboardData['inspections'] as List<dynamic>? ?? [];

      final assignedList = <Map<String, dynamic>>[];
      final completedList = <Map<String, dynamic>>[];

      for (var inspection in inspections) {
        final status = (inspection['status'] ?? 'assigned').toString().toLowerCase();
        final imageUrl = inspection['photo_url'] ?? 'assets/images/car1.png';

        final vehicleId = inspection['vehicle_id']?.toString() ?? '0';
        final year = _parseInt(inspection['year']);
        final mileage = _parseInt(inspection['mileage']);

        final inspectionData = {
          'id': inspection['id'].toString(),
          'car': Car(
            id: vehicleId,
            make: inspection['make'] ?? 'Unknown',
            model: inspection['model'] ?? 'Unknown',
            year: year,
            imageUrl: imageUrl,
            startingBid: 0,
            buyNowPrice: 0,
            mileage: mileage,
            location: inspection['location'] ?? '',
            distance: '',
            auctionEndTime: DateTime.now(),
            status: status,
            vin: inspection['vin'] ?? '',
          ),
          'date': _formatDate(DateTime.now()),
          'location': _formatLocation(inspection['location_city'], inspection['location_state'], inspection['location_zip']),
          'request_type': inspection['request_type'] ?? 'standard',
          'buyer_name': inspection['buyer_name'],
          'status': status,
        };

        if (status == 'completed') completedList.add(inspectionData);
        else assignedList.add(inspectionData);
      }

      _assignedInspections.assignAll(assignedList);
      _completedInspections.assignAll(completedList);

    } catch (e) {
      print('Error: $e');
    } finally {
      _isRefreshing = false;
      if (mounted) _isLoadingInspections.value = false;
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatLocation(String? city, String? state, String? zip) {
    final parts = [city, state, zip].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : 'N/A';
  }

  String _formatStatus(String status) {
    return status.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned': return kThemeColor3;
      case 'in_progress': return kThemeColor3;
      case 'completed': return kAccentColor;
      default: return Colors.grey;
    }
  }

  Widget _buildActionButtons(Map<String, dynamic> inspection, Car car) {
    final status = (inspection['status'] ?? '').toString().toLowerCase();
    if (status == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
      );
    } else if (status == 'assigned') {
      return ElevatedButton(
        onPressed: () async {
          await _inspectionService.startInspection(inspection['id'].toString());
          _loadDashboard();
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => InspectorInspectionScreen(
                car: car,
                inspectionId: inspection['id'].toString(),
                date: inspection['date'] ?? '',
                location: inspection['location'] ?? '',
              ),
            )).then((_) => _loadDashboard());
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: kThemeColor3,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Start', style: TextStyle(fontSize: 11)),
      );
    } else {
      return ElevatedButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ContinueInspectionScreen(
              car: car,
              inspectionId: inspection['id'].toString(),
              date: inspection['date'] ?? '',
              location: inspection['location'] ?? '',
            ),
          )).then((_) => _loadDashboard());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentColor,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Continue', style: TextStyle(fontSize: 11)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      drawer: DrawerMenu(
        selectedIndex: _selectedDrawerIndex,
        hideBuyerSellerSwitch: true,
        onItemSelected: (index) => setState(() => _selectedDrawerIndex = index),
      ),
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        toolbarHeight: 56,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 22),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Inspector', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildCarouselBanner(),
            _buildCarouselIndicators(),
           _buildWelcomeAndStatsSection(),
            _buildTabs(),
           _buildSearchBar(),
            _selectedTab == 0 ? _buildAssignedContent() : _buildCompletedContent(),
          ],
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
            height: 180,
            autoPlay: true,
            viewportFraction: 1.0,
            onPageChanged: (index, _) => setState(() => _currentCarouselIndex = index),
          ),
          items: _carouselImages.map((path) => Container(
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.6)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_currentCarouselIndex + 1}/${_carouselImages.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'We Deliver the\nDream Drive',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _carouselImages.asMap().entries.map((entry) {
        return GestureDetector(
          onTap: () => _carouselController.animateToPage(entry.key),
          child: Container(
            width: _currentCarouselIndex == entry.key ? 10 : 6,
            height: _currentCarouselIndex == entry.key ? 10 : 6,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentCarouselIndex == entry.key ? kAccentColor : Colors.grey[400],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWelcomeAndStatsSection() {
    final userData = _dashboardData.value?['user'];
    final stats = _dashboardData.value?['stats'];

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Welcome, ${userData?['full_name'] ?? 'Inspector'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAccentColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: kThemeColor3, borderRadius: BorderRadius.circular(12)),
                child: const Text('Certified', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Total', _parseInt(stats?['total_inspections']).toString()),
              const SizedBox(width: 6),
              _buildStatCard('Active', _parseInt(stats?['assigned_inspections']).toString()),
              const SizedBox(width: 6),
              _buildStatCard('Done', _parseInt(stats?['completed_inspections']).toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: kAccentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kAccentColor)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(child: _buildTab('Assigned', 0)),
          const SizedBox(width: 6),
          Expanded(child: _buildTab('Completed', 1)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() { _selectedTab = index; _itemsToShow.value = 5; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kThemeColor3 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? kThemeColor3 : Colors.grey.shade300),
        ),
        child: Text(title, textAlign: TextAlign.center,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) { _searchQuery.value = v; _itemsToShow.value = 5; },
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildAssignedContent() {
    return Obx(() {
      if (_isLoadingInspections.value) {
        return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      }

      final displayed = _getDisplayedInspections(_assignedInspections);
      final hasMore = _getFilteredInspections(_assignedInspections).length > _itemsToShow.value;

      if (displayed.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No inspections', style: TextStyle(fontSize: 14, color: Colors.grey))),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            ...displayed.map((inspection) {
              final car = inspection['car'] as Car;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                car.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.directions_car, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${car.year} ${car.make} ${car.model}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('VIN: ${car.vin?.substring(0, 8)}...', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(inspection['status']).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(_formatStatus(inspection['status']),
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _getStatusColor(inspection['status']))),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        width: 70,
                                        child: _buildActionButtons(inspection, car),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (inspection['buyer_name'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text('Buyer: ${inspection['buyer_name']}',
                                      style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton(
                  onPressed: () => _itemsToShow.value += 5,
                  child: Text('Load +${_getFilteredInspections(_assignedInspections).length - _itemsToShow.value}',
                      style: const TextStyle(fontSize: 12, color: kAccentColor)),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildCompletedContent() {
    return Obx(() {
      if (_isLoadingInspections.value) {
        return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      }

      final displayed = _getDisplayedInspections(_completedInspections);
      final hasMore = _getFilteredInspections(_completedInspections).length > _itemsToShow.value;

      if (displayed.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No completed', style: TextStyle(fontSize: 14, color: Colors.grey))),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            ...displayed.map((inspection) {
              final car = inspection['car'] as Car;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            car.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.directions_car, size: 25),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${car.year} ${car.make} ${car.model}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('VIN: ${car.vin?.substring(0, 8)}...', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Done', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green)),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: 60,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewReportScreen(car: car))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                      child: const Text('View', style: TextStyle(fontSize: 10)),
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
                ),
              );
            }).toList(),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton(
                  onPressed: () => _itemsToShow.value += 5,
                  child: Text('Load +${_getFilteredInspections(_completedInspections).length - _itemsToShow.value}',
                      style: const TextStyle(fontSize: 12, color: kAccentColor)),
                ),
              ),
          ],
        ),
      );
    });
  }
}