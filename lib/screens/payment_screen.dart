import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String invoiceId;
  final double amount;

  const PaymentScreen({super.key, required this.invoiceId, required this.amount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();
  String _selectedPaymentMethod = 'stripe';
  final _paymentReferenceController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _paymentReferenceController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _paymentService.processPayment(
        invoiceId: widget.invoiceId,
        paymentMethod: _selectedPaymentMethod,
        paymentReference: _paymentReferenceController.text.isEmpty 
            ? null 
            : _paymentReferenceController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      enableScroll: true,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        toolbarHeight: ResponsiveHelper.appBarHeight(context),
        title: Text(
          'Payment',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: SafeContainer(
        padding: ResponsiveHelper.safePadding(
          context,
          all: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount Display
              Container(
                width: double.infinity,
                padding: ResponsiveHelper.safePadding(
                  context,
                  all: 20,
                ),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 12),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: ResponsiveHelper.bodyStyle(context).copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                    Text(
                      _formatCurrency(widget.amount),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 28, // textStyle will handle responsive scaling
                      ).copyWith(
                        fontWeight: FontWeight.bold,
                        color: kAccentColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              // Payment Method Selection
              Text(
                'Select Payment Method',
                style: ResponsiveHelper.headingStyle(context),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              _buildPaymentMethodOption(
                'stripe',
                'Credit/Debit Card',
                Icons.credit_card,
                'Pay securely with Stripe',
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 10)),
              _buildPaymentMethodOption(
                'paypal',
                'PayPal',
                Icons.paypal,
                'Pay with your PayPal account',
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 10)),
              _buildPaymentMethodOption(
                'bank_transfer',
                'Bank Transfer',
                Icons.account_balance,
                'Direct bank transfer',
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              // Payment Reference (optional)
              TextFormField(
                controller: _paymentReferenceController,
                decoration: InputDecoration(
                  labelText: 'Payment Reference (Optional)',
                  hintText: 'Transaction ID, Reference number, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 12),
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: ResponsiveHelper.bodyStyle(context),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ResponsiveHelper.adaptiveButtonStyle(context).copyWith(
                    backgroundColor: MaterialStateProperty.all(kAccentColor),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          height: ResponsiveHelper.iconSize(context, mobile: 20),
                          width: ResponsiveHelper.iconSize(context, mobile: 20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Pay ${_formatCurrency(widget.amount)}',
                          style: ResponsiveHelper.bodyStyle(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption(String value, String title, IconData icon, String subtitle) {
    final isSelected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: ResponsiveHelper.safePadding(
          context,
          all: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected ? kAccentColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 12),
          ),
          border: Border.all(
            color: isSelected ? kAccentColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? kAccentColor : Colors.grey,
              size: ResponsiveHelper.iconSize(context, mobile: 28),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: ResponsiveHelper.bodyStyle(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? kAccentColor : kBlackColor,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    subtitle,
                    style: ResponsiveHelper.bodyStyle(context).copyWith(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: kAccentColor,
                size: ResponsiveHelper.iconSize(context, mobile: 22),
              ),
          ],
        ),
      ),
    );
  }
}

