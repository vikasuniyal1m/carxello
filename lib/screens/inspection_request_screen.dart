import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/user_service.dart';
import 'package:carauction/services/inspection_service.dart';

class InspectionRequestScreen extends StatefulWidget {
  final Car car;

  const InspectionRequestScreen({
    super.key,
    required this.car,
  });

  @override
  State<InspectionRequestScreen> createState() => _InspectionRequestScreenState();
}

class _InspectionRequestScreenState extends State<InspectionRequestScreen> {
  int _currentStep = 0; // 0: Vehicle Info, 1: Inspection Details, 2: Concerns & Photos
  final _formKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();
  
  // Step 1: Vehicle Information
  String? _selectedMake;
  final _modelController = TextEditingController();
  final _yearController = TextEditingController(text: '2020');
  DateTime? _purchaseDate;
  final _invoiceNumberController = TextEditingController(text: 'INV-2024-001');
  
  // Step 2: Inspection Details
  String? _selectedInspectionType = 'Post-Sale Inspection';
  String? _selectedPriority = 'Urgent';
  DateTime? _preferredDate;
  String? _selectedTime;
  final _vehicleLocationController = TextEditingController();
  String? _selectedInspectorId;
  String? _selectedInspectorName;
  List<Map<String, dynamic>> _availableInspectors = [];
  bool _isLoadingInspectors = false;
  bool _hasRequestedInspection = false;
  String? _inspectionStatus;
  
  final UserService _userService = UserService();
  final InspectionService _inspectionService = InspectionService();
  
  // Step 3: Concerns & Photos
  final Set<String> _selectedConcerns = {};
  final _descriptionController = TextEditingController();
  final List<String> _selectedPhotos = []; // Using String paths instead of File
  
