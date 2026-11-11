import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class InvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> invoiceData;

  const InvoiceScreen({
    super.key,
    required this.invoiceData,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: Text(
          'Invoice #${widget.invoiceData['invoice_number'] ?? 'N/A'}',
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printInvoice(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareInvoice(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: ResponsiveHelper.safePadding(context, all: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              
              // Bill To and Invoice Details (Side by Side)
              _buildDetailsSection(),
              
              // Vehicle Information
              if (widget.invoiceData['vehicle_id'] != null) _buildVehicleInfo(),
              
              // Seller Information
              if (widget.invoiceData['seller_name'] != null && widget.invoiceData['seller_name'].toString().isNotEmpty) _buildSellerInfo(),
              
              // Amount Breakdown
              _buildAmountBreakdown(),
              
              // Payment Information
              if (widget.invoiceData['transaction_id'] != null) _buildPaymentInfo(),
              
              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.safePadding(context, all: 24),
      decoration: BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
          topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        ),
        border: Border(
          bottom: BorderSide(color: kAccentColor.withValues(alpha: 0.2), width: 2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'INVOICE',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 28),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2c3e50),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          Text(
            'Car Auction Platform',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
              color: const Color(0xFF2c3e50),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          Text(
            'Invoice #${widget.invoiceData['invoice_number'] ?? 'N/A'}',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: ResponsiveHelper.safePadding(context, all: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill To Section
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill To:',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2c3e50),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                if (widget.invoiceData['full_name'] != null && widget.invoiceData['full_name'].toString().isNotEmpty)
                  Text(
                    widget.invoiceData['full_name'],
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                if (widget.invoiceData['email'] != null && widget.invoiceData['email'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                    child: Text(
                      widget.invoiceData['email'],
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if (widget.invoiceData['phone'] != null && widget.invoiceData['phone'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                    child: Text(
                      widget.invoiceData['phone'],
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if (widget.invoiceData['address'] != null && widget.invoiceData['address'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                    child: Text(
                      widget.invoiceData['address'],
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          SizedBox(width: ResponsiveHelper.spacing(context, 16)),
          
          // Invoice Details Section
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Details:',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2c3e50),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                _buildDetailItem('Date', _formatDate(widget.invoiceData['created_at'])),
                _buildDetailItem('Due Date', _formatDate(widget.invoiceData['due_date'])),
                _buildDetailItem('Status', _buildStatusBadge(widget.invoiceData['payment_status'] ?? 'pending').toString()),
                _buildDetailItem('Paid Date', _formatDate(widget.invoiceData['paid_at'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 4)),
      child: Text(
        value,
        style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(context, 20)),
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle Information:',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2c3e50),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 10)),
          _buildInfoRow('Vehicle', '${widget.invoiceData['year']} ${widget.invoiceData['make']} ${widget.invoiceData['model']}'),
          _buildInfoRow('VIN', widget.invoiceData['vin']),
          _buildInfoRow('Mileage', '${NumberFormat.decimalPattern().format(widget.invoiceData['mileage'])} miles'),
          _buildInfoRow('Description', widget.invoiceData['description'] ?? 'Vehicle Purchase'),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(context, 20)),
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        border: Border.all(color: kAccentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller Information (pay seller directly if not using escrow)',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
              fontWeight: FontWeight.bold,
              color: kAccentColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 10)),
          _buildInfoRow('Name', widget.invoiceData['seller_name']),
          _buildInfoRow('Email', widget.invoiceData['seller_email']),
          _buildInfoRow('Phone', widget.invoiceData['seller_phone']),
          _buildInfoRow('Address', widget.invoiceData['seller_address']),
        ],
      ),
    );
  }

  Widget _buildAmountBreakdown() {
    final purchaseAmount = (widget.invoiceData['amount'] ?? 0.0).toDouble();
    final totalAmount = (widget.invoiceData['total_amount'] ?? 0.0).toDouble();
    final escrowFee = (widget.invoiceData['escrow_fee'] ?? 0.0).toDouble();
    final arbitrationFee = (widget.invoiceData['arbitration_fee'] ?? 0.0).toDouble();

    return Container(
      margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount Breakdown (wholesale — no retail sales tax):',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2c3e50),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          
          // Breakdown Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
            ),
            child: Column(
              children: [
                _buildBreakdownRow('Purchase Amount (vehicle)', purchaseAmount),
                _buildBreakdownRow('Escrow / platform fees (if applicable)', escrowFee),
                _buildBreakdownRow('Arbitration / other fees (if applicable)', arbitrationFee),
                _buildBreakdownRow('TOTAL AMOUNT', totalAmount, isTotal: true),
              ],
            ),
          ),
          
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          
          Text(
            'Wholesale transactions do not include state sales tax. Fees may include escrow, arbitration, or platform charges.',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(context, 20)),
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Information:',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2c3e50),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 10)),
          _buildInfoRow('Transaction ID', widget.invoiceData['transaction_id']),
          _buildInfoRow('Payment Method', widget.invoiceData['payment_method'] ?? 'Stripe'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveHelper.widthMultiplier(context) * 25,
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String description, double amount, {bool isTotal = false}) {
    return Container(
      padding: ResponsiveHelper.safePadding(context, horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTotal ? kAccentColor : (isTotal ? Colors.grey[100] : null),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: isTotal ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            '\$${NumberFormat.decimalPattern().format(amount)}',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'paid':
        badgeColor = Colors.green;
        textColor = Colors.white;
        break;
      case 'pending':
        badgeColor = Colors.orange;
        textColor = Colors.white;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        textColor = Colors.white;
        break;
      default:
        badgeColor = Colors.grey;
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.spacing(context, 8),
        vertical: ResponsiveHelper.spacing(context, 4),
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.safePadding(context, all: 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
          bottomRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Thank you for your business!',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          Text(
            'Car Auction Platform © ${DateTime.now().year}',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          Text(
            'For questions about this invoice, please contact support.',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  void _printInvoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print functionality coming soon!'),
        backgroundColor: kAccentColor,
      ),
    );
  }

  void _shareInvoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: kAccentColor,
      ),
    );
  }
}
