import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';

class SwapOfferConfirmationScreen extends StatelessWidget {
  final Car targetCar;
  final String yourVehicleVIN;
  final double yourVehicleValue;
  final double additionalPayment;
  final String paymentType;
  /// Real offer (bid) ID from backend after submit; if null, fallback to display id.
  final String? offerId;

  const SwapOfferConfirmationScreen({
    super.key,
    required this.targetCar,
    required this.yourVehicleVIN,
    required this.yourVehicleValue,
    required this.additionalPayment,
    required this.paymentType,
    this.offerId,
  });

  String get _offerId => offerId != null ? 'SWP-$offerId' : 'AUC-SWP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Offer Submitted',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Offer Submitted',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
              const SizedBox(height: 12),
              
              // Confirmation Message
              Text(
                'Your Swap offer has been successfully submitted!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Offer ID
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  children: [
                    const TextSpan(text: 'Offer ID : '),
                    TextSpan(
                      text: _offerId,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Transaction Summary Card
              _buildTransactionSummaryCard(),
              const SizedBox(height: 24),
              
              // Next Steps Card
              _buildNextStepsCard(),
              const SizedBox(height: 32),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop back to ProductDetailsScreen (which will then pop to Home)
                    Navigator.pop(context, true);
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
                    'Back to Home',
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
      ),
    );
  }

  Widget _buildTransactionSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            'Target Value',
            '${targetCar.year} ${targetCar.make} ${targetCar.model}',
            '\$${targetCar.buyNowPrice.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'Your Vehicle Value',
            'VIN: ${yourVehicleVIN.length > 8 ? "${yourVehicleVIN.substring(0, 8)}..." : yourVehicleVIN}',
            '\$${yourVehicleValue.toStringAsFixed(0)}',
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Price:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '\$${targetCar.buyNowPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Vehicle:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '-\$${yourVehicleValue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Additional Payment (Cash):',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '\$${additionalPayment.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String subtitle, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kBlackColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
      ],
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Steps',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            '1',
            'Vehicle Verification',
            'Our team will verify the VIN and the value of your submitted vehicle. This may take up to 24 hours.',
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            '2',
            'Schedule Inspection',
            'After verification, we will call or email you to schedule an inspection appointment.',
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            '3',
            'Final Approval',
            'The deal will be finalized only after the inspection is passed and all paperwork is completed.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String stepNumber, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.orange[700],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

