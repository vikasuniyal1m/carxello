import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/services/shipping_address_service.dart';
import 'package:carauction/screens/transport_tracking_screen.dart';
import 'package:carauction/screens/billing_history_screen.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleShippingScreen extends StatefulWidget {
  final Car car;

  const VehicleShippingScreen({
    super.key,
    required this.car,
  });

  @override
  State<VehicleShippingScreen> createState() => _VehicleShippingScreenState();
}

class _VehicleShippingScreenState extends State<VehicleShippingScreen> {
  String _selectedShippingOption = 'Expedited Delivery';
  String _selectedDeliveryOption = 'Door-to-Door';
  String _selectedInsurance = 'Standard Coverage';
  bool _rushDelivery = false;
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _deliveryZipController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  bool _costManuallyEdited = false;
  final TextEditingController _pickupFieldController = TextEditingController();
  final TextEditingController _deliveryFieldController = TextEditingController();
  List<Map<String, dynamic>> _transporters = [];
  bool _isLoadingTransporters = false;
  String? _transporterError;
  String? _selectedTransporterId;
  DateTime? _userPickupDate;
  DateTime? _userDeliveryDate;

  // Location data from vehicle
  String get _pickupLocation => widget.car.location;
  String get _pickupZip => widget.car.location.split(',').length > 1 ? widget.car.location.split(',')[1].trim() : '';
  final TextEditingController _deliveryLocationController = TextEditingController();
  final TextEditingController _deliveryCityController = TextEditingController();
  final TextEditingController _deliveryStateController = TextEditingController();
  final double _distance = 15.0; // miles (can be calculated from actual locations)

