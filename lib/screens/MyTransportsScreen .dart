import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/screens/transport_tracking_screen.dart';
import 'package:intl/intl.dart';

class MyTransportsScreen extends StatefulWidget {
  const MyTransportsScreen({super.key});

  @override
  State<MyTransportsScreen> createState() => _MyTransportsScreenState();
}

class _MyTransportsScreenState extends State<MyTransportsScreen> {
  final TransportService _transportService = TransportService();
  List<Map<String, dynamic>> _transports = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;
  int? _userId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTransports();

    // Auto-refresh for transporters every 60 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userRole == 'transporter') {
        _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
          if (mounted) {
            _loadTransports(showLoading: false);
          }
        });
      }
    });
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

  Future<void> _loadTransports({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      final transports = await _transportService.getMyTransports();
      if (mounted) {
        setState(() {
          _transports = transports;
          _errorMessage = null;
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
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Transports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        toolbarHeight: 56,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _errorMessage != null && _transports.isEmpty
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transport History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_transports.length} Orders',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Statistics Cards
            if (_transports.isNotEmpty) ...[
              _buildStatisticsCards(),
              const SizedBox(height: 16),
            ],

            // Transports List
            if (_transports.isEmpty)
              _buildEmptyState()
            else
              _buildTransportsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final pending = _transports.where((t) => t['status'] == 'pending').length;
    final inTransit = _transports.where((t) => t['status'] == 'in_transit').length;
    final delivered = _transports.where((t) => t['status'] == 'delivered' || t['status'] == 'completed').length;

    return Row(
      children: [
        _buildStatCard('Pending', pending.toString(), Colors.orange),
        const SizedBox(width: 8),
        _buildStatCard('In Transit', inTransit.toString(), Colors.blue),
        const SizedBox(width: 8),
        _buildStatCard('Delivered', delivered.toString(), Colors.green),
        const SizedBox(width: 8),
        _buildStatCard('Total', _transports.length.toString(), kAccentColor),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transports.length,
      itemBuilder: (context, index) {
        final transport = _transports[index];
        return _buildTransportCard(transport);
      },
    );
  }

  Widget _buildTransportCard(Map<String, dynamic> transport) {
    final status = transport['status'] as String? ?? 'pending';
    final vehicle = transport['vehicle'] as Map<String, dynamic>? ?? {};
    final photoUrl = transport['photo_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Main Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Vehicle Image
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: photoUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.directions_car, size: 20, color: Colors.grey);
                      },
                    ),
                  )
                      : const Icon(Icons.directions_car, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 10),

                // Vehicle Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'VIN: ${vehicle['vin'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusTextColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Pickup Location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'From',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transport['pickup_city'] != null && transport['pickup_state'] != null
                            ? '${transport['pickup_city']}, ${transport['pickup_state']}'
                            : 'N/A',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Delivery Location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transport['delivery_city'] != null && transport['delivery_state'] != null
                            ? '${transport['delivery_city']}, ${transport['delivery_state']}'
                            : 'N/A',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Estimated Delivery
                if (status == 'in_transit' && transport['delivery_date'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Est. Delivery',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(transport['delivery_date']),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // View Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransportTrackingScreen(
                            orderId: transport['id']?.toString(),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, size: 14),
                        SizedBox(width: 4),
                        Text('View', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                // Confirm Button for Transporters (if pending)
                if (_userRole == 'transporter' && status == 'pending') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _showConfirmDialog(transport['id']);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 14),
                          SizedBox(width: 4),
                          Text('Confirm', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmDialog(int? orderId) async {
    if (orderId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Pickup'),
        content: const Text('Have you confirmed pickup of this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) {
      // TODO: Call API to confirm pickup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup confirmed'),
          backgroundColor: Colors.green,
        ),
      );
      _loadTransports();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.local_shipping, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Transport Orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _userRole == 'transporter'
                  ? 'You don\'t have any transport orders assigned yet.'
                  : 'You haven\'t scheduled any vehicle transports yet.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (_userRole == 'buyer')
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
              child: const Text('Browse Purchased Vehicles'),
            )
          else
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
              child: const Text('Back to Dashboard'),
            ),
        ],
      ),
    );
  }
}