import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:intl/intl.dart';

class InspectionDetailsScreen extends StatefulWidget {
  final String inspectionId;
  final Map<String, dynamic>? initialData; // Optional initial data from billing history

  const InspectionDetailsScreen({
    super.key,
    required this.inspectionId,
    this.initialData,
  });

  @override
  State<InspectionDetailsScreen> createState() => _InspectionDetailsScreenState();
}

class _InspectionDetailsScreenState extends State<InspectionDetailsScreen> {
  final InspectionService _inspectionService = InspectionService();
  Map<String, dynamic>? _inspectionData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInspectionDetails();
  }

  Future<void> _loadInspectionDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _inspectionService.getInspectionDetails(widget.inspectionId);
      
      if (mounted) {
        setState(() {
          _inspectionData = result['inspection'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback: if unauthorized for this inspection ID, try loading by vehicle ID (more permissive on backend)
      final errStr = e.toString();
      final looksUnauthorized = errStr.contains('Unauthorized') || errStr.contains('403');
      final vehicleId = _extractVehicleIdFromInitialData(widget.initialData);
      if (looksUnauthorized && vehicleId != null) {
        try {
          final alt = await _inspectionService.getVehicleInspection(vehicleId);
          if (mounted) {
            setState(() {
              _inspectionData = alt['inspection'] as Map<String, dynamic>?;
              _error = _inspectionData == null ? 'No accessible inspection found for this vehicle.' : null;
              _isLoading = false;
            });
          }
          return;
        } catch (_) {
          // Fall through to show original error
        }
      }
      if (mounted) {
        setState(() {
          _error = errStr;
          _isLoading = false;
        });
      }
    }
  }

  String? _extractVehicleIdFromInitialData(Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      if (data['vehicle_id'] != null) return data['vehicle_id'].toString();
      if (data['vehicle'] != null && data['vehicle'] is Map && data['vehicle']['id'] != null) {
        return data['vehicle']['id'].toString();
      }
    } catch (_) {}
    return null;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'assigned':
        return Icons.assignment;
      case 'in_progress':
        return Icons.work;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kWhiteColor),
        title: Text(
          'Inspection Details',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: kWhiteColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      Text(
                        'Error Loading Inspection',
                        style: ResponsiveHelper.headingStyle(context),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                      Text(
                        _error!,
                        style: ResponsiveHelper.bodyStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                      ElevatedButton.icon(
                        onPressed: _loadInspectionDetails,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _inspectionData == null
                  ? Center(
                      child: Text(
                        'Inspection not found',
                        style: ResponsiveHelper.bodyStyle(context),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInspectionDetails,
                      color: kAccentColor,
                      child: SingleChildScrollView(
                        padding: ResponsiveHelper.padding(
                          context,
                          all: ResponsiveHelper.isMobile(context) ? 16 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Badge
                            _buildStatusCard(),
                            SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                            
                            // Vehicle Information
                            _buildVehicleCard(),
                            SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                            
                            // Inspection Information
                            _buildInspectionInfoCard(),
                            SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                            
                            // Track Record
                            _buildTrackRecordCard(),
                            SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                            
                            // Inspector Information (if assigned)
                            if (_inspectionData!['inspector'] != null)
                              _buildInspectorCard(),
                            if (_inspectionData!['inspector'] != null)
                              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                            
                            // Assigned By Information (if admin assigned)
                            if (_inspectionData!['assigned_by'] != null)
                              _buildAssignedByCard(),
                            if (_inspectionData!['assigned_by'] != null)
                              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                            
                            // Inspection Report (if completed)
                            if (_inspectionData!['report'] != null)
                              _buildReportCard(),
                            if (_inspectionData!['report'] != null)
                              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildStatusCard() {
    final status = _inspectionData!['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    
    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: statusColor,
              size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: ResponsiveHelper.captionStyle(context).copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: ResponsiveHelper.headingStyle(context).copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    final vehicle = _inspectionData!['vehicle'] as Map<String, dynamic>?;
    if (vehicle == null) return const SizedBox.shrink();

    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: kAccentColor,
                size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Expanded(
                child: Text(
                  'Vehicle Information',
                  style: ResponsiveHelper.headingStyle(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (vehicle['id'] != null)
                TextButton.icon(
                  onPressed: () {
                    print('🔍 InspectionDetails: Navigating to ProductDetailsScreen');
                    print('   Vehicle data from inspection: $vehicle');
                    final car = Car(
                      id: vehicle['id'].toString(),
                      make: vehicle['make'] ?? '',
                      model: vehicle['model'] ?? '',
                      year: vehicle['year'] ?? 0,
                      imageUrl: vehicle['image_url'] ?? vehicle['photos']?[0]?['url'] ?? 'assets/images/car1.png',
                      startingBid: (vehicle['starting_bid'] as num?)?.toDouble() ?? 0.0,
                      buyNowPrice: (vehicle['buy_now_price'] as num?)?.toDouble() ?? 0.0,
                      mileage: vehicle['mileage'] ?? 0,
                      location: vehicle['location'] ?? '',
                      distance: vehicle['distance'] ?? '',
                      auctionEndTime: vehicle['auction_end_time'] != null
                          ? DateTime.parse(vehicle['auction_end_time']).toLocal()
                          : DateTime.now().add(const Duration(days: 7)),
                      status: vehicle['status'] ?? 'available',
                      vin: vehicle['vin'],
                      description: vehicle['description'],
                      wonAmount: (vehicle['won_amount'] as num?)?.toDouble(),
                      transportStatus: vehicle['transport_status'],
                      expectedDeliveryDate: vehicle['expected_delivery_date'],
                      invoiceNumber: vehicle['invoice_number'],
                      titleStatus: vehicle['title_status'],
                      inspectionStatus: vehicle['inspection_status'],
                      swapOfferStatus: vehicle['swap_offer_status'],
                      lastMatch: vehicle['last_match'],
                      currentMatches: (vehicle['current_matches'] is int)
                          ? vehicle['current_matches']
                          : (vehicle['current_matches'] as num?)?.toInt(),
                      alerts: (vehicle['alerts'] is bool)
                          ? vehicle['alerts']
                          : (vehicle['alerts'] is int)
                              ? (vehicle['alerts'] as int) != 0
                              : null,
                      price: (vehicle['price'] as num?)?.toDouble(),
                      purchaseMethod: vehicle['purchase_method'],
                      purchaseAmount: (vehicle['purchase_amount'] as num?)?.toDouble(),
                      sellerId: vehicle['seller_id']?.toString(),
                      sellerName: vehicle['seller_name'],
                      contactPhone: vehicle['contact_phone'],
                      contactEmail: vehicle['contact_email'],
                      photos: (vehicle['photos'] as List?)?.map((photo) => photo as Map<String, dynamic>).toList(),
                      currentBid: (vehicle['current_bid'] as num?)?.toDouble() ?? (vehicle['highest_bid'] as num?)?.toDouble(),
                      exteriorColor: vehicle['exterior_color'],
                      interiorColor: vehicle['interior_color'],
                      condition: vehicle['condition'],
                    );
                    print('   Constructed Car object: ${car.toJson()}'); // Log the constructed Car object
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsScreen(car: car),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View Vehicle'),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccentColor,
                  ),
                ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          _buildDetailRow('Make', vehicle['make'] ?? 'N/A'),
          _buildDetailRow('Model', vehicle['model'] ?? 'N/A'),
          _buildDetailRow('Year', vehicle['year']?.toString() ?? 'N/A'),
          if (vehicle['vin'] != null && vehicle['vin'].toString().isNotEmpty)
            _buildDetailRow('VIN', vehicle['vin']),
          if (vehicle['mileage'] != null)
            _buildDetailRow('Mileage', '${vehicle['mileage']} miles'),
          if (vehicle['location'] != null && vehicle['location'].toString().isNotEmpty)
            _buildDetailRow('Location', vehicle['location']),
        ],
      ),
    );
  }

  Widget _buildInspectionInfoCard() {
    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: kAccentColor,
                size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Text(
                'Inspection Information',
                style: ResponsiveHelper.headingStyle(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          _buildDetailRow('Request Type', _inspectionData!['request_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'N/A'),
          _buildDetailRow('Requested At', _formatDate(_inspectionData!['requested_at'])),
          if (_inspectionData!['scheduled_date'] != null)
            _buildDetailRow('Scheduled Date', _formatDateOnly(_inspectionData!['scheduled_date'])),
          if (_inspectionData!['location'] != null && _inspectionData!['location'].toString().isNotEmpty)
            _buildDetailRow('Location', _inspectionData!['location']),
          if (_inspectionData!['notes'] != null && _inspectionData!['notes'].toString().isNotEmpty)
            _buildDetailRow('Notes', _inspectionData!['notes'], isMultiline: true),
        ],
      ),
    );
  }

  Widget _buildTrackRecordCard() {
    final trackRecord = _inspectionData!['track_record'] as List<dynamic>? ?? [];
    
    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline,
                color: kAccentColor,
                size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Text(
                'Track Record',
                style: ResponsiveHelper.headingStyle(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          if (trackRecord.isEmpty)
            Padding(
              padding: ResponsiveHelper.padding(context, all: 16),
              child: Text(
                'No track record available',
                style: ResponsiveHelper.bodyStyle(context).copyWith(
                  color: Colors.grey[600],
                ),
              ),
            )
          else
            ...trackRecord.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value as Map<String, dynamic>;
              final isLast = index == trackRecord.length - 1;
              
              return _buildTrackRecordItem(record, isLast);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTrackRecordItem(Map<String, dynamic> record, bool isLast) {
    final status = record['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                _getStatusIcon(status),
                size: 12,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
          ],
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 16)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : ResponsiveHelper.spacing(context, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['label'] as String? ?? 'Unknown',
                  style: ResponsiveHelper.headingStyle(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  record['description'] as String? ?? '',
                  style: ResponsiveHelper.bodyStyle(context),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  _formatDate(record['date']?.toString()),
                  style: ResponsiveHelper.captionStyle(context).copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                // Show assigned by info if available
                if (record['assigned_by'] != null) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 16, color: Colors.blue[700]),
                        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                        Expanded(
                          child: Text(
                            'Assigned by: ${record['assigned_by']}',
                            style: ResponsiveHelper.captionStyle(context).copyWith(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInspectorCard() {
    final inspector = _inspectionData!['inspector'] as Map<String, dynamic>?;
    if (inspector == null) return const SizedBox.shrink();

    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: kAccentColor,
                size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Text(
                'Inspector Information',
                style: ResponsiveHelper.headingStyle(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          _buildDetailRow('Name', inspector['name'] ?? 'N/A'),
          _buildDetailRow('Email', inspector['email'] ?? 'N/A'),
          if (inspector['phone'] != null && inspector['phone'].toString().isNotEmpty)
            _buildDetailRow('Phone', inspector['phone']),
        ],
      ),
    );
  }

  Widget _buildAssignedByCard() {
    final assignedBy = _inspectionData!['assigned_by'] as Map<String, dynamic>?;
    if (assignedBy == null) return const SizedBox.shrink();

    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.blue[700],
                size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Text(
                'Assigned By Admin',
                style: ResponsiveHelper.headingStyle(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          _buildDetailRow('Admin Name', assignedBy['name'] ?? 'N/A'),
          _buildDetailRow('Admin Email', assignedBy['email'] ?? 'N/A'),
          if (_inspectionData!['assigned_at'] != null)
            _buildDetailRow('Assigned At', _formatDate(_inspectionData!['assigned_at'])),
        ],
      ),
    );
  }

  Widget _buildReportCard() {
    final report = _inspectionData!['report'] as Map<String, dynamic>?;
    if (report == null) return const SizedBox.shrink();

    return Container(
      padding: ResponsiveHelper.padding(context, all: 20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in,
                color: Colors.green[700],
                size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Text(
                'Inspection Report',
                style: ResponsiveHelper.headingStyle(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          _buildDetailRow('Overall Grade', (report['overall_grade'] as String? ?? 'N/A').toUpperCase()),
          if (report['summary'] != null && report['summary'].toString().isNotEmpty)
            _buildDetailRow('Summary', report['summary'], isMultiline: true),
          if (report['recommendations'] != null && report['recommendations'].toString().isNotEmpty)
            _buildDetailRow('Recommendations', report['recommendations'], isMultiline: true),
          _buildDetailRow('Report Status', (report['status'] as String? ?? 'N/A').toUpperCase()),
          if (report['created_at'] != null)
            _buildDetailRow('Report Date', _formatDate(report['created_at'])),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ResponsiveHelper.captionStyle(context).copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          Text(
            value,
            style: ResponsiveHelper.bodyStyle(context).copyWith(
              color: kBlackColor,
            ),
            maxLines: isMultiline ? null : 2,
            overflow: isMultiline ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

