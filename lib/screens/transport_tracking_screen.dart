import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/widgets/empty_state_widget.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/screens/transporter_dashboard_screen.dart';
import 'dart:async';

import '../models/car.dart';
import 'MyTransportsScreen .dart';

class TransportTrackingScreen extends StatefulWidget {
  final String? vehicleId;
  final String? orderId; // For direct order lookup

  const TransportTrackingScreen({
    super.key,
    this.vehicleId,
    this.orderId,
  });

  @override
  State<TransportTrackingScreen> createState() => _TransportTrackingScreenState();
}

class _TransportTrackingScreenState extends State<TransportTrackingScreen> {
  final TransportService _transportService = TransportService();
  final CarService _carService = CarService();

  Map<String, dynamic>? _transportOrder;
  List<Map<String, dynamic>> _updates = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  String? _userRole;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    if (widget.orderId != null || widget.vehicleId != null) {
      _loadTransportOrder();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      _userRole = await PreferencesHelper.getUserRole();
      final userIdStr = await PreferencesHelper.getUserId();
      _userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted) {
        await _loadTransportOrder(showLoading: false);
      }
    });
  }

  Future<void> _loadTransportOrder({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? order;

      if (widget.orderId != null) {
        // Direct order lookup by ID - using existing method
        // getTransportOrder already accepts orderId parameter in the service
        order = await _transportService.getTransportOrder(widget.orderId!);
      } else if (widget.vehicleId != null) {
        // Lookup by vehicle ID
        order = await _transportService.getTransportOrder(widget.vehicleId!);
      }

      if (!mounted) return;

      if (order != null && order['order'] != null) {
        final orderData = order['order'] as Map<String, dynamic>;
        setState(() {
          _transportOrder = order;
          _updates = (order?['updates'] as List?)?.map((e) =>
          e is Map<String, dynamic> ? e : <String, dynamic>{}
          ).toList() ?? [];
          _errorMessage = null;
          _isLoading = false;
        });
        _startAutoRefresh();
      } else {
        setState(() {
          _transportOrder = null;
          _errorMessage = 'Transport order not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getStatusClass(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'status-pending';
      case 'in_transit':
        return 'status-in_transit';
      case 'delivered':
      case 'completed':
        return 'status-delivered';
      default:
        return 'status-pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFF3CD);
      case 'in_transit':
        return const Color(0xFFCCE7FF);
      case 'delivered':
      case 'completed':
        return const Color(0xFFD4EDDA);
      default:
        return const Color(0xFFFFF3CD);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFF856404);
      case 'in_transit':
        return const Color(0xFF004085);
      case 'delivered':
      case 'completed':
        return const Color(0xFF155724);
      default:
        return const Color(0xFF856404);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${_getMonthName(date.month)} ${date.day}, ${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    } catch (e) {
      return dateStr;
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getTimelineItemClass(String status, String currentStatus) {
    if (status == 'completed') return 'completed';
    if (status == currentStatus.toLowerCase()) return 'current';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: kWhiteColor,
      enableScroll: false,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kWhiteColor),
        title: const Text(
          'Transport Status',
          style: TextStyle(
            color: kWhiteColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        toolbarHeight: 56,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _errorMessage != null && _transportOrder == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      )
          : _transportOrder == null
          ? const EmptyStateWidget(
        type: EmptyStateType.emptyTransport,
        title: 'No Transport Order',
        message: 'Transport not scheduled yet.',
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // Mobile view - stack vertically
              return _buildMobileView();
            } else {
              // Tablet/Desktop view - two columns
              return _buildDesktopView();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDesktopView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Main Content
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success/Error Messages
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Transport Timeline Card
              _buildTimelineCard(),
              const SizedBox(height: 16),

              // Map Preview Card
              _buildMapCard(),
              const SizedBox(height: 16),

              // Updates & Communication Card
              _buildUpdatesCard(),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right Column - Sidebar
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Order Summary Card
              _buildOrderSummaryCard(),
              const SizedBox(height: 16),

              // Quick Actions Card
              _buildQuickActionsCard(),
              const SizedBox(height: 16),

              // Help Information Card
              _buildHelpCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success/Error Messages
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),

        // Transport Timeline Card
        _buildTimelineCard(),
        const SizedBox(height: 16),

        // Map Preview Card
        _buildMapCard(),
        const SizedBox(height: 16),

        // Updates & Communication Card
        _buildUpdatesCard(),
        const SizedBox(height: 16),

        // Order Summary Card
        _buildOrderSummaryCard(),
        const SizedBox(height: 16),

        // Quick Actions Card
        _buildQuickActionsCard(),
        const SizedBox(height: 16),

        // Help Information Card
        _buildHelpCard(),
      ],
    );
  }

  Widget _buildTimelineCard() {
    final order = _transportOrder?['order'] as Map<String, dynamic>? ?? {};
    final status = (order['status'] ?? order['transport_status'] ?? 'pending') as String;
    final createdAt = order['created_at'] as String?;
    final pickupDate = order['pickup_date'] as String?;
    final deliveryDate = order['delivery_date'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: kAccentColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.timeline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Transport Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Status Timeline
                Container(
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: kAccentColor,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Order Created
                      _buildTimelineItem(
                        title: 'Order Created',
                        description: 'Transport order was created and assigned to transporter',
                        timestamp: createdAt != null ? _formatDate(createdAt) : null,
                        status: 'completed',
                        currentStatus: status,
                      ),

                      // Pickup Scheduled
                      _buildTimelineItem(
                        title: 'Pickup Scheduled',
                        description: 'Vehicle pickup scheduled with transporter',
                        timestamp: pickupDate != null ? 'Scheduled: ${_formatDate(pickupDate)}' : null,
                        status: status != 'pending' ? 'completed' : 'current',
                        currentStatus: status,
                        extraWidget: status == 'pending'
                            ? Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFE7A0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Color(0xFF856404)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Waiting for transporter to confirm pickup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : null,
                      ),

                      // In Transit
                      _buildTimelineItem(
                        title: 'In Transit',
                        description: 'Vehicle is being transported to delivery location',
                        status: status == 'delivered' ? 'completed' : (status == 'in_transit' ? 'current' : ''),
                        currentStatus: status,
                        extraWidget: status == 'in_transit' && deliveryDate != null
                            ? Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCE7FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFB8DAFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.local_shipping, size: 16, color: Color(0xFF004085)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Vehicle is currently in transit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF004085),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Estimated delivery: ${_formatDate(deliveryDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF004085),
                                ),
                              ),
                            ],
                          ),
                        )
                            : null,
                      ),

                      // Delivery
                      _buildTimelineItem(
                        title: 'Delivery',
                        description: 'Vehicle delivered to final destination',
                        status: status == 'delivered' ? 'completed' : '',
                        currentStatus: status,
                        extraWidget: status == 'delivered' && _updates.isNotEmpty
                            ? Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4EDDA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC3E6CB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Color(0xFF155724)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vehicle delivered successfully on ${_formatDate(_updates.first['delivery_date'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF155724),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Current Status Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Current Status: ',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusTextColor(status),
                          ),
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

  Widget _buildTimelineItem({
    required String title,
    String? description,
    String? timestamp,
    required String status,
    required String currentStatus,
    Widget? extraWidget,
  }) {
    final itemStatus = _getTimelineItemClass(status, currentStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 2),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: itemStatus == 'completed'
                  ? Colors.green
                  : (itemStatus == 'current'
                  ? Colors.amber
                  : Colors.grey[400]),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: itemStatus == 'current'
                  ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
                  : null,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: itemStatus == 'completed'
                        ? Colors.green[700]
                        : (itemStatus == 'current'
                        ? Colors.amber[800]
                        : Colors.grey[600]),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    timestamp,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                if (extraWidget != null) extraWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final order = _transportOrder?['order'] as Map<String, dynamic>? ?? {};
    final pickupCity = order['pickup_city'] as String? ?? 'N/A';
    final pickupState = order['pickup_state'] as String? ?? '';
    final deliveryCity = order['delivery_city'] as String? ?? 'N/A';
    final deliveryState = order['delivery_state'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: const Text(
              'Transport Route',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        '${pickupCity.isNotEmpty ? pickupCity : 'N/A'}${pickupState.isNotEmpty ? ', $pickupState' : ''} → ${deliveryCity.isNotEmpty ? deliveryCity : 'N/A'}${deliveryState.isNotEmpty ? ', $deliveryState' : ''}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live tracking will be available when transport begins',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
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

  Widget _buildUpdatesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: const Text(
              'Updates & Communication',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _updates.isEmpty
                ? Column(
              children: [
                Icon(Icons.access_time, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No updates available yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updates will appear here when the transporter provides them',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            )
                : Column(
              children: _updates.map((update) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Update',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        update['delivery_notes'] as String? ?? 'No notes provided',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Posted on: ${_formatDate(update['created_at'] as String?)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    final order = _transportOrder?['order'] as Map<String, dynamic>? ?? {};
    final vehicle = order['vehicle'] as Map<String, dynamic>? ?? {};
    final photoUrl = order['photo_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: kAccentColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: const Text(
              'Order Summary',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Image
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: photoUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.directions_car, size: 50, color: Colors.grey);
                        },
                      ),
                    )
                        : const Icon(Icons.directions_car, size: 50, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),

                // Vehicle Details
                Text(
                  '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}${vehicle['year'] != null ? ' (${vehicle['year']})' : ''}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'VIN: ${vehicle['vin'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mileage: ${vehicle['mileage'] != null ? '${vehicle['mileage']} miles' : 'N/A'}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  'Order ID: #${order['id'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(height: 20),

                // Transport Details
                const Text(
                  'Transport Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildSummaryRow('Cost', '\$${order['cost'] ?? '0'}'),
                _buildSummaryRow('Pickup', '${order['pickup_city'] ?? 'N/A'}${order['pickup_state'] != null ? ', ${order['pickup_state']}' : ''}'),
                _buildSummaryRow('Delivery', '${order['delivery_city'] ?? 'N/A'}${order['delivery_state'] != null ? ', ${order['delivery_state']}' : ''} ${order['delivery_zip'] ?? ''}'),
                _buildSummaryRow('Address', order['delivery_address'] ?? 'N/A'),

                if (order['special_instructions'] != null) ...[
                  const Divider(height: 20),
                  const Text(
                    'Special Instructions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order['special_instructions'] as String,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard, size: 18),
                        SizedBox(width: 8),
                        Text('Back to Dashboard', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      print('🔄 Navigating to My Transports...');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyTransportsScreen(),
                        ),
                      ).then((_) {
                        print('✅ Returned from My Transports');
                      }).catchError((e) {
                        print('❌ Navigation error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAccentColor,
                      side: BorderSide(color: kAccentColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list, size: 18),
                        SizedBox(width: 8),
                        Text('View All Transports', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                if (_userRole == 'transporter')
                  const SizedBox(height: 8),
                if (_userRole == 'transporter')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        print('🔄 Navigating to Transporter Dashboard...');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransporterDashboardScreen(),
                          ),
                        ).then((_) {
                          print('✅ Returned from Transporter Dashboard');
                        }).catchError((e) {
                          print('❌ Navigation error: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping, size: 18),
                          SizedBox(width: 8),
                          Text('Transporter Dashboard', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    final order = _transportOrder?['order'] as Map<String, dynamic>? ?? {};
    final transporterName = order['transporter_name'] as String?;
    final transporterCompany = order['transporter_company'] as String?;
    final transporterPhone = order['transporter_phone'] as String?;
    final transporterEmail = order['transporter_email'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(Icons.help_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'If you have any issues with your transport:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              _buildHelpBullet('Contact the transporter directly'),
              _buildHelpBullet('Check for updates regularly'),
              _buildHelpBullet('Ensure someone is available at delivery location'),
              _buildHelpBullet('Keep your contact information updated'),
            ],
          ),
          if (transporterName != null || transporterPhone != null || transporterEmail != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Transporter Contact:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (transporterName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Name: $transporterName', style: const TextStyle(fontSize: 12)),
              ),
            if (transporterCompany != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Company: $transporterCompany', style: const TextStyle(fontSize: 12)),
              ),
            if (transporterPhone != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Phone: $transporterPhone', style: const TextStyle(fontSize: 12)),
              ),
            if (transporterEmail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Email: $transporterEmail', style: const TextStyle(fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}