  final TransportService _transportService = TransportService();
  final ShippingAddressService _shippingAddressService = ShippingAddressService();
  bool _isScheduling = false;
  bool _isScheduled = false;
  bool _isCheckingStatus = true; // Loading state for status check
  Map<String, dynamic>? _transportStatus;
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoadingAddresses = false;
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    _checkTransportStatus();
    _loadSavedAddresses();
    _loadTransporters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncCostField();
      }
    });
    _pickupFieldController.text = 'dd-mm-yyyy --:--';
    _deliveryFieldController.text = 'dd-mm-yyyy --:--';
  }

  @override
  void dispose() {
    _deliveryLocationController.dispose();
    _deliveryCityController.dispose();
    _deliveryStateController.dispose();
    _instructionsController.dispose();
    _deliveryZipController.dispose();
    _costController.dispose();
    _pickupFieldController.dispose();
    _deliveryFieldController.dispose();
    super.dispose();
  }

  Future<void> _checkTransportStatus() async {
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      print('🔍 Checking transport status for vehicle: ${widget.car.id}');
      final status = await _transportService.getTransportOrder(widget.car.id);
      print('✅ Transport status received: ${status.toString()}');

      if (mounted) {
        setState(() {
          // Check if transport order exists (if order object exists, it's scheduled)
          // PHP file checks: SELECT id FROM transport_orders WHERE vehicle_id = ? AND buyer_id = ?
          // If order exists, transport is already scheduled
          final order = status['order'];

          // If order exists (not null), transport is scheduled
          // Order exists means: transport_orders table has a row for this vehicle_id and buyer_id
          _isScheduled = order != null && order['id'] != null;

          print('📊 Transport scheduled: $_isScheduled');
          if (_isScheduled && order != null) {
            print('📊 Order ID: ${order['id']}');
            print('📊 Order status: ${order['status'] ?? order['transport_status'] ?? 'pending'}');
            print('📊 Delivery address: ${order['delivery_address'] ?? order['delivery_location'] ?? 'N/A'}');
            print('📊 Pickup address: ${order['pickup_address'] ?? order['pickup_location'] ?? 'N/A'}');

            // Pre-fill delivery location if available
            _deliveryLocationController.text = order['delivery_address'] ??
                order['delivery_location'] ?? '';
          } else {
            print('📊 No transport order found - showing scheduling form');
          }

          _transportStatus = status;
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      // Order might not exist yet, which is fine
      print('⚠️ Transport order not found (this is normal if not scheduled yet): $e');
      if (mounted) {
        setState(() {
          _isScheduled = false;
          _transportStatus = null;
          _isCheckingStatus = false;
        });
      }
    }
  }

  Future<void> _loadSavedAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final addresses = await _shippingAddressService.getShippingAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = addresses;
          // Pre-fill with default address if available
          final defaultAddress = addresses.firstWhere(
                (addr) => addr['is_default'] == true,
            orElse: () => addresses.isNotEmpty ? addresses.first : {},
          );
          if (defaultAddress.isNotEmpty && !_isScheduled) {
            _deliveryLocationController.text = defaultAddress['address'] ?? '';
            _deliveryCityController.text = defaultAddress['city'] ?? '';
            _deliveryStateController.text = defaultAddress['state'] ?? '';
          }
        });
      }
    } catch (e) {
      print('⚠️ Error loading saved addresses: $e');
      // Continue with manual entry
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _saveAddress() async {
    if (_deliveryLocationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter delivery address', style: TextStyle(fontSize: 13)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _shippingAddressService.saveShippingAddress(
        address: _deliveryLocationController.text,
        city: _deliveryCityController.text.isNotEmpty ? _deliveryCityController.text : null,
        state: _deliveryStateController.text.isNotEmpty ? _deliveryStateController.text : null,
        zipCode: null,
        country: 'USA',
        isDefault: _savedAddresses.isEmpty, // Make first address default
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address saved successfully', style: TextStyle(fontSize: 13)),
            backgroundColor: Colors.green,
          ),
        );
        await _loadSavedAddresses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save address: ${e.toString()}', style: TextStyle(fontSize: 13)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, Map<String, dynamic>> get _shippingOptions => {
    'Economy Transport': {
      'price': 18.0,
      'pricePerMile': 1.20,
      'rating': 4.2,
      'carrier': 'Auto Ship Express',
      'days': '7-14 business days',
      'type': 'Open carrier',
      'features': ['GPS tracking', 'Insurance Included'],
    },
    'Standard Transport': {
      'price': 23.0,
      'pricePerMile': 1.53,
      'rating': 4.2,
      'carrier': 'Reliable Auto Transport',
      'days': '5-10 business days',
      'type': 'Open carrier',
      'features': ['GPS tracking', 'Insurance Included', 'Priority scheduling'],
    },
    'Premium Enclosed': {
      'price': 33.0,
      'pricePerMile': 2.20,
      'rating': 4.8,
      'carrier': 'Elite Car Carriers',
      'days': '3-7 business days',
      'type': 'Enclosed carrier',
      'features': ['GPS tracking', 'White glove Service', 'Premium insurance'],
    },
    'Expedited Delivery': {
      'price': 45.0,
      'pricePerMile': 3.00,
      'rating': 4.6,
      'carrier': 'Rush Auto Transport',
      'days': '1-3 business days',
      'type': 'Priority transport',
      'features': ['Express service', 'Dedicated Carrier', 'Real-time updates', 'Premium insurance'],
    },
  };

  Map<String, double> get _insuranceOptions => {
    'Standard Coverage': 0.0, // Up to $100,000 (Included)
    'Premium Coverage': 150.0, // Up to $250,000
    'Comprehensive Coverage': 300.0, // Up to $500,000
  };

  double get _baseShippingCost {
    return _shippingOptions[_selectedShippingOption]!['price']!;
  }

  double get _totalCost {
    double total = _baseShippingCost;

    // Add delivery option discount
    if (_selectedDeliveryOption == 'Terminal-to-Terminal') {
      total = total * 0.85; // 15% discount
    }

    // Add insurance
    total += _insuranceOptions[_selectedInsurance]!;

    // Add rush delivery surcharge
    if (_rushDelivery) {
      total = total * 1.5; // 50% surcharge
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking status
    if (_isCheckingStatus) {
      return SafeScaffold(
        backgroundColor: kWhiteColor,
        appBar: AppBar(
          backgroundColor: kAccentColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'Vehicle Shipping',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          toolbarHeight: 56,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'Checking transport status...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // If transport is already scheduled, show tracking screen directly
    // But only if we're not currently scheduling (to avoid black screen during navigation)
    if (_isScheduled && _transportStatus != null && !_isScheduling) {
      print('✅ Showing TransportTrackingScreen - transport is scheduled');
      return TransportTrackingScreen(
        vehicleId: widget.car.id,
      );
    }

    print('📝 Showing scheduling form - transport not scheduled yet');
    return SafeScaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Vehicle Shipping',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        toolbarHeight: 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule Vehicle Transport',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kBlackColor,
                ),
              ),
              const SizedBox(height: 6),

              // Show transport status card if scheduled
              if (_isScheduled && _transportStatus != null) ...[
                _buildTransportStatusCard(),
                const SizedBox(height: 20),
              ],

              // Location Details (old app UI - now removed to match website)

              // Only show form fields if NOT scheduled
              if (!_isScheduled) ...[
                _buildTransportProcess(),
                const SizedBox(height: 8),
                _buildTransporterSelection(),
                const SizedBox(height: 8),
                _buildDatePickers(),
                const SizedBox(height: 8),
                _buildDeliveryAddressSection(),
                const SizedBox(height: 8),
                _buildAdditionalDetails(),
                const SizedBox(height: 10),
                _buildActionButtons(),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue[700], size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pickup Location',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    _pickupLocation,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kBlackColor,
                    ),
                  ),
                  if (_pickupZip.isNotEmpty)
                    Text(
                      'ZIP: $_pickupZip',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.location_on, color: Colors.green[700], size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  if (_isScheduled && _transportStatus != null) ...[
                    Text(
                      _transportStatus!['order']?['delivery_address'] ??
                          _transportStatus!['order']?['delivery_location'] ?? 'Not set',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kBlackColor,
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _deliveryLocationController,
                      enabled: !_isScheduled,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        hintText: 'Enter delivery address',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kBlackColor,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (!_isScheduled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _deliveryCityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _deliveryStateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ]
                  else if (_transportStatus != null) ...[
                    Text(
                      'Status: ${_transportStatus!['order']?['transport_status'] ?? 'pending'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _getStatusColor(_transportStatus!['order']?['transport_status'] ?? 'pending'),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requested by: ${_formatRequestedBy(_transportStatus!['order']?['requested_by'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.straighten, color: Colors.blue[700], size: 18),
              const SizedBox(width: 6),
              Text(
                'Estimated distance: $_distance miles',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShippingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Shipping Option',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 12),
        ..._shippingOptions.keys.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildShippingOptionCard(option),
          );
        }),
      ],
    );
  }

  Widget _buildShippingOptionCard(String optionName) {
    final option = _shippingOptions[optionName]!;
    final isSelected = _selectedShippingOption == optionName;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedShippingOption = optionName;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : kWhiteColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio(
              value: optionName,
              groupValue: _selectedShippingOption,
              onChanged: (value) {
                setState(() {
                  _selectedShippingOption = value!;
                });
                _syncCostField();
              },
              activeColor: kAccentColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          optionName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue[700] : kBlackColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                Icons.star,
                                size: 14,
                                color: index < option['rating'].floor()
                                    ? Colors.amber
                                    : Colors.grey[300],
                              );
                            }),
                            const SizedBox(width: 2),
                            Text(
                              '${option['rating']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${option['price']} (\$${option['pricePerMile']}/mile)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${option['type']}, ${option['days']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option['carrier'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kBlackColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: (option['features'] as List).map((feature) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 8),
        RadioListTile<String>(
          title: const Text('Door-to-Door', style: TextStyle(fontSize: 15)),
          subtitle: const Text('Pickup and Delivery at specified addresses', style: TextStyle(fontSize: 13)),
          value: 'Door-to-Door',
          groupValue: _selectedDeliveryOption,
          onChanged: (value) {
            setState(() {
              _selectedDeliveryOption = value!;
            });
            _syncCostField();
          },
          activeColor: kAccentColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        RadioListTile<String>(
          title: const Text('Terminal-to-Terminal', style: TextStyle(fontSize: 15)),
          subtitle: const Text('Drop off and pick up at carrier terminals (15% discount)', style: TextStyle(fontSize: 13)),
          value: 'Terminal-to-Terminal',
          groupValue: _selectedDeliveryOption,
          onChanged: (value) {
            setState(() {
              _selectedDeliveryOption = value!;
            });
          },
          activeColor: kAccentColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildInsuranceCoverage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Insurance Coverage',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 8),
        ..._insuranceOptions.keys.map((coverage) {
          final additionalCost = _insuranceOptions[coverage]!;
          return RadioListTile<String>(
            title: Text(coverage, style: const TextStyle(fontSize: 15)),
            subtitle: Text(
              additionalCost == 0
                  ? 'Up to \$100,000 (Included)'
                  : additionalCost == 150
                  ? 'Up to \$250,000 (+\$${additionalCost.toStringAsFixed(0)})'
                  : 'Up to \$500,000 (+\$${additionalCost.toStringAsFixed(0)})',
              style: const TextStyle(fontSize: 13),
            ),
            value: coverage,
            groupValue: _selectedInsurance,
            onChanged: (value) {
              setState(() {
                _selectedInsurance = value!;
              });
              _syncCostField();
            },
            activeColor: kAccentColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
      ],
    );
  }

  Widget _buildRushDeliveryOption() {
    return CheckboxListTile(
      title: const Text('Rush Delivery', style: TextStyle(fontSize: 15)),
      subtitle: const Text('(+50% surcharge)', style: TextStyle(fontSize: 13)),
      value: _rushDelivery,
      onChanged: (value) {
        setState(() {
          _rushDelivery = value ?? false;
        });
        _syncCostField();
      },
      activeColor: kAccentColor,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Base shipping cost:',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              Text(
                '\$${_baseShippingCost.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (_selectedDeliveryOption == 'Terminal-to-Terminal') ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Terminal discount (15%):',
                  style: TextStyle(fontSize: 13, color: Colors.green),
                ),
                Text(
                  '-\$${(_baseShippingCost * 0.15).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (_insuranceOptions[_selectedInsurance]! > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedInsurance}:',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  '+\$${_insuranceOptions[_selectedInsurance]!.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (_rushDelivery) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rush Delivery (50%):',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  '+\$${(_totalCost - (_baseShippingCost + _insuranceOptions[_selectedInsurance]!)).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlackColor),
              ),
              Text(
                '\$${_totalCost.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kAccentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kBlackColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _isScheduled
              ? ElevatedButton.icon(
            onPressed: () {
              // Navigate to transport tracking screen to view status
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransportTrackingScreen(
                    vehicleId: widget.car.id,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('View Transport Status', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
              : ElevatedButton(
            onPressed: _isScheduling ? null : _handleBookShipping,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD2A231),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isScheduling
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
                : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.local_shipping, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'SCHEDULE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleBookShipping() async {
    final startTime = DateTime.now();
    print('🚚 ========================================');
    print('🚚 SCHEDULE TRANSPORT BUTTON CLICKED');
    print('🚚 ========================================');
    print('🚚 Timestamp: ${startTime.toIso8601String()}');
    print('🚚 Vehicle ID: ${widget.car.id}');
    print('🚚 Vehicle: ${widget.car.make} ${widget.car.model} ${widget.car.year}');
    print('🚚 Widget mounted: $mounted');
    print('🚚 Current context: ${context.widget.runtimeType}');

    // Step 1: Validation
    print('📋 STEP 1: Validating delivery location...');
    if (_deliveryLocationController.text.isEmpty) {
      print('❌ STEP 1 FAILED: Delivery location is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter delivery location', style: TextStyle(fontSize: 13)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedTransporterId == null || _selectedTransporterId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a transporter', style: TextStyle(fontSize: 13)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    print('✅ STEP 1 PASSED: Delivery location validated');
    print('   Delivery Location: ${_deliveryLocationController.text}');
    print('   Delivery City: ${_deliveryCityController.text}');
    print('   Delivery State: ${_deliveryStateController.text}');
    print('   Pickup Location: $_pickupLocation');
    print('   Total Cost: $_totalCost');
    print('   Shipping Option: $_selectedShippingOption');

    // Step 2: Set loading state
    print('🔄 STEP 2: Setting loading state...');
    setState(() {
      _isScheduling = true;
    });
    print('✅ STEP 2 PASSED: Loading state set to true');

    try {
      // Step 3: Calculate dates
      print('📅 STEP 3: Calculating delivery dates...');
      final deliveryDays = _selectedShippingOption == 'Expedited Delivery' ? 3 :
      _selectedShippingOption == 'Premium Enclosed' ? 5 : 7;
      final scheduledPickupDate = _userPickupDate ?? DateTime.now().add(const Duration(days: 1));
      final scheduledDeliveryDate = _userDeliveryDate ?? DateTime.now().add(Duration(days: deliveryDays));
      print('✅ STEP 3 PASSED: Dates calculated');
      print('   Pickup Date: ${scheduledPickupDate.toIso8601String()}');
      print('   Delivery Date: ${scheduledDeliveryDate.toIso8601String()}');
      print('   Delivery Days: $deliveryDays');

      // Step 4: Call API
      print('📡 STEP 4: Calling scheduleTransport API...');
      print('   API Parameters:');
      print('     - vehicleId: ${widget.car.id}');
      print('     - pickupLocation: $_pickupLocation');
      print('     - deliveryLocation: ${_deliveryLocationController.text}');
      print('     - deliveryCity: ${_deliveryCityController.text.isNotEmpty ? _deliveryCityController.text : 'null'}');
      print('     - deliveryState: ${_deliveryStateController.text.isNotEmpty ? _deliveryStateController.text : 'null'}');
      print('     - scheduledPickupDate: ${scheduledPickupDate.toIso8601String()}');
      print('     - scheduledDeliveryDate: ${scheduledDeliveryDate.toIso8601String()}');
      print('     - totalCost: $_totalCost');
      print('     - transporterId: ${_selectedTransporterId ?? 'null'}');
      print('     - deliveryZip: ${_deliveryZipController.text}');
      print('     - specialInstructions length: ${_instructionsController.text.length}');
      print('     - enteredCost: ${_costController.text}');

      double? enteredCost;
      try {
        if (_costController.text.trim().isNotEmpty) {
          enteredCost = double.parse(_costController.text.trim());
        }
      } catch (_) {
        // ignore parse error, will fall back to computed total
      }

      final apiStartTime = DateTime.now();
      final result = await _transportService.scheduleTransport(
        vehicleId: widget.car.id,
        pickupLocation: _pickupLocation,
        deliveryLocation: _deliveryLocationController.text,
        deliveryCity: _deliveryCityController.text.isNotEmpty ? _deliveryCityController.text : null,
        deliveryState: _deliveryStateController.text.isNotEmpty ? _deliveryStateController.text : null,
        scheduledPickupDate: scheduledPickupDate.toIso8601String(),
        scheduledDeliveryDate: scheduledDeliveryDate.toIso8601String(),
        pickupDate: scheduledPickupDate.toIso8601String(),
        deliveryDate: scheduledDeliveryDate.toIso8601String(),
        deliveryZip: _deliveryZipController.text.isNotEmpty ? _deliveryZipController.text : null,
        specialInstructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
        transporterId: _selectedTransporterId,
        selectedShippingOption: _selectedShippingOption,
        selectedDeliveryOption: _selectedDeliveryOption,
        selectedInsurance: _selectedInsurance,
        rushDelivery: _rushDelivery,
        totalCost: enteredCost ?? _totalCost,
      );
      final apiEndTime = DateTime.now();
      final apiDuration = apiEndTime.difference(apiStartTime).inMilliseconds;

      print('✅ STEP 4 PASSED: API call completed');
      print('   API Duration: ${apiDuration}ms');
      print('✅ Transport scheduled successfully in database');
      print('   📄 Order ID: ${result['order']?['id'] ?? 'N/A'}');
      print('   📊 Status: ${result['order']?['status'] ?? 'N/A'}');
      print('   📍 Delivery Address: ${result['order']?['delivery_address'] ?? 'N/A'}');
      print('   📍 Delivery Zip: ${result['order']?['delivery_zip'] ?? 'N/A'}');
      print('   📅 Pickup Date: ${result['order']?['pickup_date'] ?? 'N/A'}');
      print('   📅 Delivery Date: ${result['order']?['delivery_date'] ?? 'N/A'}');

      // Step 5: Check mounted state
      print('🔍 STEP 5: Checking widget mounted state...');
      if (!mounted) {
        print('❌ STEP 5 FAILED: Widget not mounted - cannot proceed with navigation');
        return;
      }
      print('✅ STEP 5 PASSED: Widget is mounted');

      // Step 6: Keep button disabled and update state
      print('🔄 STEP 6: Keeping button disabled...');
      // Don't reset _isScheduling here - keep it true to disable button
      // We'll navigate away so button state doesn't matter
      print('✅ STEP 6 PASSED: Button will remain disabled during navigation');

      // Step 7: Show success message
      print('💬 STEP 7: Showing success SnackBar...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transport scheduled successfully! Transporters will be notified.', style: TextStyle(fontSize: 13)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      print('✅ STEP 7 PASSED: Success SnackBar shown');

      // Step 8: Navigate — if buyer, go to Purchase History; same for others
      final role = await PreferencesHelper.getUserRole();
      final isBuyer = role?.toLowerCase() == 'buyer';
      print('🧭 STEP 8: User role: $role, isBuyer: $isBuyer → navigating to Purchase History');
      print('   Current route: ${ModalRoute.of(context)?.settings.name ?? 'unknown'}');
      print('   Can pop: ${Navigator.canPop(context)}');

      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        try {
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
            print('✅ Popped current screen');
            await Future.delayed(const Duration(milliseconds: 200));
            if (!mounted) return;
            try {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BillingHistoryScreen(),
                ),
              );
              print('✅ Navigated to Purchase History page' + (isBuyer ? ' (buyer)' : ''));
            } catch (e) {
              print('❌ Error navigating to Purchase History: $e');
            }
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BillingHistoryScreen(),
              ),
            );
            print('✅ Navigated to Purchase History page (direct)' + (isBuyer ? ' (buyer)' : ''));
          }
        } catch (e) {
          print('❌ Navigation error: $e');
          if (mounted) {
            try {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BillingHistoryScreen(),
                ),
              );
            } catch (e2) {
              Navigator.maybePop(context, true);
            }
          }
        }
      });

      print('✅ STEP 8 PASSED: Navigation to Purchase History scheduled');
    } catch (e, stackTrace) {
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime).inMilliseconds;

      print('❌ ========================================');
      print('❌ SCHEDULE TRANSPORT FAILED');
      print('❌ ========================================');
      print('❌ Total Duration: ${totalDuration}ms');
      print('❌ Error: $e');
      print('❌ Stack Trace: $stackTrace');
      print('❌ ========================================');

      if (mounted) {
        setState(() {
          _isScheduling = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule transport: ${e.toString()}', style: TextStyle(fontSize: 13)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTransporters() async {
    setState(() {
      _isLoadingTransporters = true;
      _transporterError = null;
    });
    try {
      final list = await _transportService.getTransporters();
      if (mounted) {
        setState(() {
          _transporters = list.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transporterError = e.toString();
        });
      }
      print('⚠️ Failed to load transporters: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTransporters = false;
        });
      }
    }
  }

  void _syncCostField() {
    if (!_costManuallyEdited) {
      _costController.text = _totalCost.toStringAsFixed(2);
    }
  }

  Future<void> _pickDateTime({required bool isPickup}) async {
    final now = DateTime.now();
    final initial = isPickup ? (_userPickupDate ?? now.add(const Duration(days: 1))) : (_userDeliveryDate ?? now.add(const Duration(days: 3)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: isPickup ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 17, minute: 0),
    );
    final dt = DateTime(date.year, date.month, date.day, time?.hour ?? (isPickup ? 9 : 17), time?.minute ?? 0);
    setState(() {
      if (isPickup) {
        _userPickupDate = dt;
        _pickupFieldController.text = _formatDdMm(dt);
      } else {
        _userDeliveryDate = dt;
        _deliveryFieldController.text = _formatDdMm(dt);
      }
      _syncCostField();
    });
  }

  String _formatDdMm(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min';
  }

  Widget _buildTransporterSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Transporter',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 6),
        if (_isLoadingTransporters)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_transporterError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Failed to load transporters',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _loadTransporters,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                child: const Text('Retry', style: TextStyle(fontSize: 11)),
              ),
            ],
          )
        else if (_transporters.isEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'No transporters found',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _loadTransporters,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  child: const Text('Refresh', style: TextStyle(fontSize: 11)),
                ),
              ],
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedTransporterId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Choose a transporter', style: TextStyle(fontSize: 14)),
              items: _transporters.map((t) {
                final id = t['id']?.toString();
                final company = (t['company_name']?.toString()?.isNotEmpty == true)
                    ? t['company_name']
                    : t['full_name'] ?? 'Unknown';
                final phone = t['phone'] ?? '';
                final email = t['email'] ?? '';
                final label = '$company  |  $phone  |  $email';
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTransporterId = value;
                });
              },
            ),
        const SizedBox(height: 6),
        if (_selectedTransporterId != null) _buildSelectedTransporterSummary(),
      ],
    );
  }

  Widget _buildSelectedTransporterSummary() {
    final t = _transporters.firstWhere(
          (e) => e['id']?.toString() == _selectedTransporterId,
      orElse: () => <String, dynamic>{},
    );
    if (t.isEmpty) return const SizedBox.shrink();
    final company = (t['company_name']?.toString()?.isNotEmpty == true)
        ? t['company_name']
        : t['full_name'] ?? 'Unknown';
    final phone = t['phone'] ?? '';
    final email = t['email'] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F3FF),
        border: Border.all(color: const Color(0xFF023873)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: Color(0xFF023873), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  [phone, email].where((s) => (s ?? '').toString().isNotEmpty).join('  |  '),
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pickup Date', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _pickupFieldController,
                    readOnly: true,
                    onTap: () async {
                      await _pickDateTime(isPickup: true);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today, size: 16),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Est. Delivery Date', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _deliveryFieldController,
                    readOnly: true,
                    onTap: () async {
                      await _pickDateTime(isPickup: false);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today, size: 16),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _deliveryZipController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            labelText: 'ZIP Code',
            labelStyle: const TextStyle(fontSize: 13),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            labelText: 'Special Instructions',
            hintText: 'Any special handling requirements, access instructions, or other details...',
            labelStyle: const TextStyle(fontSize: 13),
            hintStyle: const TextStyle(fontSize: 13),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _costController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _costManuallyEdited = true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            labelText: r'Transport Cost ($)',
            helperText: 'Enter the agreed transport cost with the selected transporter.',
            labelStyle: const TextStyle(fontSize: 13),
            helperStyle: const TextStyle(fontSize: 11),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kBlackColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _deliveryLocationController,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            labelText: 'Street Address',
            hintText: 'Enter delivery address',
            labelStyle: TextStyle(fontSize: 13),
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _deliveryCityController,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  labelText: 'City',
                  labelStyle: TextStyle(fontSize: 13),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _deliveryStateController,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  labelText: 'State',
                  labelStyle: TextStyle(fontSize: 13),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransportInfoAndMap() {
    final pickupFrom = _pickupZip.isNotEmpty ? ', $_pickupZip' : '';
    final deliverTo = [
      _deliveryLocationController.text,
      _deliveryCityController.text,
      _deliveryStateController.text,
      _deliveryZipController.text
    ].where((s) => s.isNotEmpty).join(', ');
    final costText = _costController.text.trim();
    final fallbackCost = _totalCost.isFinite ? _totalCost.toStringAsFixed(2) : '0.00';
    final displayCost = costText.isNotEmpty ? costText : fallbackCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF023873), Color(0xFF044DBC)]),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transport Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Pickup From:\n$pickupFrom', style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 6),
              Text('Deliver To:\n${deliverTo.isEmpty ? 'Enter delivery address' : deliverTo}', style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 8),
              Text('Estimated Cost: \$$displayCost', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.map, size: 32, color: Colors.grey),
              SizedBox(height: 4),
              Text('Route preview', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransportProcess() {
    final items = [
      'Select a certified transporter',
      'Schedule pickup and delivery dates',
      'Provide delivery address',
      'Review and confirm transport',
      'Track delivery in real-time',
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transport Process',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kBlackColor),
          ),
          const SizedBox(height: 4),
          ...items.map((text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTransportStatusCard() {
    if (_transportStatus == null || _transportStatus!['order'] == null) {
      return const SizedBox.shrink();
    }

    final order = _transportStatus!['order'] as Map<String, dynamic>;
    final status = order['status'] as String? ?? 'pending';
    final deliveryAddress = order['delivery_address'] as String? ?? 'N/A';
    final pickupDate = order['pickup_date'] as String?;
    final deliveryDate = order['delivery_date'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transport Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Requested by', _formatRequestedBy(order['requested_by'] as String?)),
          const SizedBox(height: 6),
          if (deliveryAddress != 'N/A') ...[
            _buildStatusRow('Delivery Address', deliveryAddress),
            const SizedBox(height: 6),
          ],
          if (pickupDate != null) ...[
            _buildStatusRow('Pickup Date', _formatDate(pickupDate)),
            const SizedBox(height: 6),
          ],
          if (deliveryDate != null) ...[
            _buildStatusRow('Delivery Date', _formatDate(deliveryDate)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  String _formatRequestedBy(String? requestedBy) {
    if (requestedBy == null || requestedBy.isEmpty) return 'N/A';
    switch (requestedBy.toLowerCase()) {
      case 'buyer':
        return 'Buyer';
      case 'seller':
        return 'Seller';
      default:
        return requestedBy[0].toUpperCase() + requestedBy.substring(1).toLowerCase();
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'in_transit':
      case 'delivery_scheduled':
      case 'pickup_scheduled':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}