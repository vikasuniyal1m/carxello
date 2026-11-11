import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/models/saved_search.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SaveSearchScreen extends StatefulWidget {
  final SavedSearch? existingSearch;

  const SaveSearchScreen({super.key, this.existingSearch});

  @override
  State<SaveSearchScreen> createState() => _SaveSearchScreenState();
}

class _SaveSearchScreenState extends State<SaveSearchScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  late TextEditingController _searchNameController;
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearFromController;
  late TextEditingController _yearToController;
  late TextEditingController _priceMinController;
  late TextEditingController _priceMaxController;
  late TextEditingController _maxMileageController;
  late TextEditingController _zipCodeController;
  late TextEditingController _searchRadiusController;

  // Dropdown values
  String? _selectedMake;
  String? _selectedCondition;
  String? _selectedSearchRadius;
  String? _selectedAlertFrequency = 'Immediate';

  // Checkbox value
  bool _enableEmailAlerts = false;

  // Make options
  final List<String> _makeOptions = [
    'Any Make',
    'Toyota',
    'Honda',
    'Ford',
    'Chevrolet',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Volkswagen',
    'Genesis',
    'Lexus',
    'Tesla',
    'Nissan',
    'Hyundai',
    'Kia',
  ];

  // Condition options
  final List<String> _conditionOptions = [
    'Any Condition',
    'New',
    'Used',
    'Certified Pre-Owned',
    'Salvage',
  ];

  // Search radius options
  final List<String> _radiusOptions = [
    '10 miles',
    '25 miles',
    '50 miles',
    '100 miles',
    '250 miles',
    '500 miles',
    'Nationwide',
  ];

  // Alert frequency options
  final List<String> _alertFrequencyOptions = [
    'Immediate',
    'Daily',
    'Weekly',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing search data or defaults
    _searchNameController = TextEditingController(text: widget.existingSearch?.searchName ?? '');
    _makeController = TextEditingController(text: widget.existingSearch?.make ?? '');
    _modelController = TextEditingController(text: widget.existingSearch?.model ?? 'Any Model');
    _yearFromController = TextEditingController(text: widget.existingSearch?.yearFrom?.toString() ?? '');
    _yearToController = TextEditingController(text: widget.existingSearch?.yearTo?.toString() ?? '');
    _priceMinController = TextEditingController(text: widget.existingSearch?.priceMin?.toString() ?? '');
    _priceMaxController = TextEditingController(text: widget.existingSearch?.priceMax?.toString() ?? '');
    _maxMileageController = TextEditingController(text: widget.existingSearch?.maxMileage?.toString() ?? '1000000');
    _zipCodeController = TextEditingController(text: widget.existingSearch?.zipCode ?? '90210');
    _searchRadiusController = TextEditingController();

    // Set dropdown values
    _selectedMake = widget.existingSearch?.make ?? 'Any Make';
    _selectedCondition = widget.existingSearch?.condition ?? 'Any Condition';
    _selectedSearchRadius = widget.existingSearch?.searchRadius != null
        ? '${widget.existingSearch!.searchRadius} miles'
        : '50 miles';
    _selectedAlertFrequency = widget.existingSearch?.alertFrequency ?? 'Immediate';
    _enableEmailAlerts = widget.existingSearch?.enableEmailAlerts ?? false;
  }

  @override
  void dispose() {
    _searchNameController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearFromController.dispose();
    _yearToController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _maxMileageController.dispose();
    _zipCodeController.dispose();
    _searchRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return SafeScaffold(
        backgroundColor: Colors.white,
        enableScroll: false,
        appBar: AppBar(
          backgroundColor: kAccentColor,
          foregroundColor: Colors.white,
          toolbarHeight: 56,
          iconTheme: const IconThemeData(
            color: Colors.white,
            size: 24,
          ),
          title: const Text(
            'Save Search',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          leadingWidth: 56,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: SafeContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Name Section
                  _buildSectionTitle('Search Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _searchNameController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'eg., Luxury SUVs under \$50k',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a search name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Vehicle Criteria Section
                  _buildSectionTitle('Vehicle Criteria'),
                  const SizedBox(height: 12),

                  // Make
                  _buildLabel('Make'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedMake,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    items: _makeOptions.map((String make) {
                      return DropdownMenuItem<String>(
                        value: make,
                        child: Text(
                          make,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedMake = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Model
                  _buildLabel('Model'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _modelController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Any Model',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Year Range
                  _buildLabel('Year Range'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _yearFromController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'From',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _yearToController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'To',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price Range
                  _buildLabel('Price Range'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceMinController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Min',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _priceMaxController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Max',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Max Mileage
                  _buildLabel('Max Mileage'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _maxMileageController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter max mileage',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Condition
                  _buildLabel('Condition'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    items: _conditionOptions.map((String condition) {
                      return DropdownMenuItem<String>(
                        value: condition,
                        child: Text(
                          condition,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCondition = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Location Criteria Section
                  _buildSectionTitle('Location'),
                  const SizedBox(height: 12),

                  // ZIP Code
                  _buildLabel('ZIP Code'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _zipCodeController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter ZIP code',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Search Radius
                  _buildLabel('Search Radius'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedSearchRadius,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAccentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    items: _radiusOptions.map((String radius) {
                      return DropdownMenuItem<String>(
                        value: radius,
                        child: Text(
                          radius,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedSearchRadius = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Alert Settings Section
                  _buildSectionTitle('Alerts'),
                  const SizedBox(height: 12),

                  // Enable Email Alerts Checkbox
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _enableEmailAlerts,
                          onChanged: (bool? value) {
                            setState(() {
                              _enableEmailAlerts = value ?? false;
                            });
                          },
                          activeColor: kAccentColor,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Email alerts for matching vehicles',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Alert Frequency - Radio buttons in row
                  // Frequency section - REPLACE your current radio buttons with this
                  _buildLabel('Frequency'),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Immediate
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAlertFrequency = 'Immediate';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Radio<String>(
                                  value: 'Immediate',
                                  groupValue: _selectedAlertFrequency,
                                  onChanged: (String? value) {
                                    setState(() {
                                      _selectedAlertFrequency = value;
                                    });
                                  },
                                  activeColor: kAccentColor,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                ),
                                const Text(
                                  'Immediate',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Daily
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAlertFrequency = 'Daily';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Radio<String>(
                                  value: 'Daily',
                                  groupValue: _selectedAlertFrequency,
                                  onChanged: (String? value) {
                                    setState(() {
                                      _selectedAlertFrequency = value;
                                    });
                                  },
                                  activeColor: kAccentColor,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                ),
                                const Text(
                                  'Daily',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Weekly
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAlertFrequency = 'Weekly';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Radio<String>(
                                  value: 'Weekly',
                                  groupValue: _selectedAlertFrequency,
                                  onChanged: (String? value) {
                                    setState(() {
                                      _selectedAlertFrequency = value;
                                    });
                                  },
                                  activeColor: kAccentColor,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                ),
                                const Text(
                                  'Weekly',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            side: BorderSide(
                              color: Colors.grey[400]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey[800],
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saveSearch,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            backgroundColor: kAccentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Search',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        )
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 1.5,
          width: 40,
          color: kAccentColor,
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Colors.black54,
      ),
    );
  }

  void _saveSearch() {
    if (_formKey.currentState!.validate()) {
      final searchRadiusValue = _selectedSearchRadius == 'Nationwide'
          ? null
          : int.tryParse(_selectedSearchRadius!.replaceAll(' miles', ''));

      final savedSearch = SavedSearch(
        id: widget.existingSearch?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        searchName: _searchNameController.text.trim(),
        make: _selectedMake == 'Any Make' ? null : _selectedMake,
        model: _modelController.text.trim().isEmpty || _modelController.text.trim() == 'Any Model'
            ? null
            : _modelController.text.trim(),
        yearFrom: _yearFromController.text.trim().isEmpty
            ? null
            : int.tryParse(_yearFromController.text.trim()),
        yearTo: _yearToController.text.trim().isEmpty
            ? null
            : int.tryParse(_yearToController.text.trim()),
        priceMin: _priceMinController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceMinController.text.trim()),
        priceMax: _priceMaxController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceMaxController.text.trim()),
        maxMileage: _maxMileageController.text.trim().isEmpty
            ? null
            : int.tryParse(_maxMileageController.text.trim()),
        condition: _selectedCondition == 'Any Condition' ? null : _selectedCondition,
        zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
        searchRadius: searchRadiusValue,
        enableEmailAlerts: _enableEmailAlerts,
        alertFrequency: _selectedAlertFrequency ?? 'Immediate',
        createdAt: widget.existingSearch?.createdAt ?? DateTime.now(),
        lastMatch: widget.existingSearch?.lastMatch,
        currentMatches: widget.existingSearch?.currentMatches ?? 0,
      );

      Navigator.pop(context, savedSearch);
    }
  }
}