  final List<String> _concernOptions = [
    'Engine',
    'Transmission',
    'Brakes',
    'Suspension',
    'Electrical',
    'Body/Paint',
    'Interior',
    'Tires/Wheels',
    'Air Conditioning',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkInspectionStatus();
    _loadAvailableInspectors();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _yearController.dispose();
    _invoiceNumberController.dispose();
    _vehicleLocationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkInspectionStatus() async {
    try {
      final status = widget.car.inspectionStatus;
      if (status != null && status.isNotEmpty && status != 'none') {
        setState(() {
          _hasRequestedInspection = true;
          _inspectionStatus = status;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadAvailableInspectors() async {
    setState(() {
      _isLoadingInspectors = true;
    });

    try {
      final inspectors = await _userService.getAvailableInspectors();
      setState(() {
        _availableInspectors = inspectors;
        _isLoadingInspectors = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInspectors = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load inspectors: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Request Post-sale Inspection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
          
          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Vehicle Information', 'Inspection Details', 'Concerns & Photos'];
    final progress = (_currentStep + 1) / 3;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 3',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                steps[_currentStep],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule a professional vehicle inspection.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Vehicle Criteria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Make Dropdown
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Make*',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: ['Any Make', 'Toyota', 'Honda', 'Ford', 'BMW', 'Mercedes', 'Audi']
                .map((make) => DropdownMenuItem(value: make, child: Text(make)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedMake = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty || value == 'Any Make') {
                return 'Please select a make';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Model
          TextFormField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: 'Model*',
              hintText: 'e.g, Camry',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter model';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Year
          TextFormField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Year*',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter year';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Purchase Date
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _purchaseDate = date;
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Purchase Date',
                hintText: 'dd-mm-yyyy',
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              child: Text(
                _purchaseDate != null
                    ? '${_purchaseDate!.day}-${_purchaseDate!.month}-${_purchaseDate!.year}'
                    : '',
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Invoice Number
          TextFormField(
            controller: _invoiceNumberController,
            decoration: InputDecoration(
              labelText: 'Invoice Number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inspection Type*',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildInspectionTypeCard('Post-Sale Inspection', 'verify vehicle condition after purchase'),
          const SizedBox(height: 12),
          _buildInspectionTypeCard('Arbitration Support', 'Documentation for dispute resolution'),
          const SizedBox(height: 12),
          _buildInspectionTypeCard('Damage Assessment', 'Evaluate specific damage or issues'),
          const SizedBox(height: 12),
          _buildInspectionTypeCard('Pre-Delivery Check', 'final inspection before taking delivery'),
          
          const SizedBox(height: 24),
          const Text(
            'Priority Level*',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPriorityCard('Low', 'Within 2 weeks', Colors.green[50]!)),
              const SizedBox(width: 12),
              Expanded(child: _buildPriorityCard('Medium', 'Within 1 week', Colors.blue[50]!)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPriorityCard('High', 'Within 3 days', Colors.orange[50]!)),
              const SizedBox(width: 12),
              Expanded(child: _buildPriorityCard('Urgent', 'Within 24 hours', Colors.red[50]!)),
            ],
          ),
          
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (date != null) {
                setState(() {
                  _preferredDate = date;
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Preferred Date',
                hintText: 'dd-mm-yyyy',
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              child: Text(
                _preferredDate != null
                    ? '${_preferredDate!.day}-${_preferredDate!.month}-${_preferredDate!.year}'
                    : '',
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Preferred Time',
              hintText: 'Select Time',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: ['9:00 AM', '10:00 AM', '11:00 AM', '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM']
                .map((time) => DropdownMenuItem(value: time, child: Text(time)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedTime = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _vehicleLocationController,
            decoration: InputDecoration(
              labelText: 'Vehicle Location*',
              hintText: 'Enter address or ZIP code',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter vehicle location';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          if (_hasRequestedInspection) ...[
            // Show inspection status if already requested
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(_inspectionStatus ?? 'pending'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(_inspectionStatus ?? 'pending'),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inspection Status:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _inspectionStatus?.toUpperCase() ?? 'PENDING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show inspector dropdown if not yet requested
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Inspector Preference',
                hintText: 'Any Available Inspector',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              value: _selectedInspectorId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Any Available Inspector'),
                ),
                ..._availableInspectors.map((inspector) {
                  return DropdownMenuItem(
                    value: inspector['id'].toString(),
                    child: Text(inspector['name'] ?? 'Unknown'),
                  );
                }),
              ],
              onChanged: _isLoadingInspectors ? null : (value) {
                setState(() {
                  _selectedInspectorId = value;
                  if (value != null) {
                    final inspector = _availableInspectors.firstWhere(
                      (i) => i['id'].toString() == value,
                    );
                    _selectedInspectorName = inspector['name'];
                  } else {
                    _selectedInspectorName = null;
                  }
                });
              },
            ),
            if (_isLoadingInspectors)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInspectionTypeCard(String title, String subtitle) {
    final isSelected = _selectedInspectionType == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInspectionType = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kAccentColor.withValues(alpha: 0.2) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kAccentColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio(
              value: title,
              groupValue: _selectedInspectionType,
              onChanged: (value) {
                setState(() {
                  _selectedInspectionType = value;
                });
              },
              activeColor: kAccentColor,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? kAccentColor : kBlackColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityCard(String priority, String duration, Color color) {
    final isSelected = _selectedPriority == priority;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = priority;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kAccentColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              priority,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? kAccentColor : kBlackColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              duration,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Specific Concerns & Documentation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'New/Reduced Price.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _concernOptions.map((concern) {
              final isSelected = _selectedConcerns.contains(concern);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedConcerns.remove(concern);
                    } else {
                      _selectedConcerns.add(concern);
                    }
                  });
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 56) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? kAccentColor.withValues(alpha: 0.2) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? kAccentColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isSelected ? kAccentColor : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          concern,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? kAccentColor : kBlackColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Detailed Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 500,
            onChanged: (value) {
              setState(() {}); // Trigger rebuild to update character count
            },
            decoration: InputDecoration(
              hintText: 'Describe............',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_descriptionController.text.length}/500 Characters',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Supporting Photos (Optional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              child: _selectedPhotos.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text(
                          'Click to upload photos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PNG, JPG up to 10 MB each',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedPhotos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.image, size: 40, color: Colors.grey),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _selectedPhotos.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    // Simulate image picker - in production, use image_picker package
    // For now, just add a placeholder
    setState(() {
      _selectedPhotos.add('photo_${_selectedPhotos.length + 1}');
    });
    
    // Show dialog to simulate image selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image picker would open here. Add image_picker package for full functionality.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Previous',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep < 2) {
                    // Validate current step
                    bool isValid = false;
                    if (_currentStep == 0) {
                      isValid = _step1FormKey.currentState!.validate();
                    } else if (_currentStep == 1) {
                      isValid = _step2FormKey.currentState!.validate() &&
                          _selectedInspectionType != null &&
                          _selectedPriority != null;
                    }
                    
                    if (isValid) {
                      setState(() {
                        _currentStep++;
                      });
                    }
                  } else {
                    // Submit form
                    _handleSubmit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep < 2 ? 'Next' : 'Submit',
                  style: const TextStyle(
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

  Future<void> _handleSubmit() async {
    if (_hasRequestedInspection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inspection already requested. Status: ${_inspectionStatus ?? 'pending'}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_vehicleLocationController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter vehicle location'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Map priority to backend expected values: 'low', 'normal', or 'high'
      String? mappedPriority;
      if (_selectedPriority != null) {
        switch (_selectedPriority!.toLowerCase()) {
          case 'low':
            mappedPriority = 'low';
            break;
          case 'medium':
            mappedPriority = 'normal';
            break;
          case 'high':
          case 'urgent':
            mappedPriority = 'high';
            break;
          default:
            mappedPriority = 'normal';
        }
      }
      
      // Format date as YYYY-MM-DD if provided
      String? formattedDate;
      if (_preferredDate != null) {
        formattedDate = '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}';
      }
      
      final result = await _inspectionService.createRequest(
        vehicleId: widget.car.id,
        scheduledDate: formattedDate,
        location: _vehicleLocationController.text,
        priority: mappedPriority,
        notes: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        inspectorId: _selectedInspectorId,
      );

      if (mounted) {
        setState(() {
          _hasRequestedInspection = true;
          _inspectionStatus = result['inspection']?['status'] ?? 'pending';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        
        // Extract the actual error message, removing nested exception wrappers
        if (errorMessage.contains('Exception: ')) {
          // Get the last exception message (the most specific one)
          final parts = errorMessage.split('Exception: ');
          if (parts.length > 1) {
            errorMessage = parts.last.trim();
          }
        }
        
        // Remove "Failed to create inspection request:" prefix if present
        if (errorMessage.startsWith('Failed to create inspection request: ')) {
          errorMessage = errorMessage.substring('Failed to create inspection request: '.length);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isEmpty 
                ? 'Failed to submit inspection request. Please check your input and try again.'
                : errorMessage,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'assigned':
        return Icons.assignment;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.info;
    }
  }
}

