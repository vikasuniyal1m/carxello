import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/screens/swap_offer_confirmation_screen.dart';
import 'package:carauction/services/swap_offer_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/nhtsa_service.dart';

class SwapPurchaseScreen extends StatefulWidget {
  final Car car;

  const SwapPurchaseScreen({
    super.key,
    required this.car,
  });

  @override
  State<SwapPurchaseScreen> createState() => _SwapPurchaseScreenState();
}

class _SwapPurchaseScreenState extends State<SwapPurchaseScreen> {
  final _vinController = TextEditingController();
  final _vehicleValueController = TextEditingController();
  final _additionalPaymentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String _paymentType = 'Add Cash'; // 'Add Cash' or 'Receive Cash'
  double _yourVehicleValue = 0;
  double _additionalPayment = 0;
  bool _isLoadingVehicleValue = false;
  bool _isVerifyingVin = false;
  final CarService _carService = CarService();
  final NHTSAService _nhtsaService = NHTSAService();

  @override
  void initState() {
    super.initState();
    _vehicleValueController.text = '0';
    _additionalPaymentController.text = '0';
  }

  @override
  void dispose() {
    _vinController.dispose();
    _vehicleValueController.dispose();
    _additionalPaymentController.dispose();
    super.dispose();
  }

  // Calculate total offer value (same logic as swap.php)
  double get _totalOfferValue {
    final yourValue = _yourVehicleValue;
    final additional = _additionalPayment;
    
    // Same calculation as swap.php: total_offer = swap_vehicle_value + additional_cash (if add)
    // or total_offer = swap_vehicle_value - additional_cash (if resolve)
    if (_paymentType == 'Add Cash') {
      return yourValue + additional;
    } else {
      final total = yourValue - additional;
      return total < 0 ? 0 : total;
    }
  }

