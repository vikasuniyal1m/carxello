import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/bid_service.dart';

class BuyNowScreen extends StatefulWidget {
  final Car car;

  const BuyNowScreen({
    super.key,
    required this.car,
  });

  @override
  State<BuyNowScreen> createState() => _BuyNowScreenState();
}

class _BuyNowScreenState extends State<BuyNowScreen> {
  int _currentStep = 0; // 0: Purchase Options, 1: Payment Details, 2: Review & Confirm
  bool _applyForFinancing = false;
  bool _waiveInspection = false;
  String _selectedPaymentMethod = 'Credit/Debit Card';
  bool _agreeToTerms = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Buy Now',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
          ),
        ),
        toolbarHeight: ResponsiveHelper.appBarHeight(context),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: ResponsiveHelper.safePadding(context, all: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Car Details Card
              _buildCarDetailsCard(),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),

              // Progress Indicator
              _buildProgressIndicator(),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),

              // Step Content
              _buildStepContent(),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarDetailsCard() {
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Car Image
          ClipRRect(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
            child: Image.asset(
              'assets/images/car1.png',
              width: ResponsiveHelper.widthMultiplier(context) * 18,
              height: ResponsiveHelper.widthMultiplier(context) * 18,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: ResponsiveHelper.widthMultiplier(context) * 18,
                  height: ResponsiveHelper.widthMultiplier(context) * 18,
                  color: Colors.grey[300],
                  child: Icon(Icons.directions_car, size: ResponsiveHelper.widthMultiplier(context) * 8),
                );
              },
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 12)),

          // Car Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.car.year} ${widget.car.make} ${widget.car.model}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                Text(
                  'VIN : ${widget.car.vin ?? "N/A"}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                Text(
                  '${widget.car.mileage} miles',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                Text(
                  '\$${widget.car.buyNowPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                    fontWeight: FontWeight.bold,
                    color: kAccentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = [
      'Purchase Options',
      'Payment Details',
      'Review & Confirm',
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: ResponsiveHelper.widthMultiplier(context) * 7,
                    height: ResponsiveHelper.widthMultiplier(context) * 7,
                    decoration: BoxDecoration(
                      color: isActive || isCompleted
                          ? kAccentColor
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(Icons.check, color: Colors.white, size: ResponsiveHelper.widthMultiplier(context) * 4)
                          : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive || isCompleted
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        ),
                      ),
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted
                            ? kAccentColor
                            : Colors.grey[300],
                        margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 4)),
              Text(
                steps[index],
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive || isCompleted
                      ? kAccentColor
                      : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPurchaseOptionsStep();
      case 1:
        return _buildPaymentDetailsStep();
      case 2:
        return _buildReviewConfirmStep();
      default:
        return _buildPurchaseOptionsStep();
    }
  }

  Widget _buildPurchaseOptionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase Options',
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),

        // Apply for Financing
        _buildOptionCard(
          title: 'Apply for Financing',
          description: 'Get pre-approved for auto financing with competitive rates',
          value: _applyForFinancing,
          onChanged: (value) {
            setState(() {
              _applyForFinancing = value;
            });
          },
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),

        // Waive Inspection Period
        _buildOptionCard(
          title: 'Waive Inspection Period',
          description: 'Purchase immediately without 24 hour inspection period',
          value: _waiveInspection,
          onChanged: (value) {
            setState(() {
              _waiveInspection = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            activeColor: kAccentColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),

        _buildPaymentMethodCard(
          icon: Icons.credit_card,
          title: 'Credit / Debit Card',
          isSelected: _selectedPaymentMethod == 'Credit/Debit Card',
          onTap: () {
            setState(() {
              _selectedPaymentMethod = 'Credit/Debit Card';
            });
          },
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),

        _buildPaymentMethodCard(
          icon: Icons.account_balance,
          title: 'Bank Transfer',
          isSelected: _selectedPaymentMethod == 'Bank Transfer',
          onTap: () {
            setState(() {
              _selectedPaymentMethod = 'Bank Transfer';
            });
          },
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),

        if (_applyForFinancing)
          _buildPaymentMethodCard(
            icon: Icons.euro,
            title: 'Financing (if approved)',
            isSelected: _selectedPaymentMethod == 'Financing',
            onTap: () {
              setState(() {
                _selectedPaymentMethod = 'Financing';
              });
            },
          ),

        SizedBox(height: ResponsiveHelper.spacing(context, 16)),

        // Price Breakdown
        _buildPriceBreakdown(),
      ],
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: ResponsiveHelper.safePadding(context, all: 12),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
          border: Border.all(
            color: isSelected ? kAccentColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Radio(
              value: title,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) => onTap(),
              activeColor: kAccentColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Icon(icon, size: ResponsiveHelper.widthMultiplier(context) * 5, color: isSelected ? kAccentColor : Colors.grey),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                  fontWeight: FontWeight.bold,
                  color: isSelected ? kAccentColor : kBlackColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    final buyNowPrice = widget.car.buyNowPrice;
    final totalValue = buyNowPrice; // Total = Buy Now price; fees/transport can be confirmed after seller approval
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 12),
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
        border: Border.all(color: kAccentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Breakdown',
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 6)),
          Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveHelper.spacing(context, 6), 
              horizontal: ResponsiveHelper.spacing(context, 8)
            ),
            decoration: BoxDecoration(
              color: kThemeColor2.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
              border: Border.all(color: kThemeColor2.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: ResponsiveHelper.widthMultiplier(context) * 4, color: kThemeColor2),
                SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                Expanded(
                  child: Text(
                    'Your offer will be sent to seller. The deal is complete only after seller accepts.',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11), 
                      color: kThemeColor2.withOpacity(0.8)
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildPriceRow('Buy Now Price', '\$${buyNowPrice.toStringAsFixed(0)}'),
          Divider(height: ResponsiveHelper.spacing(context, 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Offer Value:',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
              Text(
                '\$${totalValue.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                  fontWeight: FontWeight.bold,
                  color: kAccentColor,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildInfoRow('Payment Method:', _selectedPaymentMethod),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          _buildInfoRow('Financing:', _applyForFinancing ? 'Yes' : 'No'),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          _buildInfoRow('Inspection Waived:', _waiveInspection ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 13), 
          color: Colors.grey
        )),
        Text(value, style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 13), 
          fontWeight: FontWeight.w600
        )),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 12), 
          color: Colors.grey
        )),
        Text(value, style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 12), 
          fontWeight: FontWeight.w600
        )),
      ],
    );
  }

  Widget _buildReviewConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Your Purchase',
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        _buildPriceBreakdown(),
        SizedBox(height: ResponsiveHelper.spacing(context, 16)),

        // Terms and Conditions
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: (value) {
                setState(() {
                  _agreeToTerms = value ?? false;
                });
              },
              activeColor: kAccentColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.grey, 
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12)
                  ),
                  children: [
                    const TextSpan(text: 'I agree the '),
                    TextSpan(
                      text: 'terms and conditions',
                      style: const TextStyle(color: kAccentColor),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'User agreement and Privacy policy',
                      style: const TextStyle(color: kAccentColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_currentStep == 0) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.spacing(context, 14)
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8)
                  ),
                ),
              ),
              child: Text(
                'Continue to Payment',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.spacing(context, 14)
                ),
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8)
                  ),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.spacing(context, 14)
                ),
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8)
                  ),
                ),
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 2;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.spacing(context, 14)
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8)
                  ),
                ),
              ),
              child: Text(
                'Review',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.spacing(context, 14)
                ),
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8)
                  ),
                ),
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Expanded(
            child: ElevatedButton(
              onPressed: _agreeToTerms ? _handleConfirmPurchase : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.spacing(context, 14)
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8)
                  ),
                ),
              ),
              child: Text(
                'Submit',
                style: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _handleConfirmPurchase() async {
    if (!_agreeToTerms) {
      print('❌ ERROR: Please agree to terms and conditions');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please agree to terms and conditions to proceed', style: TextStyle(fontSize: 14)), // Added fontSize
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2), // Added strokeWidth
        ),
      );
    }

    try {
      print('🔄 Processing purchase for vehicle ${widget.car.id}...');
      final bidService = BidService();
      await bidService.buyNow(widget.car.id);

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        print('✅ Buy Now offer submitted successfully!');

        // Show success message (same as template: offer pending seller approval)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Buy Now offer sent. Waiting for seller approval.',
              style: TextStyle(fontSize: 13), // Pehle 14 tha
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigate back using SchedulerBinding to ensure proper timing
        // This prevents navigation issues when app is in background or during state changes
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // Small delay to ensure SnackBar is visible and parent screen is ready
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;

            try {
              // Navigate back with success result
              Navigator.pop(context, true);
              print('✅ Navigation completed successfully - returned to Product Details');
            } catch (e) {
              print('❌ Navigation error: $e');
              // Fallback: Try maybePop
              Navigator.maybePop(context, true).then((didPop) {
                if (didPop) {
                  print('✅ Navigation completed with maybePop');
                } else {
                  print('⚠️ maybePop returned false - navigator may not have history');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Purchase confirmed! Tap here to go back.', style: TextStyle(fontSize: 14)), // Added fontSize
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Go Back',
                          textColor: Colors.white,
                          onPressed: () {
                            if (mounted) {
                              Navigator.maybePop(context);
                            }
                          },
                        ),
                      ),
                    );
                  }
                }
              }).catchError((e2) {
                print('❌ maybePop error: $e2');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Purchase confirmed! Please use back button to return.', style: TextStyle(fontSize: 14)), // Added fontSize
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              });
            }
          });
        });
      }
// Line 409 ke around - _handleConfirmPurchase() method mein catch block dhundo

    } catch (e) {
      print('❌ BUY NOW ERROR: ${e.toString()}');

      // Close loading dialog if still open
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {
          // Dialog might already be closed
        }

        // ✅ FIXED: Better error message
        String errorMessage = 'Failed to process request';

        // Agar bid cancel wala error hai to friendly message do
        if (e.toString().contains('bid') || e.toString().contains('cancel')) {
          errorMessage = 'Your previous bid has been cancelled. You can place a new bid or try Buy Now again.';
        } else {
          errorMessage = 'Failed to confirm purchase: ${e.toString().split(':').last.trim()}';
        }

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontSize: 14)),
            backgroundColor: Colors.orange, // Orange color for better visibility
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}