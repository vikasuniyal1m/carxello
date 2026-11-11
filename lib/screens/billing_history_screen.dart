import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carauction/services/invoice_service.dart';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/screens/invoice_view_screen.dart';
import 'package:carauction/screens/vehicle_shipping_screen.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:carauction/screens/transport_tracking_screen.dart';
import 'package:carauction/screens/inspection_details_screen.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class BillingHistoryScreen extends StatefulWidget {
  final bool hideScaffold; // If true, return only body content (no Scaffold)

  const BillingHistoryScreen({super.key, this.hideScaffold = false});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final CarService _carService = CarService();
  final TransportService _transportService = TransportService();
  List<Map<String, dynamic>> _billingHistory = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  Map<String, bool> _downloadingInvoices = {};
  Map<String, bool> _transportExists = {}; // Cache for transport order existence
  Map<String, bool> _loadingVehicle = {}; // Track loading state for each vehicle button

  bool _isLoadingInProgress = false; // Track if a load is actually in progress

  @override
  void initState() {
    super.initState();
    print('🏗️ BillingHistoryScreen.initState: Initializing...');
    print('   hideScaffold: ${widget.hideScaffold}');
    // Reset loading state and load data
    _isLoading = true;
    _isLoadingInProgress = false; // Reset flag
    _loadBillingHistory();
  }

  Future<void> _loadBillingHistory() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingInProgress) {
      print('⏭️ Billing history already loading, skipping duplicate call');
      return;
    }

    print('🔄 BillingHistoryScreen._loadBillingHistory: Starting...');
    _isLoadingInProgress = true;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      print('📞 Calling InvoiceService.getBillingHistory()...');
      final data = await _invoiceService.getBillingHistory();
      print('✅ Received data from InvoiceService');
      print('   - Statistics keys: ${(data['statistics'] as Map<String, dynamic>?)?.keys.toList() ?? []}');
      print('   - Billing history count: ${(data['billing_history'] as List<dynamic>?)?.length ?? 0}');

      if (mounted) {
        setState(() {
          _statistics = data['statistics'] ?? {};
          _billingHistory = List<Map<String, dynamic>>.from(data['billing_history'] ?? []);
          _isLoading = false;
          _isLoadingInProgress = false; // Reset flag
        });
        print('✅ Billing history loaded successfully: ${_billingHistory.length} invoices');
      } else {
        print('⚠️ Widget not mounted, skipping setState');
        _isLoadingInProgress = false; // Reset flag even if not mounted
      }

      // Populate cache from invoice data (backend already includes transport info)
      // This matches PHP logic: SELECT id FROM transport_orders WHERE vehicle_id = ? AND buyer_id = ?
      int transportCount = 0;
      for (final invoice in _billingHistory) {
        final transport = invoice['transport'] as Map<String, dynamic>?;
        final vehicleId = invoice['vehicle_id']?.toString() ?? invoice['vehicle']?['id']?.toString();

        // Debug: Log transport data for each invoice
        if (vehicleId != null) {
          print('🔍 Invoice ${invoice['invoice_number']}: Vehicle $vehicleId - Transport: ${transport != null ? "exists (ID=${transport['id']}, Status=${transport['status']})" : "null"}');
        }

        // Check if transport exists (same logic as PHP: if existing_transport is not null)
        if (transport != null && transport['id'] != null && vehicleId != null) {
          // Update cache based on invoice data
          _transportExists[vehicleId] = true;
          transportCount++;
          print('✅ Invoice ${invoice['invoice_number']}: Transport scheduled (ID=${transport['id']}, Status=${transport['status']})');
        } else if (vehicleId != null) {
          // Explicitly mark as false if no transport data (to clear stale cache)
          _transportExists[vehicleId] = false;
        }
      }

      print('📊 Transport cache: ${transportCount} vehicles with transport out of ${_billingHistory.length} invoices');

      // Don't check transport status for all vehicles at once via API
      // Use transport data from invoice response instead
      // This prevents too many API calls
    } catch (e, stackTrace) {
      print('❌ Error loading billing history: $e');
      print('📚 Stack trace: $stackTrace');

      _isLoadingInProgress = false; // Always reset flag on error

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load billing history: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        print('⚠️ Widget not mounted, cannot show error message');
      }
    }
  }

  Future<void> _checkTransportStatus(String vehicleId) async {
    try {
      final status = await _transportService.getTransportOrder(vehicleId);
      if (mounted) {
        setState(() {
          _transportExists[vehicleId] = status?['order'] != null && status['order']['id'] != null;
        });
      }
    } catch (e) {
      // Transport order doesn't exist (404) - this is normal
      if (mounted) {
        setState(() {
          _transportExists[vehicleId] = false;
        });
      }
    }
  }

  /// Check if transport order exists for this vehicle
  /// Matches PHP logic: SELECT id FROM transport_orders WHERE vehicle_id = ? AND buyer_id = ?
  /// First checks invoice data (transport field from backend), then cache
  bool _hasTransport(Map<String, dynamic>? transport, String? vehicleId) {
    // First check if transport data exists in invoice (from backend billing history API)
    // Backend returns transport data with 'id' field if transport order exists (same as PHP's existing_transport check)
    if (transport != null && transport['id'] != null) {
      // Update cache when we find transport in invoice data
      if (vehicleId != null) {
        _transportExists[vehicleId] = true;
      }
      return true;
    }

    // Then check cache (if we've checked via API before)
    if (vehicleId != null && _transportExists[vehicleId] == true) {
      return true;
    }

    // No transport found (matches PHP: existing_transport is null)
    return false;
  }

  /// Get transport button text based on status
  String _getTransportButtonText(Map<String, dynamic>? transport) {
    if (transport == null || transport['id'] == null) {
      return 'Book Transport';
    }

    // Once transport is booked (any status), show "Track Your Order"
    return 'Track Your Order';
  }

  /// Get transport status display text
  String _getTransportStatusText(Map<String, dynamic>? transport) {
    if (transport == null || transport['id'] == null) {
      return 'Not Scheduled';
    }

    final status = transport['status'] as String? ?? 'pending';
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Awaiting Transporter Acceptance';
      case 'in_transit':
        final pickupDate = transport['pickup_date'] as String?;
        if (pickupDate != null) {
          return 'In Transit - Picked Up';
        }
        return 'In Transit';
      case 'delivered':
        final deliveryDate = transport['delivery_date'] as String?;
        if (deliveryDate != null) {
          return 'Delivered';
        }
        return 'Delivered';
      default:
        return 'Status: ${status.toUpperCase()}';
    }
  }

  /// Get transport schedule details (pickup and delivery dates)
  String? _getTransportScheduleDetails(Map<String, dynamic>? transport) {
    if (transport == null || transport['id'] == null) {
      return null;
    }

    final pickupDate = transport['pickup_date'] as String?;
    final deliveryDate = transport['delivery_date'] as String?;

    if (pickupDate != null && deliveryDate != null) {
      try {
        final pickup = DateTime.parse(pickupDate);
        final delivery = DateTime.parse(deliveryDate);
        return 'Pickup: ${_formatDateTime(pickup)} | Delivery: ${_formatDateTime(delivery)}';
      } catch (e) {
        return 'Pickup: ${pickupDate} | Delivery: ${deliveryDate}';
      }
    } else if (pickupDate != null) {
      try {
        final pickup = DateTime.parse(pickupDate);
        return 'Pickup: ${_formatDateTime(pickup)}';
      } catch (e) {
        return 'Pickup: $pickupDate';
      }
    } else if (deliveryDate != null) {
      try {
        final delivery = DateTime.parse(deliveryDate);
        return 'Delivery: ${_formatDateTime(delivery)}';
      } catch (e) {
        return 'Delivery: $deliveryDate';
      }
    }

    return null;
  }

  /// Format date and time for display
  String _formatDateTime(DateTime dateTime) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = monthNames[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$month $day, $year at $displayHour:$displayMinute $amPm';
  }

  /// Get transport status color
  Color _getTransportStatusColor(Map<String, dynamic>? transport) {
    if (transport == null || transport['id'] == null) {
      return Colors.grey;
    }

    final status = transport['status'] as String? ?? 'pending';
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Get transport status icon
  IconData _getTransportStatusIcon(Map<String, dynamic>? transport) {
    if (transport == null || transport['id'] == null) {
      return Icons.info_outline;
    }

    final status = transport['status'] as String? ?? 'pending';
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'in_transit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  /// Show transport status in a dialog (instead of navigating to new page)
  void _showTransportStatusDialog(BuildContext context, Map<String, dynamic>? transport, String? vehicleId) {
    if (transport == null) {
      // If transport data is not available, show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transport status not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final status = transport['status'] as String? ?? 'pending';
    final statusText = _getTransportStatusText(transport);
    final statusColor = _getTransportStatusColor(transport);
    final statusIcon = _getTransportStatusIcon(transport);
    final scheduleDetails = _getTransportScheduleDetails(transport);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Transport Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (scheduleDetails != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scheduleDetails,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (transport['delivery_address'] != null || transport['delivery_location'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery Address',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transport['delivery_address'] ?? transport['delivery_location'] ?? 'Not set',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to full transport tracking screen if user wants more details
              if (vehicleId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransportTrackingScreen(
                      vehicleId: vehicleId,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _viewInvoice(Map<String, dynamic> invoice) {
    final invoiceId = invoice['id'].toString();
    final invoiceNumber = invoice['invoice_number'] as String? ?? 'N/A';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceViewScreen(
          invoiceId: invoiceId,
          invoiceNumber: invoiceNumber,
          invoiceData: invoice,
        ),
      ),
    );
  }

  Future<void> _navigateToVehicle(Map<String, dynamic>? vehicle, String? vehicleId) async {
    if (vehicle == null || vehicleId == null) {
      print('⚠️ Cannot navigate: Vehicle data is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle information not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check if already loading
    if (_loadingVehicle[vehicleId] == true) {
      print('⏭️ Vehicle $vehicleId already loading, skipping duplicate call');
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        _loadingVehicle[vehicleId] = true;
      });
    }

    try {
      print('🚗 Loading vehicle details: $vehicleId');

      // Try to fetch full vehicle details from API
      Car? car;
      try {
        car = await _carService.getVehicleById(vehicleId).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('⏱️ Timeout loading vehicle $vehicleId');
            throw Exception('Timeout loading vehicle details');
          },
        );
        print('✅ Vehicle fetched from API');
      } catch (e) {
        print('⚠️ Could not fetch vehicle from API, using available data: $e');
        // Fallback: Create Car object from available data
        final imageUrl = vehicle['image_url'] as String? ?? vehicle['imageUrl'] as String? ?? 'assets/images/car1.png';
        final year = (vehicle['year'] is int)
            ? vehicle['year'] as int
            : ((vehicle['year'] is String) ? int.tryParse(vehicle['year']) ?? 0 : 0);

        car = Car(
          id: vehicleId,
          make: vehicle['make'] as String? ?? 'Unknown',
          model: vehicle['model'] as String? ?? 'Vehicle',
          year: year,
          imageUrl: imageUrl,
          startingBid: 0,
          buyNowPrice: 0,
          mileage: 0,
          location: '',
          distance: '',
          auctionEndTime: DateTime.now(),
          status: 'sold', // Purchased vehicles are sold
          vin: vehicle['vin'] as String?,
          description: null,
        );
      }

      // Reset loading state before navigation
      if (mounted) {
        setState(() {
          _loadingVehicle[vehicleId] = false;
        });
      }

      if (car != null && mounted) {
        print('✅ Vehicle data loaded, navigating to ProductDetailsScreen');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(car: car!),
          ),
        );
      } else {
        throw Exception('Could not load vehicle details');
      }
    } catch (e) {
      print('❌ Error navigating to vehicle: $e');

      // Reset loading state on error
      if (mounted) {
        setState(() {
          _loadingVehicle[vehicleId] = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load vehicle details: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadInvoice(String invoiceId, String invoiceNumber) async {
    setState(() {
      _downloadingInvoices[invoiceId] = true;
    });

    try {
      final filePath = await _invoiceService.downloadInvoice(invoiceId, invoiceNumber);
      if (mounted) {
        // Show success message with file path
        final fileName = filePath.split('/').last;
        final file = File(filePath);
        final fileSize = await file.length();
        final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);

        print('✅ Invoice downloaded successfully!');
        print('   📄 File: $fileName');
        print('   📁 Path: $filePath');
        print('   💾 Size: $fileSizeKB KB');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Text(
                        'Invoice Downloaded Successfully!',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'File: $fileName',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  'Size: $fileSizeKB KB',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  'Saved to: ${filePath.length > 50 ? '...${filePath.substring(filePath.length - 50)}' : filePath}',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                    color: Colors.white60,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Extract user-friendly error message
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceAll('Exception: ', '');
        }
        if (errorMessage.contains('Failed to download invoice: ')) {
          errorMessage = errorMessage.replaceAll('Failed to download invoice: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Failed',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        errorMessage,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
              ),
            ),
            action: errorMessage.toLowerCase().contains('permission')
                ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () async {
                      // Open app settings
                      await openAppSettings();
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      setState(() {
        _downloadingInvoices[invoiceId] = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _formatDate(String? dateStr) {
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
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green.shade50;
      case 'pending':
        return Colors.orange.shade50;
      case 'failed':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  // Build body content (can be used with or without Scaffold)
  Widget _buildBodyContent() {
    return _isLoading
        ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadBillingHistory,
            color: kAccentColor,
            child: SingleChildScrollView(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 16 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Cards
                  _buildStatisticsCards(),
                  SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                  // Invoice History Title
                  Padding(
                    padding: ResponsiveHelper.padding(
                      context,
                      horizontal: ResponsiveHelper.isMobile(context) ? 4 : 0,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
                          decoration: BoxDecoration(
                            color: kAccentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          'Invoice History',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                            fontWeight: FontWeight.bold,
                            color: kBlackColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  // Invoices List
                  _billingHistory.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: _billingHistory.map((invoice) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: ResponsiveHelper.spacing(context, 16),
                              ),
                              child: _buildInvoiceCard(invoice),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    // If hideScaffold is true, return only body content (for embedding in other screens)
    if (widget.hideScaffold) {
      return _buildBodyContent();
    }

    // Otherwise, return full screen with Scaffold (for standalone use)
    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      enableScroll: false,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        toolbarHeight: ScreenSize.isLargeTablet ? 64.0 : (ScreenSize.isSmallTablet ? ScreenSize.appBarHeight : ResponsiveHelper.appBarHeight(context)),
        iconTheme: IconThemeData(
          color: kWhiteColor,
          size: ScreenSize.isLargeTablet ? 32.0 : (ScreenSize.isSmallTablet ? ScreenSize.iconLarge : 28.0),
        ),
        centerTitle: ScreenSize.isLargeTablet ? true : false,
        leadingWidth: ScreenSize.isLargeTablet ? 80.0 : null,
        title: Text(
          'Billing History',
          style: TextStyle(
            fontSize: ScreenSize.isLargeTablet ? 24.0 : (ScreenSize.isSmallTablet ? ScreenSize.headingMedium : 22.0),
            color: kWhiteColor,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildStatisticsCards() {
    final totalPaid = (_statistics['total_paid'] as num?)?.toDouble() ?? 0.0;
    final totalPending = (_statistics['total_pending'] as num?)?.toDouble() ?? 0.0;
    final invoiceCount = (_statistics['invoice_count'] as int?) ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final spacing = ResponsiveHelper.spacing(context, 8);
        final columns = w < 380 ? 2 : 3;
        final cardWidth = (w - spacing * (columns - 1)) / columns;
        final cards = [
          _buildStatCard(
            context,
            icon: Icons.attach_money,
            iconColor: Colors.white,
            iconBgColor: Colors.green,
            number: _formatCurrency(totalPaid),
            label: 'Total Paid',
          ),
          _buildStatCard(
            context,
            icon: Icons.access_time,
            iconColor: Colors.white,
            iconBgColor: Colors.red,
            number: _formatCurrency(totalPending),
            label: 'Pending Payments',
          ),
          _buildStatCard(
            context,
            icon: Icons.receipt,
            iconColor: Colors.white,
            iconBgColor: Colors.blue,
            number: invoiceCount.toString(),
            label: 'Total Invoices',
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String number,
    required String label,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 16 : isTablet ? 20 : 24,
      ),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 15, desktop: 18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: ResponsiveHelper.fontSize(context, mobile: 8, tablet: 10, desktop: 12),
            offset: Offset(0, ResponsiveHelper.fontSize(context, mobile: 4, tablet: 5, desktop: 6)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ResponsiveHelper.fontSize(context, mobile: 56, tablet: 64, desktop: 72),
            height: ResponsiveHelper.fontSize(context, mobile: 56, tablet: 64, desktop: 72),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconBgColor,
                  iconBgColor.withOpacity(0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconBgColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, isMobile ? 10 : 12)),
          Text(
            number,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          Text(
            label,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoice_number'] as String? ?? 'N/A';
    final paymentStatus = invoice['payment_status'] as String? ?? 'pending';
    final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
    final vehicle = invoice['vehicle'] as Map<String, dynamic>?;
    final description = invoice['description'] as String? ?? 'Service Payment';
    final dueDate = invoice['due_date'] as String?;
    final createdAt = invoice['created_at'] as String?;
    final invoiceId = invoice['id'].toString();
    final isDownloading = _downloadingInvoices[invoiceId] ?? false;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final inspection = invoice['inspection'] as Map<String, dynamic>?;
    final transport = invoice['transport'] as Map<String, dynamic>?;
    final vehicleId = vehicle?['id']?.toString();

    // Debug: Log transport data for this invoice
    if (vehicleId != null) {
      if (transport != null && transport['id'] != null) {
        print('📦 Invoice ${invoice['invoice_number']}: Vehicle $vehicleId has transport ID=${transport['id']}, Status=${transport['status']}');
      } else {
        // Only log once per invoice to avoid spam
        if (!_transportExists.containsKey(vehicleId)) {
          print('📦 Invoice ${invoice['invoice_number']}: Vehicle $vehicleId - no transport data in invoice');
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 15, desktop: 18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: ResponsiveHelper.fontSize(context, mobile: 8, tablet: 10, desktop: 12),
            offset: Offset(0, ResponsiveHelper.fontSize(context, mobile: 4, tablet: 5, desktop: 6)),
          ),
        ],
        border: Border.all(
          color: Colors.grey[200]!,
          width: ResponsiveHelper.isMobile(context) ? 1.0 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Header
          Container(
            padding: ResponsiveHelper.padding(
              context,
              all: isMobile ? 16 : isTablet ? 20 : 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kAccentColor,
                  kAccentColor.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 15, desktop: 18)),
                topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 15, desktop: 18)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        invoiceNumber,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 17, tablet: 19, desktop: 21),
                          fontWeight: FontWeight.bold,
                          color: kWhiteColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        'Created: ${_formatDate(createdAt)}',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                          color: kWhiteColor.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                Container(
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: isMobile ? 12 : 14,
                    vertical: isMobile ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(paymentStatus).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 18, tablet: 20, desktop: 22)),
                    border: Border.all(
                      color: _getStatusColor(paymentStatus).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    paymentStatus.toUpperCase(),
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(paymentStatus),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Invoice Body
          Padding(
            padding: ResponsiveHelper.padding(
              context,
              all: isMobile ? 16 : isTablet ? 20 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice Details Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = ResponsiveHelper.isMobile(context);
                    if (isMobile) {
                      final gap = ResponsiveHelper.spacing(context, 12);
                      final half = (constraints.maxWidth - gap) / 2;
                      final vehicleText = vehicle != null
                          ? '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}'
                          : 'Service Payment';
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(width: half, child: _buildDetailItem(context, 'Vehicle', vehicleText)),
                          SizedBox(width: half, child: _buildDetailItem(context, 'Amount', _formatCurrency(totalAmount), isAmount: true)),
                          if (vehicle != null && vehicle['vin'] != null)
                            SizedBox(width: half, child: _buildDetailItem(context, 'VIN', vehicle['vin'] as String)),
                          SizedBox(width: half, child: _buildDetailItem(context, 'Due Date', _formatDate(dueDate))),
                          SizedBox(width: constraints.maxWidth, child: _buildDetailItem(context, 'Description', description)),
                        ],
                      );
                    } else {
                      // Use Wrap for better overflow handling on smaller screens
                      return Wrap(
                        spacing: ResponsiveHelper.spacing(context, 12),
                        runSpacing: ResponsiveHelper.spacing(context, 12),
                        children: [
                          Flexible(
                            flex: 2,
                            child: _buildDetailItem(context, 'Vehicle', vehicle != null
                                ? '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}'
                                : 'Service Payment'),
                          ),
                          if (vehicle != null && vehicle['vin'] != null)
                            Flexible(
                              flex: 1,
                              child: _buildDetailItem(context, 'VIN', vehicle['vin'] as String),
                            ),
                          Flexible(
                            flex: 2,
                            child: _buildDetailItem(context, 'Description', description),
                          ),
                          Flexible(
                            flex: 1,
                            child: _buildDetailItem(context, 'Amount', _formatCurrency(totalAmount), isAmount: true),
                          ),
                          Flexible(
                            flex: 1,
                            child: _buildDetailItem(context, 'Due Date', _formatDate(dueDate)),
                          ),
                        ],
                      );
                    }
                  },
                ),
                // Transport Status Display
                if (vehicleId != null && _hasTransport(transport, vehicleId)) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                  Container(
                    padding: ResponsiveHelper.padding(
                      context,
                      all: isMobile ? 14 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: _getTransportStatusColor(transport).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                      ),
                      border: Border.all(
                        color: _getTransportStatusColor(transport).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getTransportStatusIcon(transport),
                          color: _getTransportStatusColor(transport),
                          size: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transport Status',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                _getTransportStatusText(transport),
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                  fontWeight: FontWeight.bold,
                                  color: _getTransportStatusColor(transport),
                                ),
                              ),
                              // Show schedule details if available
                              if (_getTransportScheduleDetails(transport) != null) ...[
                                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                                Text(
                                  _getTransportScheduleDetails(transport)!,
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                // Action Buttons
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = ResponsiveHelper.isMobile(context);
                    if (isMobile) {
                      return Column(
                        children: [
                          if (paymentStatus == 'paid')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _viewInvoice(invoice),
                                icon: const Icon(Icons.visibility),
                                label: const Text('View Invoice'),
                                style: ResponsiveHelper.adaptiveButtonStyle(
                                  context,
                                  backgroundColor: Colors.green[700]!,
                                  foregroundColor: Colors.white,
                                ).copyWith(
                                  padding: MaterialStateProperty.all(
                                    ResponsiveHelper.padding(
                                      context,
                                      vertical: isMobile ? 12 : 14,
                                      horizontal: isMobile ? 16 : 20,
                                    ),
                                  ),
                                  shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // View Vehicle button (only show if paid AND purchase_id exists - matching billing.php)
                          if (paymentStatus == 'paid' &&
                              vehicle != null &&
                              invoice['purchase_id'] != null) ...[
                            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                            SizedBox(
                              width: isMobile ? double.infinity : null,
                              child: OutlinedButton.icon(
                                onPressed: (_loadingVehicle[vehicleId] == true)
                                    ? null
                                    : () => _navigateToVehicle(vehicle, vehicleId),
                                icon: (_loadingVehicle[vehicleId] == true)
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                                        ),
                                      )
                                    : const Icon(Icons.directions_car),
                                label: Text(
                                  (_loadingVehicle[vehicleId] == true) ? 'Loading...' : 'View Vehicle',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kAccentColor,
                                  side: BorderSide(
                                    color: kAccentColor,
                                    width: ResponsiveHelper.isMobile(context) ? 1.5 : 2.0,
                                  ),
                                  padding: ResponsiveHelper.padding(
                                    context,
                                    vertical: isMobile ? 12 : 14,
                                    horizontal: isMobile ? 16 : 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Inspection button
                            if (inspection != null) ...[
                              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                              SizedBox(
                                width: isMobile ? double.infinity : null,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // Navigate to inspection details screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InspectionDetailsScreen(
                                          inspectionId: inspection['id'].toString(),
                                          initialData: inspection,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.search),
                                  label: Text('Inspection: ${inspection['status'] ?? 'N/A'}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    side: const BorderSide(color: Colors.blue, width: 1.5),
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      vertical: isMobile ? 12 : 14,
                                      horizontal: isMobile ? 16 : 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Transport button
                            if (vehicleId != null) ...[
                              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                              SizedBox(
                                width: isMobile ? double.infinity : null,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // Show loading
                                    if (!mounted) return;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    try {
                                      // Check transport status immediately
                                      // First check invoice data (this is the primary source - backend already includes transport info)
                                      bool hasTransport = _hasTransport(transport, vehicleId);

                                      print('🔍 Book Transport Button Click:');
                                      print('   - Vehicle ID: $vehicleId');
                                      print('   - Transport from invoice: ${transport != null ? "exists (ID=${transport['id']}, Status=${transport['status']})" : "null"}');
                                      print('   - _hasTransport result: $hasTransport');

                                      // Only check API if transport is NOT found in invoice data
                                      // If invoice data has transport, use it directly (backend is the source of truth)
                                      if (!hasTransport && vehicleId != null) {
                                        print('   - Transport not in invoice data, checking API...');
                                        try {
                                          final status = await _transportService.getTransportOrder(vehicleId);
                                          hasTransport = status?['order'] != null && status['order']['id'] != null;
                                          print('   - API check result: $hasTransport');
                                          // Update cache
                                          if (mounted) {
                                            setState(() {
                                              _transportExists[vehicleId] = hasTransport;
                                            });
                                          }
                                        } catch (e) {
                                          // Transport doesn't exist (404) - this is normal, not an error
                                          print('   - API returned 404 (transport not found) - this is normal');
                                          hasTransport = false;
                                          if (mounted) {
                                            setState(() {
                                              _transportExists[vehicleId] = false;
                                            });
                                          }

                                          // Close loading
                                          if (mounted) Navigator.pop(context);

                                          // Don't show error for 404 - it just means transport doesn't exist yet
                                          // Only show error for actual network issues
                                          final errorMsg = e.toString().toLowerCase();
                                          if (errorMsg.contains('network') ||
                                              errorMsg.contains('host lookup') ||
                                              errorMsg.contains('timeout') ||
                                              errorMsg.contains('socket')) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Network error: Unable to check transport status. Please try again.'),
                                                  backgroundColor: Colors.orange,
                                                  duration: Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          }
                                          // Continue to booking page if no network error
                                        }
                                      } else {
                                        print('   - Using transport data from invoice (no API call needed)');
                                      }

                                      // Close loading before showing dialog or navigating
                                      if (mounted) Navigator.pop(context);

                                      if (!mounted) return;

                                      if (hasTransport) {
                                        print('   - Transport exists, showing status dialog');
                                        // Show transport status in dialog (don't navigate to new page)
                                        // Use transport data from invoice (backend is source of truth)
                                        Map<String, dynamic>? transportData = transport;

                                        // If transport data from invoice is complete, use it
                                        // Otherwise, try to fetch from API (but this should rarely happen)
                                        if (transportData == null || transportData['id'] == null) {
                                          print('   - Transport data incomplete, fetching from API...');
                                          if (vehicleId != null) {
                                            try {
                                              final status = await _transportService.getTransportOrder(vehicleId);
                                              transportData = status['order'] as Map<String, dynamic>?;
                                            } catch (e) {
                                              print('⚠️ Error fetching transport data from API: $e');
                                              // Use whatever transport data we have from invoice
                                              transportData = transport;
                                            }
                                          }
                                        }

                                        if (mounted && transportData != null) {
                                          _showTransportStatusDialog(context, transportData, vehicleId);
                                        } else {
                                          print('⚠️ No transport data available to show');
                                        }
                                      } else {
                                        // Navigate to transport scheduling
                                        if (vehicle != null && vehicleId != null) {
                                          final car = Car(
                                            id: vehicleId,
                                            make: vehicle['make'] ?? '',
                                            model: vehicle['model'] ?? '',
                                            year: vehicle['year'] ?? 0,
                                            imageUrl: vehicle['image_url'] ?? '',
                                            startingBid: 0,
                                            buyNowPrice: 0,
                                            mileage: 0,
                                            location: '',
                                            distance: '',
                                            auctionEndTime: DateTime.now(),
                                            status: 'sold',
                                            description: '',
                                          );
                                          if (mounted) {
                                            print('🚀 ========================================');
                                            print('🚀 NAVIGATING TO VEHICLE SHIPPING SCREEN');
                                            print('🚀 ========================================');
                                            print('🚀 Vehicle ID: $vehicleId');
                                            print('🚀 Widget mounted: $mounted');
                                            print('🚀 Current route: ${ModalRoute.of(context)?.settings.name ?? 'unknown'}');

                                            // Store the vehicle ID for refresh after navigation
                                            final vehicleIdForRefresh = vehicleId;

                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => VehicleShippingScreen(car: car),
                                              ),
                                            ).then((result) async {
                                              print('🔄 ========================================');
                                              print('🔄 RETURNED FROM VEHICLE SHIPPING SCREEN');
                                              print('🔄 ========================================');
                                              print('🔄 Result: $result');
                                              print('🔄 Widget mounted: $mounted');
                                              print('🔄 Current route: ${ModalRoute.of(context)?.settings.name ?? 'unknown'}');

                                              // Add a small delay to ensure widget is fully ready
                                              await Future.delayed(const Duration(milliseconds: 100));

                                              // After scheduling, refresh data to update button
                                              if (mounted) {
                                                if (result == true) {
                                                  print('✅ Result is true - transport scheduled successfully');
                                                  print('🔄 Starting billing history refresh...');

                                                  try {
                                                    // Reload billing history to get updated transport data from backend
                                                    // This will refresh the transport status in the invoice data
                                                    await _loadBillingHistory();

                                                    print('✅ Billing history refreshed successfully');
                                                    print('✅ Transport status updated for vehicle $vehicleIdForRefresh');
                                                    print('✅ ========================================');
                                                  } catch (e, stackTrace) {
                                                    print('❌ Error refreshing billing history: $e');
                                                    print('❌ Stack Trace: $stackTrace');
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Transport scheduled but failed to refresh data: ${e.toString()}'),
                                                          backgroundColor: Colors.orange,
                                                          duration: const Duration(seconds: 3),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                } else {
                                                  print('⚠️ Result is not true');
                                                  print('   Result: $result');
                                                  print('   Skipping billing history refresh');
                                                }
                                              } else {
                                                print('⚠️ Widget not mounted after navigation');
                                                print('   Skipping billing history refresh');
                                              }
                                            }).catchError((error) {
                                              print('❌ ========================================');
                                              print('❌ ERROR IN NAVIGATION CALLBACK');
                                              print('❌ ========================================');
                                              print('❌ Error: $error');
                                              print('❌ Widget mounted: $mounted');
                                            });

                                            // Also set up a listener for when the route is popped
                                            // This is a backup in case .then() doesn't execute
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              // This will execute after the navigation completes
                                              // We'll check if we need to refresh after a delay
                                              Future.delayed(const Duration(milliseconds: 500), () {
                                                if (mounted) {
                                                  print('🔄 PostFrameCallback: Checking if refresh needed...');
                                                  // The .then() callback should handle this, but this is a backup
                                                }
                                              });
                                            });
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      // Close loading on error
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      print('❌ Error checking transport status: $e');
                                    }
                                  },
                                  icon: Icon(
                                    _hasTransport(transport, vehicleId)
                                        ? Icons.visibility
                                        : Icons.add_shopping_cart
                                  ),
                                  label: Text(
                                    _getTransportButtonText(transport),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _hasTransport(transport, vehicleId)
                                        ? Colors.blue
                                        : kAccentColor,
                                    foregroundColor: Colors.white,
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      vertical: isMobile ? 12 : 14,
                                      horizontal: isMobile ? 16 : 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (paymentStatus == 'pending')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Navigate to payment screen
                                  // TODO: Implement navigation
                                },
                                icon: const Icon(Icons.credit_card),
                                label: const Text('Complete Payment'),
                                style: ResponsiveHelper.adaptiveButtonStyle(
                                  context,
                                  backgroundColor: kAccentColor,
                                  foregroundColor: Colors.white,
                                ).copyWith(
                                  padding: MaterialStateProperty.all(
                                    ResponsiveHelper.padding(
                                      context,
                                      vertical: isMobile ? 12 : 14,
                                      horizontal: isMobile ? 16 : 20,
                                    ),
                                  ),
                                  shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    } else {
                      return Wrap(
                        spacing: ResponsiveHelper.spacing(context, 12),
                        runSpacing: ResponsiveHelper.spacing(context, 12),
                        children: [
                          if (paymentStatus == 'paid')
                            ElevatedButton.icon(
                              onPressed: () => _viewInvoice(invoice),
                              icon: const Icon(Icons.visibility),
                              label: const Text('View Invoice'),
                              style: ResponsiveHelper.adaptiveButtonStyle(
                                context,
                                backgroundColor: Colors.green[700]!,
                                foregroundColor: Colors.white,
                              ).copyWith(
                                padding: MaterialStateProperty.all(
                                  ResponsiveHelper.padding(
                                    context,
                                    vertical: isMobile ? 12 : 14,
                                    horizontal: isMobile ? 16 : 20,
                                  ),
                                ),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // View Vehicle button (only show if paid AND purchase_id exists - matching billing.php)
                          if (paymentStatus == 'paid' &&
                              vehicle != null &&
                              invoice['purchase_id'] != null) ...[
                            OutlinedButton.icon(
                              onPressed: (_loadingVehicle[vehicleId] == true)
                                  ? null
                                  : () => _navigateToVehicle(vehicle, vehicleId),
                              icon: (_loadingVehicle[vehicleId] == true)
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                                      ),
                                    )
                                  : const Icon(Icons.directions_car),
                              label: Text(
                                (_loadingVehicle[vehicleId] == true) ? 'Loading...' : 'View Vehicle',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kAccentColor,
                                side: BorderSide(
                                  color: kAccentColor,
                                  width: ResponsiveHelper.isMobile(context) ? 1.5 : 2.0,
                                ),
                                padding: ResponsiveHelper.padding(
                                  context,
                                  vertical: isMobile ? 12 : 14,
                                  horizontal: isMobile ? 16 : 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                  ),
                                ),
                              ),
                            ),
                            // Inspection button
                            if (inspection != null)
                              OutlinedButton.icon(
                                onPressed: () {
                                  // Navigate to inspection details screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InspectionDetailsScreen(
                                        inspectionId: inspection['id'].toString(),
                                        initialData: inspection,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.search),
                                label: Text('Inspection: ${inspection['status'] ?? 'N/A'}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue, width: 1.5),
                                  padding: ResponsiveHelper.padding(
                                    context,
                                    vertical: isMobile ? 12 : 14,
                                    horizontal: isMobile ? 16 : 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                    ),
                                  ),
                                ),
                              ),
                            // Transport button
                            if (vehicleId != null)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Show loading
                                  if (!mounted) return;
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                    try {
                                      // Check transport status immediately
                                      // First check invoice data (this is the primary source - backend already includes transport info)
                                      bool hasTransport = _hasTransport(transport, vehicleId);

                                      print('🔍 Book Transport Button Click (Second Location):');
                                      print('   - Vehicle ID: $vehicleId');
                                      print('   - Transport from invoice: ${transport != null ? "exists (ID=${transport['id']}, Status=${transport['status']})" : "null"}');
                                      print('   - _hasTransport result: $hasTransport');

                                      // Only check API if transport is NOT found in invoice data
                                      // If invoice data has transport, use it directly (backend is the source of truth)
                                      if (!hasTransport && vehicleId != null) {
                                        print('   - Transport not in invoice data, checking API...');
                                        try {
                                          final status = await _transportService.getTransportOrder(vehicleId);
                                          hasTransport = status['order'] != null && status['order']['id'] != null;
                                          print('   - API check result: $hasTransport');
                                          // Update cache
                                          if (mounted) {
                                            setState(() {
                                              _transportExists[vehicleId] = hasTransport;
                                            });
                                          }
                                        } catch (e) {
                                          // Transport doesn't exist (404) - this is normal, not an error
                                          print('   - API returned 404 (transport not found) - this is normal');
                                          hasTransport = false;
                                          if (mounted) {
                                            setState(() {
                                              _transportExists[vehicleId] = false;
                                            });
                                          }

                                          // Close loading
                                          if (mounted) Navigator.pop(context);

                                          // Don't show error for 404 - it just means transport doesn't exist yet
                                          // Only show error for actual network issues
                                          final errorMsg = e.toString().toLowerCase();
                                          if (errorMsg.contains('network') ||
                                              errorMsg.contains('host lookup') ||
                                              errorMsg.contains('timeout') ||
                                              errorMsg.contains('socket')) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Network error: Unable to check transport status. Please try again.'),
                                                  backgroundColor: Colors.orange,
                                                  duration: Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          }
                                          // Continue to booking page if no network error
                                        }
                                      } else {
                                        print('   - Using transport data from invoice (no API call needed)');
                                      }

                                      // Close loading before showing dialog or navigating
                                      if (mounted) Navigator.pop(context);

                                      if (!mounted) return;

                                      if (hasTransport) {
                                        print('   - Transport exists, showing status dialog');
                                        // Show transport status in dialog (don't navigate to new page)
                                        // Use transport data from invoice (backend is source of truth)
                                        Map<String, dynamic>? transportData = transport;

                                        // If transport data from invoice is complete, use it
                                        // Otherwise, try to fetch from API (but this should rarely happen)
                                        if (transportData == null || transportData['id'] == null) {
                                          print('   - Transport data incomplete, fetching from API...');
                                          if (vehicleId != null) {
                                            try {
                                              final status = await _transportService.getTransportOrder(vehicleId);
                                              transportData = status['order'] as Map<String, dynamic>?;
                                            } catch (e) {
                                              print('⚠️ Error fetching transport data from API: $e');
                                              // Use whatever transport data we have from invoice
                                              transportData = transport;
                                            }
                                          }
                                        }

                                        if (mounted && transportData != null) {
                                          _showTransportStatusDialog(context, transportData, vehicleId);
                                        } else {
                                          print('⚠️ No transport data available to show');
                                        }
                                      } else {
                                      // Navigate to transport scheduling
                                      if (vehicle != null && vehicleId != null) {
                                        final car = Car(
                                          id: vehicleId,
                                          make: vehicle['make'] ?? '',
                                          model: vehicle['model'] ?? '',
                                          year: vehicle['year'] ?? 0,
                                          imageUrl: vehicle['image_url'] ?? '',
                                          startingBid: 0,
                                          buyNowPrice: 0,
                                          mileage: 0,
                                          location: '',
                                          distance: '',
                                          auctionEndTime: DateTime.now(),
                                          status: 'sold',
                                          description: '',
                                        );
                                        if (mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VehicleShippingScreen(car: car),
                                            ),
                                          ).then((result) async {
                                            // After scheduling, refresh data to update button
                                            if (mounted && result == true) {
                                              print('🔄 Returning from VehicleShippingScreen - transport scheduled successfully');

                                              // Reload billing history to get updated transport data from backend
                                              // This will refresh the transport status in the invoice data
                                              await _loadBillingHistory();

                                              print('✅ Billing history refreshed - transport status updated for vehicle $vehicleId');
                                            }
                                          });
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    // Close loading on error
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    print('❌ Error checking transport status: $e');
                                  }
                                },
                                icon: Icon(
                                  _hasTransport(transport, vehicleId)
                                      ? Icons.visibility
                                      : Icons.add_shopping_cart
                                ),
                                label: Text(
                                  _getTransportButtonText(transport),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasTransport(transport, vehicleId)
                                      ? Colors.blue
                                      : kAccentColor,
                                  foregroundColor: Colors.white,
                                  padding: ResponsiveHelper.padding(
                                    context,
                                    vertical: isMobile ? 12 : 14,
                                    horizontal: isMobile ? 16 : 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          if (paymentStatus == 'pending')
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to payment screen
                                // TODO: Implement navigation
                              },
                              icon: const Icon(Icons.credit_card),
                              label: const Text('Complete Payment'),
                              style: ResponsiveHelper.adaptiveButtonStyle(
                                context,
                                backgroundColor: kAccentColor,
                                foregroundColor: Colors.white,
                              ).copyWith(
                                padding: MaterialStateProperty.all(
                                  ResponsiveHelper.padding(
                                    context,
                                    vertical: isMobile ? 12 : 14,
                                    horizontal: isMobile ? 16 : 20,
                                  ),
                                ),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isAmount = false}) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
        SizedBox(
          width: double.infinity,
          child: Text(
            value,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(
                context,
                mobile: isAmount ? 16 : 13,
                tablet: isAmount ? 18 : 14,
                desktop: isAmount ? 20 : 15,
              ),
              fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
              color: isAmount ? Colors.green[700] : kBlackColor,
            ),
            maxLines: isAmount ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 40 : isTablet ? 60 : 80,
      ),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 15, desktop: 18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: ResponsiveHelper.fontSize(context, mobile: 8, tablet: 10, desktop: 12),
            offset: Offset(0, ResponsiveHelper.fontSize(context, mobile: 4, tablet: 5, desktop: 6)),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: ResponsiveHelper.padding(context, all: isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: ResponsiveHelper.fontSize(context, mobile: 56, tablet: 72, desktop: 88),
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),
          Text(
            'No Invoices Yet',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          Padding(
            padding: ResponsiveHelper.padding(
              context,
              horizontal: isMobile ? 20 : 40,
            ),
            child: Text(
              'Your billing history will appear here after making purchases.',
              textAlign: TextAlign.center,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.search,
              size: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
            ),
            label: Text(
              'Browse Vehicles',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ResponsiveHelper.adaptiveButtonStyle(
              context,
              backgroundColor: kAccentColor,
              foregroundColor: Colors.white,
            ).copyWith(
              padding: MaterialStateProperty.all(
                ResponsiveHelper.padding(
                  context,
                  vertical: isMobile ? 12 : 14,
                  horizontal: isMobile ? 24 : 32,
                ),
              ),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
