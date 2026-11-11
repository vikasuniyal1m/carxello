import 'package:flutter/material.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';

class SellerTransportRequestsScreen extends StatefulWidget {
  const SellerTransportRequestsScreen({super.key});

  @override
  State<SellerTransportRequestsScreen> createState() => _SellerTransportRequestsScreenState();
}

class _SellerTransportRequestsScreenState extends State<SellerTransportRequestsScreen> {
  final TransportService _transportService = TransportService();
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    if (_isLoading) {
      print('⏭️ Already loading, skipping duplicate call');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      print('🔄 Loading pending transport requests...');
      final requests = await _transportService.getSellerPendingRequests();
      print('✅ Loaded ${requests.length} pending transport requests');
      
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading pending transport requests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load requests: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _approveTransportDates(String orderId) async {
    try {
      await _transportService.sellerApproveTransportDates(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transport dates approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not set';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Scheduling Requests'),
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingRequests,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading transport requests...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _pendingRequests.isEmpty
              ? const EmptyStateWidget(
                  type: EmptyStateType.emptyInspection,
                  title: 'No Pending Requests',
                  message: 'You have no pending transport scheduling requests.',
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final order = _pendingRequests[index];
                      final vehicle = order['vehicle'] ?? {};
                      final buyer = order['buyer'] ?? {};
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      order['transport_status'] ?? 'Pending',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Buyer: ${buyer['name'] ?? buyer['email'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(Icons.location_on, 'Pickup', order['pickup_location'] ?? 'N/A'),
                              _buildInfoRow(Icons.location_city, 'Delivery', order['delivery_location'] ?? 'N/A'),
                              if (order['scheduled_pickup_date'] != null)
                                _buildInfoRow(Icons.calendar_today, 'Pickup Date', _formatDate(order['scheduled_pickup_date'])),
                              if (order['scheduled_delivery_date'] != null)
                                _buildInfoRow(Icons.event, 'Delivery Date', _formatDate(order['scheduled_delivery_date'])),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _approveTransportDates(order['id'].toString()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Approve Transport Dates'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

