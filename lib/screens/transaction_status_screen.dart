import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/services/auction_transaction_service.dart';
import 'package:carauction/models/auction_transaction.dart';
import 'package:intl/intl.dart';

/// Screen to display the auction transaction workflow status
/// 
/// Shows the 10-step escrow process with visual indicators
class TransactionStatusScreen extends StatefulWidget {
  final String transactionId;
  final bool isBuyer;

  const TransactionStatusScreen({
    super.key,
    required this.transactionId,
    required this.isBuyer,
  });

  @override
  State<TransactionStatusScreen> createState() => _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen> {
  final AuctionTransactionService _transactionService = AuctionTransactionService();
  AuctionTransaction? _transaction;
  bool _isLoading = true;
  bool _isProcessing = false;
  StreamSubscription<AuctionTransaction>? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTransaction() async {
    try {
      final transaction = await _transactionService.getTransaction(widget.transactionId);
      if (mounted) {
        setState(() {
          _transaction = transaction;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transaction: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _subscribeToUpdates() {
    _transactionSubscription = _transactionService
        .subscribeToTransactionUpdates(widget.transactionId)
        .listen((transaction) {
      if (mounted) {
        setState(() {
          _transaction = transaction;
        });
      }
    });
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y h:mm a').format(date);
  }

  Future<void> _handleBuyerPayment() async {
    // Navigate to payment screen
    final result = await Navigator.pushNamed(
      context,
      '/payment',
      arguments: {
        'transaction_id': widget.transactionId,
        'amount': _transaction?.financials.totalAmount,
      },
    );
    if (result == true) {
      _loadTransaction();
    }
  }

  Future<void> _handleConfirmReceipt() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _transactionService.confirmVehicleReceipt(
        transactionId: widget.transactionId,
        vehicleAsDescribed: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle receipt confirmed!'), backgroundColor: Colors.green),
        );
        _loadTransaction();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleProvideShipping() async {
    // Show shipping info dialog
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const ShippingInfoDialog(),
    );

    if (result != null) {
      setState(() {
        _isProcessing = true;
      });

      try {
        await _transactionService.provideShippingInfo(
          transactionId: widget.transactionId,
          carrier: result['carrier']!,
          trackingNumber: result['tracking_number']!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shipping information updated!'), backgroundColor: Colors.green),
          );
          _loadTransaction();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      enableScroll: true,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        toolbarHeight: ResponsiveHelper.appBarHeight(context),
        title: Text(
          'Transaction Status',
          style: ResponsiveHelper.headingStyle(context).copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransaction,
          ),
        ],
      ),
      body: SafeContainer(
        padding: ResponsiveHelper.safePadding(context, all: 16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transaction == null
                ? const Center(child: Text('Transaction not found'))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Info Card
          _buildVehicleInfoCard(),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),

          // Financial Summary
          _buildFinancialSummary(),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),

          // Current Status
          _buildCurrentStatusCard(),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),

          // Action Buttons
          _buildActionButtons(),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),

          // Step-by-step Progress
          _buildStepProgress(),
          SizedBox(height: ResponsiveHelper.spacing(context, 20)),

          // Shipping Info (if available)
          if (_transaction?.shippingInfo != null) _buildShippingInfo(),

          // Transaction Details
          _buildTransactionDetails(),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoCard() {
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
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
          // Vehicle Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _transaction?.vehicleImageUrl != null
                ? Image.network(
                    _transaction!.vehicleImageUrl!,
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _transaction?.vehicleTitle ?? 'Vehicle',
                  style: ResponsiveHelper.bodyStyle(context).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  'Transaction #${_transaction!.id.substring(0, 8).toUpperCase()}',
                  style: ResponsiveHelper.bodyStyle(context).copyWith(
                    color: Colors.grey,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 60,
      color: Colors.grey[200],
      child: const Icon(Icons.directions_car, color: Colors.grey),
    );
  }

  Widget _buildFinancialSummary() {
    final financials = _transaction!.financials;
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(color: kAccentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: ResponsiveHelper.headingStyle(context).copyWith(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildFinancialRow('Vehicle Price', financials.vehiclePrice),
          if (financials.shippingCost != null)
            _buildFinancialRow('Shipping', financials.shippingCost!),
          if (financials.taxAmount != null)
            _buildFinancialRow('Tax', financials.taxAmount!),
          if (financials.otherFees != null)
            _buildFinancialRow('Other Fees', financials.otherFees!),
          const Divider(),
          _buildFinancialRow('Total Amount', financials.totalAmount, isBold: true),
          if (_transaction!.status.index >= TransactionStatus.platformFeeDeducted.index)
            _buildFinancialRow('Platform Fee', financials.platformFee, isNegative: true),
          if (_transaction!.status.index >= TransactionStatus.fundsReleasedToSeller.index)
            _buildFinancialRow('Seller Receives', financials.sellerReceives, isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, double amount, {bool isBold = false, bool isNegative = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: ResponsiveHelper.bodyStyle(context).copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}${_formatCurrency(amount)}',
            style: ResponsiveHelper.bodyStyle(context).copyWith(
              fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? Colors.red : (isHighlight ? Colors.green : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final status = _transaction!.status;
    final isCompleted = status == TransactionStatus.transactionComplete;
    final isInDispute = status == TransactionStatus.disputed;
    final isCancelled = status == TransactionStatus.cancelled;

    Color statusColor;
    IconData statusIcon;

    if (isCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isInDispute) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else if (isCancelled) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = kAccentColor;
      statusIcon = Icons.hourglass_top;
    }

    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 32),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.displayName,
                      style: ResponsiveHelper.headingStyle(context).copyWith(
                        color: statusColor,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      status.description,
                      style: ResponsiveHelper.bodyStyle(context).copyWith(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status.stepNumber != null) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            LinearProgressIndicator(
              value: status.stepNumber! / 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
            Text(
              'Step ${status.stepNumber} of 10',
              style: ResponsiveHelper.bodyStyle(context).copyWith(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _transaction!.status;
    final List<Widget> buttons = [];

    // Buyer actions
    if (widget.isBuyer) {
      if (status == TransactionStatus.invoiceGenerated) {
        buttons.add(_buildActionButton(
          'Pay Now',
          Icons.payment,
          _handleBuyerPayment,
          color: Colors.green,
        ));
      }
      if (status == TransactionStatus.sellerShipsVehicle || status == TransactionStatus.buyerConfirmsReceipt) {
        buttons.add(_buildActionButton(
          'Confirm Vehicle Receipt',
          Icons.check_circle,
          _handleConfirmReceipt,
          color: Colors.green,
        ));
      }
    }
    // Seller actions
    else {
      if (status == TransactionStatus.fundsHeldInEscrow) {
        buttons.add(_buildActionButton(
          'Provide Shipping Info',
          Icons.local_shipping,
          _handleProvideShipping,
          color: kAccentColor,
        ));
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actions Required',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        ...buttons,
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, {required Color color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : onPressed,
        icon: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Progress',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
        ...TransactionStatus.values
            .where((s) => s.isMainFlow)
            .map((status) => _buildStepItem(status)),
      ],
    );
  }

  Widget _buildStepItem(TransactionStatus stepStatus) {
    final currentStatus = _transaction!.status;
    final stepNumber = stepStatus.stepNumber!;
    final currentStep = currentStatus.stepNumber ?? 0;
    
    final bool isCompleted = stepNumber < currentStep;
    final bool isCurrent = stepNumber == currentStep;
    final bool isPending = stepNumber > currentStep;

    Color circleColor;
    IconData iconData;
    
    if (isCompleted) {
      circleColor = Colors.green;
      iconData = Icons.check;
    } else if (isCurrent) {
      circleColor = kAccentColor;
      iconData = Icons.circle;
    } else {
      circleColor = Colors.grey[300]!;
      iconData = Icons.circle_outlined;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and circle
          Column(
            children: [
              if (stepNumber > 1)
                Container(
                  width: 2,
                  height: 20,
                  color: isCompleted || isCurrent ? kAccentColor : Colors.grey[300],
                ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent ? circleColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: circleColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  iconData,
                  size: 16,
                  color: isCompleted || isCurrent ? Colors.white : Colors.grey,
                ),
              ),
              if (stepNumber < 10)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? kAccentColor : Colors.grey[300],
                  ),
                ),
            ],
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 12)),
          // Step content
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stepNumber}. ${stepStatus.displayName}',
                    style: ResponsiveHelper.bodyStyle(context).copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? kAccentColor : (isCompleted ? Colors.black : Colors.grey),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    stepStatus.description,
                    style: ResponsiveHelper.bodyStyle(context).copyWith(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingInfo() {
    final shipping = _transaction!.shippingInfo!;
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 20)),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: Colors.blue),
              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
              Text(
                'Shipping Information',
                style: ResponsiveHelper.headingStyle(context).copyWith(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          if (shipping.carrier != null)
            _buildInfoRow('Carrier', shipping.carrier!),
          if (shipping.trackingNumber != null)
            _buildInfoRow('Tracking #', shipping.trackingNumber!),
          if (shipping.estimatedDelivery != null)
            _buildInfoRow('Est. Delivery', _formatDate(shipping.estimatedDelivery!)),
          if (shipping.shippedAt != null)
            _buildInfoRow('Shipped On', _formatDate(shipping.shippedAt!)),
          if (shipping.deliveredAt != null)
            _buildInfoRow('Delivered On', _formatDate(shipping.deliveredAt!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: ResponsiveHelper.bodyStyle(context).copyWith(
                color: Colors.grey,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveHelper.bodyStyle(context).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails() {
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: ResponsiveHelper.headingStyle(context).copyWith(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildInfoRow('Transaction ID', _transaction!.id),
          _buildInfoRow('Auction ID', _transaction!.auctionId),
          _buildInfoRow('Buyer', _transaction!.buyerName ?? _transaction!.buyerId),
          _buildInfoRow('Seller', _transaction!.sellerName ?? _transaction!.sellerId),
          _buildInfoRow('Created', _formatDate(_transaction!.createdAt)),
          _buildInfoRow('Last Updated', _formatDate(_transaction!.updatedAt)),
          if (_transaction!.paymentProcessedAt != null)
            _buildInfoRow('Payment Processed', _formatDate(_transaction!.paymentProcessedAt!)),
          if (_transaction!.buyerConfirmedAt != null)
            _buildInfoRow('Buyer Confirmed', _formatDate(_transaction!.buyerConfirmedAt!)),
          if (_transaction!.escrowReleasedAt != null)
            _buildInfoRow('Funds Released', _formatDate(_transaction!.escrowReleasedAt!)),
        ],
      ),
    );
  }
}

/// Dialog for entering shipping information
class ShippingInfoDialog extends StatefulWidget {
  const ShippingInfoDialog({super.key});

  @override
  State<ShippingInfoDialog> createState() => _ShippingInfoDialogState();
}

class _ShippingInfoDialogState extends State<ShippingInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _carrierController = TextEditingController();
  final _trackingController = TextEditingController();

  @override
  void dispose() {
    _carrierController.dispose();
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Provide Shipping Information'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _carrierController,
              decoration: const InputDecoration(
                labelText: 'Carrier (e.g., FedEx, UPS)',
                hintText: 'Enter shipping carrier',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the carrier';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _trackingController,
              decoration: const InputDecoration(
                labelText: 'Tracking Number',
                hintText: 'Enter tracking number',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the tracking number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'carrier': _carrierController.text,
                'tracking_number': _trackingController.text,
              });
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
