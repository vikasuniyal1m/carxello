import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/models/auction_transaction.dart';

class InvoiceScreen extends StatefulWidget {
  final AuctionTransaction transaction;
  final Map<String, dynamic>? additionalInvoiceData;

  const InvoiceScreen({
    super.key,
    required this.transaction,
    this.additionalInvoiceData,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late Map<String, dynamic> _invoiceData;
  
  @override
  void initState() {
    super.initState();
    _invoiceData = _mapTransactionToInvoiceData();
  }
  
  /// Map AuctionTransaction to invoice data format
  Map<String, dynamic> _mapTransactionToInvoiceData() {
    final transaction = widget.transaction;
    final financials = transaction.financials;
    
    return {
      'invoice_number': transaction.invoiceId ?? 'INV-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${transaction.id.substring(0, 3)}',
      'full_name': transaction.buyerName ?? 'Buyer',
      'email': widget.additionalInvoiceData?['email'] ?? '',
      'phone': widget.additionalInvoiceData?['phone'] ?? '',
      'address': widget.additionalInvoiceData?['address'] ?? '',
      'created_at': transaction.createdAt.toIso8601String(),
      'due_date': transaction.createdAt.add(const Duration(days: 7)).toIso8601String(),
      'payment_status': _getPaymentStatus(),
      'paid_at': transaction.paymentProcessedAt?.toIso8601String(),
      'seller_name': transaction.sellerName ?? 'Seller',
      'seller_email': widget.additionalInvoiceData?['seller_email'] ?? '',
      'seller_phone': widget.additionalInvoiceData?['seller_phone'] ?? '',
      'seller_address': widget.additionalInvoiceData?['seller_address'] ?? '',
      'vehicle_id': transaction.vehicleId,
      'year': widget.additionalInvoiceData?['year'] ?? '',
      'make': widget.additionalInvoiceData?['make'] ?? '',
      'model': widget.additionalInvoiceData?['model'] ?? '',
      'vin': widget.additionalInvoiceData?['vin'] ?? '',
      'mileage': widget.additionalInvoiceData?['mileage'] ?? 0,
      'description': transaction.vehicleTitle ?? 'Vehicle Purchase',
      'amount': financials.vehiclePrice,
      'total_amount': financials.totalAmount,
      'escrow_fee': financials.platformFee,
      'arbitration_fee': financials.otherFees ?? 0.0,
      'transaction_id': transaction.paymentReference ?? transaction.id,
      'payment_method': widget.additionalInvoiceData?['payment_method'] ?? 'Stripe',
    };
  }
  
  String _getPaymentStatus() {
    switch (widget.transaction.status) {
      case TransactionStatus.invoiceGenerated:
        return 'pending';
      case TransactionStatus.buyerPaymentProcessing:
        return 'processing';
      case TransactionStatus.fundsHeldInEscrow:
      case TransactionStatus.sellerShipsVehicle:
      case TransactionStatus.buyerConfirmsReceipt:
      case TransactionStatus.fundsReleasedToSeller:
      case TransactionStatus.platformFeeDeducted:
      case TransactionStatus.transactionComplete:
        return 'paid';
      case TransactionStatus.cancelled:
        return 'cancelled';
      case TransactionStatus.disputed:
        return 'disputed';
      default:
        return 'pending';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: Text(
          'Invoice #${_invoiceData['invoice_number'] ?? 'N/A'}',
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
              
              // Bill To and Invoice Details
              _buildDetailsSection(),
              
              // Vehicle Information
              if (_invoiceData['vehicle_id'] != null) _buildVehicleInfo(),
              
              // Seller Information
              if (_invoiceData['seller_name'] != null) _buildSellerInfo(),
              
              // Amount Breakdown
              _buildAmountBreakdown(),
              
              // Payment Information
              if (_invoiceData['transaction_id'] != null) _buildPaymentInfo(),
              
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
            'Invoice #${_invoiceData['invoice_number'] ?? 'INV-20240315-001'}',
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
                if (_invoiceData['full_name'] != null && _invoiceData['full_name'].toString().isNotEmpty)
                  Text(
                    _invoiceData['full_name'],
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                if (_invoiceData['email'] != null && _invoiceData['email'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                    child: Text(
                      _invoiceData['email'],
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if (_invoiceData['phone'] != null && _invoiceData['phone'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                    child: Text(
                      _invoiceData['phone'],
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if (_invoiceData['address'] != null && _invoiceData['address'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                    child: Text(
                      _invoiceData['address'],
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
                _buildDetailItem('Date', _formatDate(_invoiceData['created_at'])),
                _buildDetailItem('Due Date', _formatDate(_invoiceData['due_date'])),
                _buildDetailItem('Status', _buildStatusBadge(_invoiceData['payment_status'] ?? 'pending').toString()),
                _buildDetailItem('Paid Date', _formatDate(_invoiceData['paid_at'])),
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

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'paid':
        badgeColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'pending':
        badgeColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case 'cancelled':
        badgeColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        badgeColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
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

  Widget _buildVehicleInfo() {
    // Only show vehicle info if vehicle data exists
    final hasVehicleData = _invoiceData['vehicle_id'] != null;
    
    if (!hasVehicleData) return const SizedBox.shrink();
    
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
          if (_invoiceData['year'] != null || _invoiceData['make'] != null || _invoiceData['model'] != null)
            _buildInfoRow('Vehicle', '${_invoiceData['year'] ?? ''} ${_invoiceData['make'] ?? ''} ${_invoiceData['model'] ?? ''}'.trim()),
          if (_invoiceData['vin'] != null && _invoiceData['vin'].toString().isNotEmpty)
            _buildInfoRow('VIN', _invoiceData['vin']),
          if (_invoiceData['mileage'] != null && _invoiceData['mileage'] != 0)
            _buildInfoRow('Mileage', '${NumberFormat.decimalPattern().format(_invoiceData['mileage'])} miles'),
          if (_invoiceData['description'] != null && _invoiceData['description'].toString().isNotEmpty)
            _buildInfoRow('Description', _invoiceData['description']),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    // Only show seller info if seller data exists
    final hasSellerData = (_invoiceData['seller_name'] != null && _invoiceData['seller_name'].toString().isNotEmpty) ||
                        (_invoiceData['seller_email'] != null && _invoiceData['seller_email'].toString().isNotEmpty);
    
    if (!hasSellerData) return const SizedBox.shrink();
    
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
          if (_invoiceData['seller_name'] != null && _invoiceData['seller_name'].toString().isNotEmpty)
            Text(
              _invoiceData['seller_name'],
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          if (_invoiceData['seller_email'] != null && _invoiceData['seller_email'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
              child: Text(
                _invoiceData['seller_email'],
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                  color: Colors.black87,
                ),
              ),
            ),
          if (_invoiceData['seller_phone'] != null && _invoiceData['seller_phone'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
              child: Text(
                _invoiceData['seller_phone'],
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                  color: Colors.black87,
                ),
              ),
            ),
          if (_invoiceData['seller_address'] != null && _invoiceData['seller_address'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
              child: Text(
                _invoiceData['seller_address'],
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountBreakdown() {
    final purchaseAmount = (_invoiceData['amount'] ?? 0.0).toDouble();
    final totalAmount = (_invoiceData['total_amount'] ?? 0.0).toDouble();
    final escrowFee = (_invoiceData['escrow_fee'] ?? 0.0).toDouble();
    final arbitrationFee = (_invoiceData['arbitration_fee'] ?? 0.0).toDouble();

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

  Widget _buildBreakdownRow(String description, double amount, {bool isHeader = false, bool isTotal = false}) {
    return Container(
      padding: ResponsiveHelper.safePadding(context, horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTotal ? kAccentColor : (isHeader ? Colors.grey[100] : null),
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

  Widget _buildPaymentInfo() {
    // Only show payment info if transaction data exists
    final hasPaymentData = _invoiceData['transaction_id'] != null && _invoiceData['transaction_id'].toString().isNotEmpty;
    
    if (!hasPaymentData) return const SizedBox.shrink();
    
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
          _buildInfoRow('Transaction ID', _invoiceData['transaction_id']),
          _buildInfoRow('Payment Method', _invoiceData['payment_method'] ?? 'Stripe'),
        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
    // TODO: Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print functionality coming soon!'),
        backgroundColor: kAccentColor,
      ),
    );
  }

  void _shareInvoice() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: kAccentColor,
      ),
    );
  }
}
