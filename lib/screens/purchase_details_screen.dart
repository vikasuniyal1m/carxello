import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/invoice_service.dart';
import 'package:carauction/screens/view_report_screen.dart';
import 'package:carauction/services/transport_service.dart';
import 'dart:async';

class PurchaseDetailsScreen extends StatefulWidget {
  final Car car;

  const PurchaseDetailsScreen({
    super.key,
    required this.car,
  });

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  final TransportService _transportService = TransportService();
  final InvoiceService _invoiceService = InvoiceService();
  Map<String, dynamic>? _transportOrder;
  bool _isLoadingTransport = true;
  bool _isDownloadingInvoice = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTransportOrder();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadTransportOrder();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTransportOrder() async {
    try {
      final order = await _transportService.getTransportOrder(widget.car.id);
      if (mounted) {
        setState(() {
          _transportOrder = order;
          _isLoadingTransport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTransport = false;
        });
      }
    }
  }

  Future<void> _downloadInvoice() async {
    if (widget.car.invoiceNumber == null || widget.car.invoiceNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isDownloadingInvoice = true);

    try {
      final invoiceId = widget.car.invoiceNumber!.replaceAll('INV-', '');
      final filePath = await _invoiceService.downloadInvoice(invoiceId, widget.car.invoiceNumber!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Invoice downloaded', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Download failed', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingInvoice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Purchase Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Summary Card
              _buildVehicleSummary(),
              const SizedBox(height: 16),

              // Transport & Inspection Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTransportCompact()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInspectionCompact()),
                ],
              ),
              const SizedBox(height: 16),

              // Invoice & Payment Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildInvoiceCompact()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPaymentCompact()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ COMPACT VEHICLE SUMMARY ============
  Widget _buildVehicleSummary() {
    final totalPrice = widget.car.price ?? widget.car.wonAmount ?? widget.car.buyNowPrice ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row - Image and basic info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/car1.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.car.year} ${widget.car.make} ${widget.car.model}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VIN: ${widget.car.vin ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTransportStatusColor(widget.car.transportStatus ?? 'pending').withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _getTransportStatusColor(widget.car.transportStatus ?? 'pending').withOpacity(0.3)),
                          ),
                          child: Text(
                            _getTransportStatusText(widget.car.transportStatus ?? 'pending'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getTransportStatusColor(widget.car.transportStatus ?? 'pending'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '\$${_formatNumberWithCommas(totalPrice)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Buyer info - if available
          Builder(
            builder: (context) {
              final order = _transportOrder?['order'] as Map<String, dynamic>?;
              final buyer = order?['buyer'] as Map<String, dynamic>?;
              if (buyer == null) return const SizedBox.shrink();

              final name = (buyer['full_name'] ?? '').toString();
              final email = (buyer['email'] ?? '').toString();

              if (name.isEmpty && email.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (name.isNotEmpty)
                            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          if (email.isNotEmpty)
                            Text(email, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============ COMPACT TRANSPORT TRACKING ============
  Widget _buildTransportCompact() {
    if (_isLoadingTransport) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Get steps
    List<Map<String, dynamic>> steps = _getTransportSteps();

    // Find current step index
    int currentStepIndex = steps.indexWhere((step) => step['completed'] == true);
    if (currentStepIndex == -1) currentStepIndex = 0;

    final progress = steps.isEmpty ? 0.0 : (currentStepIndex + 1) / steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Transport',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // Current status
          if (steps.isNotEmpty)
            Text(
              steps[currentStepIndex]['title'] ?? 'Processing',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // Next step if not last
          if (currentStepIndex < steps.length - 1) ...[
            const SizedBox(height: 4),
            Text(
              'Next: ${steps[currentStepIndex + 1]['title']}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ============ COMPACT INSPECTION REPORT ============
  Widget _buildInspectionCompact() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Inspection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          /*    FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Approved',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                ),
              ),*/
            ],
          ),
          const SizedBox(height: 12),

          // Inspector info
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'John Smith',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Mar 8, 2024',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick condition summary
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildConditionChip('Engine', 'Excellent'),
              _buildConditionChip('Trans', 'Good'),
              _buildConditionChip('Ext', 'Excellent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionChip(String label, String condition) {
    Color color = condition == 'Excellent' ? Colors.green :
    condition == 'Good' ? Colors.blue : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $condition',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  // ============ COMPACT INVOICE ============
  Widget _buildInvoiceCompact() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            widget.car.invoiceNumber ?? 'No invoice',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (widget.car.invoiceNumber != null && widget.car.invoiceNumber!.isNotEmpty)
            InkWell(
              onTap: _isDownloadingInvoice ? null : _downloadInvoice,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isDownloadingInvoice
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      _isDownloadingInvoice ? '...' : 'PDF',
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ COMPACT PAYMENT ============
  Widget _buildPaymentCompact() {
    final total = widget.car.price ?? widget.car.wonAmount ?? widget.car.buyNowPrice ?? 0.0;
    final deposit = 2000.0;
    final remaining = total - deposit;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 12)),
              Text('\$${_formatNumberWithCommas(total)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.green)),
              Text('\$${_formatNumberWithCommas(deposit)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Due', style: TextStyle(fontSize: 12, color: Colors.orange)),
              Text('\$${_formatNumberWithCommas(remaining)}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          /*SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewReportScreen(car: widget.car),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: const Size(0, 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Report',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ),
          ),*/
        ],
      ),
    );
  }

  // ============ HELPER FUNCTIONS ============
  List<Map<String, dynamic>> _getTransportSteps() {
    if (_transportOrder != null && _transportOrder!['timeline'] != null) {
      final timeline = _transportOrder!['timeline'];
      if (timeline is List) {
        return timeline
            .where((item) => item is Map<String, dynamic> && item['title'] != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    }

    // Fallback
    final transportStatus = widget.car.transportStatus ?? 'pending';

    if (transportStatus == 'pending') {
      return [
        {'title': 'Order Created', 'completed': true},
        {'title': 'Awaiting Assignment', 'completed': false},
      ];
    } else if (transportStatus == 'in_transit') {
      return [
        {'title': 'Order Created', 'completed': true},
        {'title': 'Picked Up', 'completed': true},
        {'title': 'In Transit', 'completed': true},
        {'title': 'Out for Delivery', 'completed': false},
      ];
    } else if (transportStatus == 'delivered' || transportStatus == 'completed') {
      return [
        {'title': 'Order Created', 'completed': true},
        {'title': 'Picked Up', 'completed': true},
        {'title': 'In Transit', 'completed': true},
        {'title': 'Delivered', 'completed': true},
      ];
    }

    return [
      {'title': 'Order Created', 'completed': true},
      {'title': 'Processing', 'completed': false},
    ];
  }

  String _formatNumberWithCommas(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  Color _getTransportStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'in_transit':
      case 'delivery_scheduled':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTransportStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'in_transit':
        return 'In Transit';
      case 'delivery_scheduled':
        return 'Scheduled';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }
}