  // Calculate balance (same logic as swap.php)
  double get _balance {
    final targetPrice = widget.car.buyNowPrice;
    return targetPrice - _totalOfferValue;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Vehicle Swap Purchase',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        toolbarHeight: ResponsiveHelper.appBarHeight(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveHelper.safeScrollable(
              context: context,
              child: Padding(
                padding: ResponsiveHelper.padding(
                  context,
                  all: isDesktop ? 24 : isTablet ? 20 : 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 800 : isTablet ? 700 : double.infinity,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTargetVehicleSection(),
                          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                          _buildYourVehicleVINSection(),
                          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                          _buildYourVehicleValueSection(),
                          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                          _buildAdditionalPaymentSection(),
                          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                          _buildTransactionSummary(),
                          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                          _buildSwapTerms(),
                          SizedBox(height: ResponsiveHelper.spacing(context, 32)),
                          // Extra space so content is not hidden behind sticky bar
                          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Sticky bottom bar: Submit Swap Offer always visible
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : isTablet ? 20 : 16,
              ResponsiveHelper.spacing(context, 12),
              isDesktop ? 24 : isTablet ? 20 : 16,
              ResponsiveHelper.spacing(context, 12) + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: kWhiteColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: _buildActionButtons(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetVehicleSection() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final imageSize = isDesktop ? 120.0 : isTablet ? 110.0 : 100.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Vehicle',
          style: ResponsiveHelper.subheadingStyle(
            context,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        Container(
          padding: ResponsiveHelper.padding(
            context,
            all: isDesktop ? 20 : isTablet ? 18 : 16,
          ),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(
              ResponsiveHelper.borderRadius(context, mobile: 12),
            ),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 8),
                ),
                child: Image.asset(
                  'assets/images/car1.png',
                  width: imageSize * ResponsiveHelper.scaleFactor(context),
                  height: imageSize * ResponsiveHelper.scaleFactor(context),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: imageSize * ResponsiveHelper.scaleFactor(context),
                      height: imageSize * ResponsiveHelper.scaleFactor(context),
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.directions_car,
                        size: ResponsiveHelper.iconSize(
                          context,
                          mobile: 50,
                          tablet: 55,
                          desktop: 60,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.car.year} ${widget.car.make} ${widget.car.model}',
                      style: ResponsiveHelper.bodyStyle(
                        context,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      'Price : \$${widget.car.buyNowPrice.toStringAsFixed(0)}',
                      style: ResponsiveHelper.captionStyle(
                        context,
                        color: Colors.grey,
                      ).copyWith(
                        fontSize: ResponsiveHelper.fontSize(
                          context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      'VIN : ${widget.car.vin ?? "N/A"}',
                      style: ResponsiveHelper.captionStyle(
                        context,
                        color: Colors.grey,
                      ).copyWith(
                        fontSize: ResponsiveHelper.fontSize(
                          context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
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

  Widget _buildYourVehicleVINSection() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Vehicle VIN',
          style: ResponsiveHelper.subheadingStyle(
            context,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
        isMobile
            ? Column(
                children: [
                  TextFormField(
                    controller: _vinController,
                    style: ResponsiveHelper.bodyStyle(context),
                    decoration: InputDecoration(
                      hintText: 'Enter 17-Character VIN',
                      hintStyle: ResponsiveHelper.captionStyle(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                        borderSide: const BorderSide(color: kAccentColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: ResponsiveHelper.padding(
                        context,
                        vertical: isDesktop ? 18 : isTablet ? 16 : 14,
                        horizontal: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter VIN number';
                      }
                      if (value.length != 17) {
                        return 'VIN must be 17 characters';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 17,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isVerifyingVin ? null : () => _verifyVinWithApi(),
                      style: TextButton.styleFrom(
                        padding: ResponsiveHelper.padding(
                          context,
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12),
                          ),
                        ),
                      ),
                      child: _isVerifyingVin
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                            )
                          : Text(
                              'Verify VIN Number',
                              style: ResponsiveHelper.bodyStyle(
                                context,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vinController,
                      style: ResponsiveHelper.bodyStyle(context),
                      decoration: InputDecoration(
                        hintText: 'Enter 17-Character VIN',
                        hintStyle: ResponsiveHelper.captionStyle(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12),
                          ),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12),
                          ),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12),
                          ),
                          borderSide: const BorderSide(color: kAccentColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: ResponsiveHelper.padding(
                          context,
                          vertical: isDesktop ? 18 : isTablet ? 16 : 14,
                          horizontal: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter VIN number';
                        }
                        if (value.length != 17) {
                          return 'VIN must be exactly 17 characters';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 17,
                      onChanged: (value) {
                        // Auto-fetch vehicle value when VIN is complete (same as swap.php)
                        if (value.length == 17) {
                          _fetchVehicleValue(value);
                        } else {
                          setState(() {
                            _yourVehicleValue = 0;
                            _vehicleValueController.text = '0';
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  TextButton(
                    onPressed: _isVerifyingVin ? null : () => _verifyVinWithApi(),
                    style: TextButton.styleFrom(
                      padding: ResponsiveHelper.padding(
                        context,
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                      ),
                    ),
                    child: _isVerifyingVin
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                          )
                        : Text(
                            'Verify VIN Number',
                            style: ResponsiveHelper.bodyStyle(
                              context,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildYourVehicleValueSection() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Vehicle Estimated Value',
          style: ResponsiveHelper.subheadingStyle(
            context,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
        TextFormField(
          controller: _vehicleValueController,
          keyboardType: TextInputType.number,
          style: ResponsiveHelper.bodyStyle(context),
          readOnly: _isLoadingVehicleValue,
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: ResponsiveHelper.bodyStyle(
              context,
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
            hintText: '0',
            hintStyle: ResponsiveHelper.captionStyle(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12),
              ),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12),
              ),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12),
              ),
              borderSide: const BorderSide(color: kAccentColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: ResponsiveHelper.padding(
              context,
              vertical: isDesktop ? 18 : isTablet ? 16 : 14,
              horizontal: 16,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _yourVehicleValue = double.tryParse(value) ?? 0;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty || (double.tryParse(value) ?? 0) <= 0) {
              return 'Please enter vehicle value';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
        if (_isLoadingVehicleValue)
          Padding(
            padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
            child: Text(
              'Calculating vehicle value...',
              style: ResponsiveHelper.captionStyle(context).copyWith(
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
            child: Container(
              padding: ResponsiveHelper.padding(context, all: 12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  Expanded(
                    child: Text(
                      'Vehicle value will be calculated automatically after entering VIN and will be verified upon inspection',
                      style: ResponsiveHelper.captionStyle(context).copyWith(
                        color: Colors.amber[900],
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdditionalPaymentSection() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Payment',
          style: ResponsiveHelper.subheadingStyle(
            context,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        
        // Radio buttons
        isMobile
            ? Column(
                children: [
                  RadioListTile<String>(
                    title: Text(
                      'Add Cash',
                      style: ResponsiveHelper.bodyStyle(context),
                    ),
                    value: 'Add Cash',
                    groupValue: _paymentType,
                    onChanged: (value) {
                      setState(() {
                        _paymentType = value!;
                      });
                    },
                    activeColor: kAccentColor,
                  ),
                  RadioListTile<String>(
                    title: Text(
                      'Receive Cash',
                      style: ResponsiveHelper.bodyStyle(context),
                    ),
                    value: 'Receive Cash',
                    groupValue: _paymentType,
                    onChanged: (value) {
                      setState(() {
                        _paymentType = value!;
                      });
                    },
                    activeColor: kAccentColor,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(
                        'Add Cash',
                        style: ResponsiveHelper.bodyStyle(context),
                      ),
                      value: 'Add Cash',
                      groupValue: _paymentType,
                      onChanged: (value) {
                        setState(() {
                          _paymentType = value!;
                        });
                      },
                      activeColor: kAccentColor,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(
                        'Receive Cash',
                        style: ResponsiveHelper.bodyStyle(context),
                      ),
                      value: 'Receive Cash',
                      groupValue: _paymentType,
                      onChanged: (value) {
                        setState(() {
                          _paymentType = value!;
                        });
                      },
                      activeColor: kAccentColor,
                    ),
                  ),
                ],
              ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
        
        // Payment input field
        TextFormField(
          controller: _additionalPaymentController,
          keyboardType: TextInputType.number,
          style: ResponsiveHelper.bodyStyle(context),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: ResponsiveHelper.bodyStyle(
              context,
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
            hintText: '0',
            hintStyle: ResponsiveHelper.captionStyle(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12),
              ),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12),
              ),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 12),
              ),
              borderSide: const BorderSide(color: kAccentColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: ResponsiveHelper.padding(
              context,
              vertical: isDesktop ? 18 : isTablet ? 16 : 14,
              horizontal: 16,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _additionalPayment = double.tryParse(value) ?? 0;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter amount';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isDesktop ? 20 : isTablet ? 18 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        border: Border.all(color: Colors.blue[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Summary',
            style: ResponsiveHelper.subheadingStyle(
              context,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          _buildSummaryRow('Target Vehicle Price', '\$${widget.car.buyNowPrice.toStringAsFixed(0)}'),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          _buildSummaryRow('Your Vehicle Value', '\$${_yourVehicleValue.toStringAsFixed(0)}'),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          _buildSummaryRow(
            _paymentType == 'Add Cash' ? 'Additional Payment:' : 'Cash Back:',
            '${_paymentType == 'Add Cash' ? '+' : '-'}\$${_additionalPayment.toStringAsFixed(0)}',
          ),
          Divider(height: ResponsiveHelper.spacing(context, 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Total Offer Value:',
                  style: ResponsiveHelper.subheadingStyle(
                    context,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              Text(
                '\$${_totalOfferValue.toStringAsFixed(0)}',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          Divider(height: ResponsiveHelper.spacing(context, 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Balance:',
                  style: ResponsiveHelper.subheadingStyle(
                    context,
                    color: _balance > 0 ? Colors.red[700] : _balance < 0 ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ),
              Text(
                _balance > 0
                    ? '\$${_balance.toStringAsFixed(0)} (You need to pay)'
                    : _balance < 0
                        ? '\$${_balance.abs().toStringAsFixed(0)} (You will receive)'
                        : '\$0 (Even swap)',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: _balance > 0 ? Colors.red[700] : _balance < 0 ? Colors.green[700] : Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          Container(
            padding: ResponsiveHelper.padding(context, all: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _balance > 0
                  ? 'Note: You need to pay \$${_balance.toStringAsFixed(0)} to complete this swap'
                  : _balance < 0
                      ? 'Note: You will receive \$${_balance.abs().toStringAsFixed(0)} back from this swap'
                      : 'Note: This is an even swap - no additional payment required',
              style: ResponsiveHelper.captionStyle(context).copyWith(
                color: Colors.grey[800],
                fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: ResponsiveHelper.bodyStyle(
              context,
              color: Colors.grey,
            ),
          ),
        ),
        Text(
          value,
          style: ResponsiveHelper.bodyStyle(
            context,
            fontWeight: FontWeight.w600,
            color: kBlackColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSwapTerms() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: isDesktop ? 20 : isTablet ? 18 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        border: Border.all(color: Colors.amber[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Swap Terms',
            style: ResponsiveHelper.subheadingStyle(
              context,
              color: kBlackColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          _buildTermItem('Vehicle Condition will be verified upon inspection'),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          _buildTermItem('Title must be clear and in your name'),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          _buildTermItem('Final value may be adjusted based on actual condition'),
          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          _buildTermItem('Both vehicle must pass inspection'),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    final dotSize = ResponsiveHelper.iconSize(
      context,
      mobile: 6,
      tablet: 7,
      desktop: 8,
    );
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            top: ResponsiveHelper.spacing(context, 6),
            right: ResponsiveHelper.spacing(context, 8),
          ),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: Colors.orange[700],
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: ResponsiveHelper.captionStyle(
              context,
              color: Colors.grey[800],
            ).copyWith(
              fontSize: ResponsiveHelper.fontSize(
                context,
                mobile: 14,
                tablet: 15,
                desktop: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final buttonHeight = ResponsiveHelper.buttonHeight(
      context,
      mobile: 50,
      tablet: 52,
      desktop: 54,
    );
    
    return isMobile
        ? Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _handleSubmitSwapOffer();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 12),
                      ),
                    ),
                  ),
                  child: Text(
                    'Submit Swap Offer',
                    style: ResponsiveHelper.bodyStyle(
                      context,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 12),
                      ),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: ResponsiveHelper.bodyStyle(
                      context,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: ResponsiveHelper.bodyStyle(
                        context,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _handleSubmitSwapOffer();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                      ),
                    ),
                    child: Text(
                      'Submit Swap Offer',
                      style: ResponsiveHelper.bodyStyle(
                        context,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  void _handleSubmitSwapOffer() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final swapOfferService = SwapOfferService();
      
      // Prepare swap offer data
      print('🔄 Creating swap offer...');
      print('   🚗 Target Vehicle ID: ${widget.car.id}');
      print('   📝 Buyer Vehicle VIN: ${_vinController.text}');
      print('   💰 Buyer Vehicle Value: $_yourVehicleValue');
      print('   💵 Additional Payment: $_additionalPayment');
      print('   💳 Payment Type: ${_paymentType == 'Add Cash' ? 'add' : 'resolve'}');
      
      // Call backend API to create swap offer
      final resultMap = await swapOfferService.createSwapOffer(
        vehicleId: widget.car.id,
        buyerVehicleVIN: _vinController.text.trim(),
        buyerVehicleValue: _yourVehicleValue,
        additionalPayment: _additionalPayment,
        paymentType: _paymentType == 'Add Cash' ? 'add' : 'resolve',
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      final offerIdFromApi = resultMap['swap_offer']?['id']?.toString();

      // Navigate to confirmation screen
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SwapOfferConfirmationScreen(
              targetCar: widget.car,
              yourVehicleVIN: _vinController.text,
              yourVehicleValue: _yourVehicleValue,
              additionalPayment: _additionalPayment,
              paymentType: _paymentType,
              offerId: offerIdFromApi,
            ),
          ),
        );
        // If user clicked "Back to Home" from confirmation screen, pop back to ProductDetailsScreen
        // The result will be true if user completed the flow
        if (mounted && result == true) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit swap offer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Verify VIN using same API as inspection (NHTSA decode-vin) – checks if VIN exists
  Future<void> _verifyVinWithApi() async {
    final vin = _vinController.text.trim();
    if (vin.length != 17) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 17-character VIN first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isVerifyingVin = true);

    try {
      final decoded = await _nhtsaService.decodeVin(vin);
      if (!mounted) return;
      setState(() => _isVerifyingVin = false);

      if (decoded != null && decoded.isNotEmpty) {
        final make = decoded['make'] ?? decoded['Make'] ?? '';
        final model = decoded['model'] ?? decoded['Model'] ?? '';
        final year = decoded['year'] ?? decoded['Model Year'] ?? '';
        final desc = [year, make, model].where((e) => e != null && e.toString().isNotEmpty).join(' ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              desc.isNotEmpty
                  ? 'VIN verified: $desc'
                  : 'VIN verified successfully',
              style: ResponsiveHelper.bodyStyle(context),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'VIN not found or invalid. Please check and try again.',
              style: ResponsiveHelper.bodyStyle(context),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingVin = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch vehicle value by VIN (same as swap.php getVehicleValue function)
  Future<void> _fetchVehicleValue(String vin) async {
    setState(() {
      _isLoadingVehicleValue = true;
    });

    try {
      final result = await _carService.getVehicleValueByVIN(vin);
      
      if (mounted) {
        final value = (result['value'] as num?)?.toDouble() ?? 0.0;
        
        setState(() {
          _yourVehicleValue = value;
          _vehicleValueController.text = value.toStringAsFixed(0);
          _isLoadingVehicleValue = false;
        });

        // Show message if vehicle not found
        if (result['vehicle_found'] == false && value == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] as String? ?? 'Vehicle not found. Please enter value manually.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (result['vehicle_found'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vehicle value found: \$${value.toStringAsFixed(0)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVehicleValue = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching vehicle value: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

