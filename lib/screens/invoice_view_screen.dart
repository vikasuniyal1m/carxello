import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/services/invoice_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class InvoiceViewScreen extends StatefulWidget {
  final String invoiceId;
  final String invoiceNumber;
  final Map<String, dynamic>? invoiceData;

  const InvoiceViewScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceNumber,
    this.invoiceData,
  });

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  Map<String, dynamic>? _invoiceData;
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();

    if (widget.invoiceData != null) {
      _invoiceData = widget.invoiceData;
      setState(() {
        _isLoading = false;
      });
    } else {
      _loadInvoiceData();
    }
  }

  Future<void> _loadInvoiceData() async {
    try {
      final data = await _invoiceService.getInvoice(widget.invoiceId);
      setState(() {
        _invoiceData = data['invoice'] ?? data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadInvoice() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final filePath = await _invoiceService.downloadInvoice(
        widget.invoiceId,
        widget.invoiceNumber,
      );

      if (mounted) {
        final fileName = filePath.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
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
                        'Invoice Downloaded',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        fileName,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 4),
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
                      await openAppSettings();
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
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
        return Colors.green[700]!;
      case 'pending':
        return Colors.orange[700]!;
      case 'failed':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
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

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return SafeScaffold(
      backgroundColor: Colors.grey[100],
      enableScroll: false,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kWhiteColor),
        title: Text(
          'Invoice',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: kWhiteColor,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (!_isLoading && _invoiceData != null)
            IconButton(
              icon: Icon(
                Icons.download,
                color: kWhiteColor,
                size: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
              ),
              onPressed: _isDownloading ? null : _downloadInvoice,
              tooltip: 'Download Invoice',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
              ),
            )
          : _invoiceData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: ResponsiveHelper.fontSize(context, mobile: 64, tablet: 80, desktop: 96),
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      Text(
                        'Invoice not found',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: ResponsiveHelper.padding(
                    context,
                    all: isMobile ? 16 : isTablet ? 20 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Professional Invoice UI
                      _buildProfessionalInvoice(context, isMobile, isTablet),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      // Download Button Card
                      _buildDownloadButtonCard(context, isMobile, isTablet),
                    ],
                  ),
                ),
    );
  }


  Widget _buildDownloadButtonCard(BuildContext context, bool isMobile, bool isTablet) {
    return Container(
                      decoration: BoxDecoration(
                        color: kWhiteColor,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
                        boxShadow: [
                          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveHelper.padding(
          context,
          all: isMobile ? 16 : isTablet ? 20 : 24,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isDownloading ? null : _downloadInvoice,
                          icon: _isDownloading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.download,
                                  size: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                                ),
                          label: Text(
                            _isDownloading ? 'Downloading...' : 'Download Invoice PDF',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ResponsiveHelper.adaptiveButtonStyle(
                            context,
                            backgroundColor: Colors.green[700]!,
                            foregroundColor: Colors.white,
                          ).copyWith(
                            padding: MaterialStateProperty.all(
                              ResponsiveHelper.padding(
                                context,
                                vertical: isMobile ? 14 : 16,
                                horizontal: isMobile ? 20 : 24,
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
                    ),
    );
  }

  Widget _buildProfessionalInvoice(BuildContext context, bool isMobile, bool isTablet) {
    final invoiceNumber = _invoiceData?['invoice_number'] as String? ?? widget.invoiceNumber;
    final paymentStatus = _invoiceData?['payment_status'] as String? ?? _invoiceData?['status'] as String? ?? 'pending';
    final amount = (_invoiceData?['amount'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (_invoiceData?['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (_invoiceData?['total_amount'] as num?)?.toDouble() ?? amount + taxAmount;
    final description = _invoiceData?['description'] as String? ?? 'Service Payment';
    final createdAt = _invoiceData?['created_at'] as String?;
    final dueDate = _invoiceData?['due_date'] as String?;
    final paidAt = _invoiceData?['paid_at'] as String?;
    final vehicle = _invoiceData?['vehicle'] as Map<String, dynamic>?;
    final user = _invoiceData?['user'] as Map<String, dynamic>?;
    final transactionId = _invoiceData?['transaction_id'] as String?;
    final paymentMethod = _invoiceData?['payment_method'] as String?;
    final taxPercent = amount > 0 ? ((taxAmount / amount) * 100).toStringAsFixed(2) : '0.00';

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            padding: ResponsiveHelper.padding(
              context,
              all: isMobile ? 20 : isTablet ? 24 : 28,
            ),
            decoration: BoxDecoration(
              color: kAccentColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20),
                ),
                topRight: Radius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'INVOICE',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 28, tablet: 32, desktop: 36),
                    fontWeight: FontWeight.bold,
                    color: kWhiteColor,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'Car Auction Platform',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                    color: kWhiteColor.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                              color: kWhiteColor.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            invoiceNumber,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                              fontWeight: FontWeight.bold,
                              color: kWhiteColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: ResponsiveHelper.padding(
                        context,
                        horizontal: isMobile ? 12 : 14,
                        vertical: isMobile ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(paymentStatus).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 22, desktop: 24),
                        ),
                        border: Border.all(
                          color: _getStatusColor(paymentStatus),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        paymentStatus.toUpperCase(),
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(paymentStatus),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: ResponsiveHelper.padding(
              context,
              all: isMobile ? 20 : isTablet ? 24 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bill To & Invoice Details Row
                if (isMobile)
                  Column(
                    children: [
                      _buildInfoSection(
                        context,
                        'Bill To',
                        user,
                        isMobile,
                        isTablet,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                      _buildInvoiceDetailsSection(
                        context,
                        createdAt,
                        dueDate,
                        paidAt,
                        paymentStatus,
                        isMobile,
                        isTablet,
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInfoSection(
                          context,
                          'Bill To',
                          user,
                          isMobile,
                          isTablet,
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 24)),
                      Expanded(
                        child: _buildInvoiceDetailsSection(
                          context,
                          createdAt,
                          dueDate,
                          paidAt,
                          paymentStatus,
                          isMobile,
                          isTablet,
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: ResponsiveHelper.spacing(context, 24)),

                // Vehicle Information
                if (vehicle != null)
                  _buildVehicleSection(
                    context,
                    vehicle,
                    description,
                    isMobile,
                    isTablet,
                  ),

                SizedBox(height: ResponsiveHelper.spacing(context, 24)),

                // Amount Breakdown Table
                _buildAmountBreakdown(
                  context,
                  amount,
                  taxAmount,
                  taxPercent,
                  totalAmount,
                  isMobile,
                  isTablet,
                ),

                // Payment Information
                if (transactionId != null) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                  _buildPaymentInfoSection(
                    context,
                    transactionId,
                    paymentMethod,
                    isMobile,
                    isTablet,
                  ),
                ],

                SizedBox(height: ResponsiveHelper.spacing(context, 24)),

                // Footer
                _buildFooter(context, isMobile, isTablet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    Map<String, dynamic>? user,
    bool isMobile,
    bool isTablet,
  ) {
    final fullName = user?['full_name'] as String? ?? user?['name'] as String? ?? 'N/A';
    final email = user?['email'] as String? ?? '';
    final phone = user?['phone'] as String? ?? user?['phone_number'] as String? ?? '';
    final address = user?['address'] as String? ?? '';

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 16 : isTablet ? 18 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.bold,
              color: kAccentColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildInfoRow(context, fullName, isBold: true, isMobile: isMobile, isTablet: isTablet),
          if (email.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildInfoRow(context, 'Email: $email', isMobile: isMobile, isTablet: isTablet),
          ],
          if (phone.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildInfoRow(context, 'Phone: $phone', isMobile: isMobile, isTablet: isTablet),
          ],
          if (address.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildInfoRow(context, 'Address: $address', isMobile: isMobile, isTablet: isTablet),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String text, {
    bool isBold = false,
    required bool isMobile,
    required bool isTablet,
  }) {
    return Text(
      text,
      style: ResponsiveHelper.textStyle(
        context,
        fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: kBlackColor,
      ),
    );
  }

  Widget _buildInvoiceDetailsSection(
    BuildContext context,
    String? createdAt,
    String? dueDate,
    String? paidAt,
    String paymentStatus,
    bool isMobile,
    bool isTablet,
  ) {
    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 16 : isTablet ? 18 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Details',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.bold,
              color: kAccentColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildDetailRow(context, 'Date', _formatDate(createdAt), isMobile, isTablet),
          SizedBox(height: ResponsiveHelper.spacing(context, 6)),
          _buildDetailRow(context, 'Due Date', _formatDate(dueDate), isMobile, isTablet),
          SizedBox(height: ResponsiveHelper.spacing(context, 6)),
          _buildDetailRow(
            context,
            'Status',
            paymentStatus.toUpperCase(),
            isMobile,
            isTablet,
            valueColor: _getStatusColor(paymentStatus),
            isBold: true,
          ),
          if (paidAt != null) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildDetailRow(context, 'Paid Date', _formatDate(paidAt), isMobile, isTablet),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    bool isMobile,
    bool isTablet, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            '$label:',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? kBlackColor,
            ),
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSection(
    BuildContext context,
    Map<String, dynamic> vehicle,
    String description,
    bool isMobile,
    bool isTablet,
  ) {
    final vehicleName = '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    final vin = vehicle['vin'] as String?;
    final mileage = vehicle['mileage'] as num?;

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 16 : isTablet ? 18 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(
          color: Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle Information',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildDetailRow(context, 'Vehicle', vehicleName.isEmpty ? 'N/A' : vehicleName, isMobile, isTablet),
          if (vin != null && vin.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildDetailRow(context, 'VIN', vin, isMobile, isTablet),
          ],
          if (mileage != null && mileage > 0) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildDetailRow(
              context,
              'Mileage',
              '${NumberFormat('#,###').format(mileage)} miles',
              isMobile,
              isTablet,
            ),
          ],
          SizedBox(height: ResponsiveHelper.spacing(context, 6)),
          _buildDetailRow(context, 'Description', description, isMobile, isTablet),
        ],
      ),
    );
  }

  Widget _buildAmountBreakdown(
    BuildContext context,
    double amount,
    double taxAmount,
    String taxPercent,
    double totalAmount,
    bool isMobile,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Amount Breakdown',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(
              ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
            ),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: ResponsiveHelper.padding(
                  context,
                  all: isMobile ? 14 : isTablet ? 16 : 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                    ),
                    topRight: Radius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Description',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                          fontWeight: FontWeight.bold,
                          color: kWhiteColor,
                        ),
                      ),
                    ),
                    Text(
                      'Amount',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                        fontWeight: FontWeight.bold,
                        color: kWhiteColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Purchase Amount Row
              _buildTableRow(
                context,
                'Purchase Amount',
                _formatCurrency(amount),
                isMobile,
                isTablet,
                isEven: false,
              ),
              // Tax Row
              _buildTableRow(
                context,
                'Tax ($taxPercent%)',
                _formatCurrency(taxAmount),
                isMobile,
                isTablet,
                isEven: true,
              ),
              // Total Row
              Container(
                padding: ResponsiveHelper.padding(
                  context,
                  all: isMobile ? 16 : isTablet ? 18 : 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                    ),
                    bottomRight: Radius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL AMOUNT',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: kWhiteColor,
                      ),
                    ),
                    Text(
                      _formatCurrency(totalAmount),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: kWhiteColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(
    BuildContext context,
    String label,
    String value,
    bool isMobile,
    bool isTablet, {
    required bool isEven,
  }) {
    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 14 : isTablet ? 16 : 18,
      ),
      color: isEven ? Colors.grey[50] : kWhiteColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                color: kBlackColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Flexible(
            flex: 1,
            child: Text(
              value,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                fontWeight: FontWeight.w600,
                color: kBlackColor,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoSection(
    BuildContext context,
    String transactionId,
    String? paymentMethod,
    bool isMobile,
    bool isTablet,
  ) {
    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isMobile ? 16 : isTablet ? 18 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(
          color: Colors.green[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Information',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildDetailRow(
            context,
            'Transaction ID',
            transactionId,
            isMobile,
            isTablet,
          ),
          if (paymentMethod != null) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            _buildDetailRow(
              context,
              'Payment Method',
              paymentMethod,
              isMobile,
              isTablet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isMobile, bool isTablet) {
    return Container(
      padding: ResponsiveHelper.padding(
        context,
        vertical: isMobile ? 16 : isTablet ? 18 : 20,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Thank you for your business!',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          Text(
            'Car Auction Platform © ${DateTime.now().year}',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          Text(
            'For questions about this invoice, please contact support.',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
