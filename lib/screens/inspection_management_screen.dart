import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/widgets/empty_state_widget.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/inspection_request_screen.dart';
import 'package:carauction/screens/inspector_inspection_screen.dart';

/// Inspection Management Screen
/// 
/// For buyers/sellers to:
/// - View inspection requests
/// - Request new inspections
/// - Track inspection status
class InspectionManagementScreen extends StatefulWidget {
  const InspectionManagementScreen({super.key});

  @override
  State<InspectionManagementScreen> createState() => _InspectionManagementScreenState();
}

class _InspectionManagementScreenState extends State<InspectionManagementScreen> {
  final InspectionService _inspectionService = InspectionService();
  
  List<Map<String, dynamic>> _inspectionRequests = [];
  bool _isLoading = true;
  Timer? _refreshTimer; // Timer for real-time updates
  
  @override
  void initState() {
    super.initState();
    _loadInspectionRequests();
    _startRealTimeUpdates(); // Start real-time updates
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  /// Start real-time updates (polling every 10 seconds)
  void _startRealTimeUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadInspectionRequests();
      }
    });
  }
  
  Future<void> _loadInspectionRequests() async {
    setState(() => _isLoading = true);
    try {
      // Note: This endpoint may need to be added to backend
      // For now, we'll use a placeholder
      // final requests = await _inspectionService.getMyInspectionRequests();
      // setState(() {
      //   _inspectionRequests = requests;
      //   _isLoading = false;
      // });
      
      // Temporary: Show empty state until backend endpoint is ready
      setState(() {
        _inspectionRequests = [];
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading inspection requests: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load inspection requests: ${e.toString()}'),
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
        title: const Text('Inspection Management'),
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInspectionRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inspectionRequests.isEmpty
              ? const EmptyStateWidget(
                  type: EmptyStateType.emptyInspection,
                  title: 'No Inspection Requests',
                  message: 'Request an inspection for a vehicle to see it here.',
                )
              : RefreshIndicator(
                  onRefresh: _loadInspectionRequests,
                  color: kAccentColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _inspectionRequests.length,
                    itemBuilder: (context, index) {
                      final request = _inspectionRequests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Navigate to inspection details
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Inspection #${request['id']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildStatusChip(request['status'] ?? 'pending'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Vehicle: ${request['vehicle']?['make'] ?? 'N/A'} ${request['vehicle']?['model'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scheduled: ${request['scheduled_date'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Location: ${request['location'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to request inspection screen
          // This would require a vehicle selection first
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Select a vehicle from listings to request inspection'),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Request Inspection'),
        backgroundColor: kAccentColor,
      ),
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

