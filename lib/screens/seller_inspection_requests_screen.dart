import 'package:flutter/material.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/widgets/empty_state_widget.dart';

class SellerInspectionRequestsScreen extends StatefulWidget {
  const SellerInspectionRequestsScreen({super.key});

  @override
  State<SellerInspectionRequestsScreen> createState() => _SellerInspectionRequestsScreenState();
}

class _SellerInspectionRequestsScreenState extends State<SellerInspectionRequestsScreen> {
  final InspectionService _inspectionService = InspectionService();
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
      print('🔄 Loading pending inspection requests...');
      final requests = await _inspectionService.getSellerPendingRequests();
      print('✅ Loaded ${requests.length} pending inspection requests');
      
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading pending inspection requests: $e');
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

  Future<void> _acceptRequest(String inspectionId) async {
    try {
      await _inspectionService.sellerAcceptRequest(inspectionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection request accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String inspectionId) async {
    try {
      await _inspectionService.sellerRejectRequest(inspectionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Requests'),
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
                    'Loading inspection requests...',
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
                  message: 'You have no pending inspection requests.',
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      final vehicle = request['vehicle'] ?? {};
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
                                      'Pending',
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
                              if (request['scheduled_date'] != null)
                                _buildInfoRow(Icons.calendar_today, 'Scheduled Date', request['scheduled_date']),
                              if (request['location'] != null)
                                _buildInfoRow(Icons.location_on, 'Location', request['location']),
                              if (request['priority'] != null)
                                _buildInfoRow(Icons.flag, 'Priority', request['priority'].toString().toUpperCase()),
                              if (request['notes'] != null && request['notes'].toString().isNotEmpty)
                                _buildInfoRow(Icons.note, 'Notes', request['notes']),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _rejectRequest(request['id'].toString()),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.red[300]!),
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () => _acceptRequest(request['id'].toString()),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
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

