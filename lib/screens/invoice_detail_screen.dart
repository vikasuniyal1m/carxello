import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/services/invoice_service.dart';
import 'package:carauction/services/payment_service.dart';
import 'package:carauction/screens/payment_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  Map<String, dynamic>? _invoice;
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _invoiceService.getInvoice(widget.invoiceId);
      setState(() {
        _invoice = data['invoice'];
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

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _downloadInvoice() async {
    if (_invoice == null) return;

    setState(() => _isDownloading = true);

    try {
      final invoiceNumber = _invoice!['invoice_number'] as String;
      final filePath = await _invoiceService.downloadInvoice(widget.invoiceId, invoiceNumber);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Invoice downloaded to: $filePath'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to download: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: Text(
          'Invoice Details',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? const Center(child: Text('Invoice not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Invoice Number',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _invoice!['invoice_number'] as String,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: kBlackColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(_invoice!['status'] as String).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (_invoice!['status'] as String).toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(_invoice!['status'] as String),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Date: ${DateTime.parse(_invoice!['created_at'] as String).toString().split('T')[0]}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Vehicle Details
                      const Text(
                        'Vehicle Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        'Vehicle',
                        '${_invoice!['vehicle']['year']} ${_invoice!['vehicle']['make']} ${_invoice!['vehicle']['model']}',
                      ),
                      _buildDetailCard(
                        'VIN',
                        _invoice!['vehicle']['vin'] ?? 'N/A',
                      ),
                      const SizedBox(height: 24),
                      // Amount Breakdown
                      const Text(
                        'Amount Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        'Subtotal',
                        _formatCurrency((_invoice!['amount'] as num).toDouble()),
                      ),
                      _buildDetailCard(
                        'Tax',
                        _formatCurrency((_invoice!['tax'] as num).toDouble()),
                      ),
                      const Divider(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kBlackColor,
                              ),
                            ),
                            Text(
                              _formatCurrency((_invoice!['total_amount'] as num).toDouble()),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kAccentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_invoice!['due_date'] != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          'Due Date',
                          DateTime.parse(_invoice!['due_date'] as String).toString().split(' ')[0],
                        ),
                      ],
                      if (_invoice!['paid_date'] != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          'Paid Date',
                          DateTime.parse(_invoice!['paid_date'] as String).toString().split(' ')[0],
                        ),
                      ],
                      if (_invoice!['payment_method'] != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          'Payment Method',
                          _invoice!['payment_method'] as String,
                        ),
                      ],
                      if (_invoice!['payment_reference'] != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          'Payment Reference',
                          _invoice!['payment_reference'] as String,
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Download Invoice Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isDownloading ? null : () async {
                            await _downloadInvoice();
                          },
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download),
                          label: Text(_isDownloading ? 'Downloading...' : 'Download Invoice (PDF)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kAccentColor,
                            side: BorderSide(color: kAccentColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Payment Button
                      if (_invoice!['status'] == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentScreen(
                                    invoiceId: widget.invoiceId,
                                    amount: (_invoice!['total_amount'] as num).toDouble(),
                                  ),
                                ),
                              ).then((_) => _loadInvoice());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
          ),
        ],
      ),
    );
  }
}

