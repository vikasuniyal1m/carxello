import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ContinueInspectionScreen extends StatefulWidget {
  final Car car;
  final String inspectionId;
  final String date;
  final String location;

  const ContinueInspectionScreen({
    super.key,
    required this.car,
    required this.inspectionId,
    required this.date,
    required this.location,
  });

  @override
  State<ContinueInspectionScreen> createState() => _ContinueInspectionScreenState();
}

class _ContinueInspectionScreenState extends State<ContinueInspectionScreen> {
  final InspectionService _inspectionService = InspectionService();
  final _formKey = GlobalKey<FormState>();
  
  // Inspection categories and items (matching PHP file)
  final Map<String, List<String>> _categoryItems = {
    'Exterior': ['Paint Condition', 'Body Panels', 'Glass & Windows', 'Lights', 'Tires & Wheels', 'Bumpers'],
    'Interior': ['Seats & Upholstery', 'Dashboard', 'Carpet & Flooring', 'Controls & Switches', 'Air Conditioning', 'Audio System'],
    'Mechanical': ['Engine Performance', 'Transmission', 'Brakes', 'Suspension', 'Exhaust System', 'Cooling System'],
    'Electrical': ['Battery', 'Charging System', 'Starting System', 'Lighting System', 'Wiring', 'Fuses'],
    'Undercarriage': ['Frame', 'Suspension Components', 'Brake Lines', 'Exhaust System', 'Fuel Lines', 'Rust & Corrosion'],
    'Test Drive': ['Engine Performance', 'Transmission Shifting', 'Braking', 'Steering', 'Suspension', 'Noise & Vibration'],
  };

  // Store inspection data: category -> item index -> {grade, notes}
  final Map<String, Map<int, Map<String, dynamic>>> _inspectionData = {};
  
  // Store TextEditingControllers for notes fields to maintain text direction
  final Map<String, Map<int, TextEditingController>> _notesControllers = {};
  
  // Overall assessment
  String? _overallGrade;
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _recommendationsController = TextEditingController();
  
  // Expand/Collapse state for each section - only one expanded at a time
  final Map<String, bool> _expandedSections = {
    'Exterior': true,
    'Interior': false,
    'Mechanical': false,
    'Electrical': false,
    'Undercarriage': false,
    'Test Drive': false,
    'Overall Assessment': false,
  };
  
  void _toggleSection(String sectionName) {
    setState(() {
      final isCurrentlyExpanded = _expandedSections[sectionName] ?? false;
      
      // If clicking on an already expanded section, collapse it
      if (isCurrentlyExpanded) {
        _expandedSections[sectionName] = false;
      } else {
        // Collapse all sections first
        for (var key in _expandedSections.keys) {
          _expandedSections[key] = false;
        }
        // Then expand the clicked section
        _expandedSections[sectionName] = true;
      }
    });
    
    // Scroll to the section after expanding
    if (_expandedSections[sectionName] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(sectionName);
      });
    }
  }
  
  void _scrollToSection(String sectionName) {
    final key = _sectionKeys[sectionName];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _startInspection() async {
    // If status is null, try to reload it first from multiple sources
    if (_inspectionStatus == null) {
      try {
        final inspectionDetails = await _inspectionService.getInspectionDetails(widget.inspectionId);
        // Status is inside 'inspection' object in the response
        if (inspectionDetails['inspection'] != null) {
          _inspectionStatus = inspectionDetails['inspection']['status']?.toString().toLowerCase();
        } else {
          _inspectionStatus = inspectionDetails['status']?.toString().toLowerCase();
        }
        print('📋 Reloaded Inspection Status: $_inspectionStatus');
      } catch (e) {
        print('Could not reload status from details: $e');
        // Try dashboard as fallback
        try {
          final dashboard = await _inspectionService.getDashboard();
          final inspections = dashboard['inspections'] as List<dynamic>? ?? [];
          for (var inspection in inspections) {
            if (inspection['id']?.toString() == widget.inspectionId) {
              _inspectionStatus = inspection['status']?.toString().toLowerCase();
              print('📋 Reloaded Inspection Status from dashboard: $_inspectionStatus');
              break;
            }
          }
        } catch (e2) {
          print('Could not reload status from dashboard: $e2');
        }
      }
    }
    
    // If status is "in_progress", already started
    if (_inspectionStatus == 'in_progress') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection is already in progress!'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // If status is "completed", cannot start
    if (_inspectionStatus == 'completed') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This inspection is already completed.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    setState(() {
      _isStartingInspection = true;
    });
    
    try {
      // If status is "pending", first claim it (changes to "assigned")
      if (_inspectionStatus == 'pending') {
        try {
          await _inspectionService.claimInspection(widget.inspectionId);
          // Reload status from API to ensure we have the latest
          await _reloadStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Inspection claimed successfully! Starting inspection...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Small delay to ensure status is updated
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to claim inspection: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }
      
      // Now start the inspection (status should be "assigned" now)
      await _inspectionService.startInspection(widget.inspectionId);
      // Reload status from API to ensure we have the latest
      await _reloadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('must be in "assigned" status')) {
        errorMessage = 'Cannot start inspection. The inspection must be in "assigned" status. Current status: ${_inspectionStatus ?? "unknown"}.';
      } else if (errorMessage.contains('Failed to start inspection')) {
        errorMessage = 'Failed to start inspection: ${errorMessage.split("Exception:").last.trim()}';
      } else if (errorMessage.contains('Failed to claim')) {
        errorMessage = 'Failed to claim inspection: ${errorMessage.split("Exception:").last.trim()}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingInspection = false;
        });
      }
    }
  }
  
  // Photos
  final List<File> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Vehicle info
  Map<String, dynamic>? _vehicleInfo;
  List<Map<String, dynamic>>? _vehiclePhotos;
  bool _isLoading = true;
  
  // Scroll controller for auto-scrolling to sections
  final ScrollController _scrollController = ScrollController();
  
  // GlobalKeys for each section to scroll to them
  final Map<String, GlobalKey> _sectionKeys = {};
  
  // Inspection status
  String? _inspectionStatus;
  bool _isStartingInspection = false;

  @override
  void initState() {
    super.initState();
    // Initialize GlobalKeys for each section
    for (var category in _categoryItems.keys) {
      _sectionKeys[category] = GlobalKey();
    }
    _sectionKeys['Overall Assessment'] = GlobalKey();
    _loadInspectionData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload status when screen comes into focus (e.g., when assigned from dashboard)
    // Only reload if data is already loaded to avoid conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading) {
        _reloadStatus();
      }
    });
  }

  Future<void> _reloadStatus() async {
    try {
      final inspectionDetails = await _inspectionService.getInspectionDetails(widget.inspectionId);
      // Status is inside 'inspection' object in the response
      if (inspectionDetails['inspection'] != null) {
        final newStatus = inspectionDetails['inspection']['status']?.toString().toLowerCase();
        if (newStatus != _inspectionStatus) {
          setState(() {
            _inspectionStatus = newStatus;
          });
          print('📋 Status Reloaded: $_inspectionStatus');
        }
      } else {
        // Fallback: check if status is at root level
        final newStatus = inspectionDetails['status']?.toString().toLowerCase();
        if (newStatus != _inspectionStatus) {
          setState(() {
            _inspectionStatus = newStatus;
          });
          print('📋 Status Reloaded from root: $_inspectionStatus');
        }
      }
    } catch (e) {
      print('Note: Could not reload status from details: $e');
      // Try to get status from dashboard
      try {
        final dashboard = await _inspectionService.getDashboard();
        final inspections = dashboard['inspections'] as List<dynamic>? ?? [];
        for (var inspection in inspections) {
          if (inspection['id']?.toString() == widget.inspectionId) {
            final newStatus = inspection['status']?.toString().toLowerCase();
            if (newStatus != _inspectionStatus) {
              setState(() {
                _inspectionStatus = newStatus;
              });
              print('📋 Status Reloaded from dashboard: $_inspectionStatus');
            }
            break;
          }
        }
      } catch (e2) {
        print('Note: Could not reload status from dashboard: $e2');
      }
    }
  }

  Future<void> _loadInspectionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to load inspection details to get status
      try {
        final inspectionDetails = await _inspectionService.getInspectionDetails(widget.inspectionId);
        // Status is inside 'inspection' object in the response
        if (inspectionDetails['inspection'] != null) {
          _inspectionStatus = inspectionDetails['inspection']['status']?.toString().toLowerCase();
          print('📋 Inspection Status Loaded from details: $_inspectionStatus');
        } else {
          // Fallback: check if status is at root level
          _inspectionStatus = inspectionDetails['status']?.toString().toLowerCase();
          print('📋 Inspection Status Loaded from root: $_inspectionStatus');
        }
      } catch (e) {
        print('Note: Could not load inspection status from details: $e');
        
        // Try to get status from dashboard
        try {
          final dashboard = await _inspectionService.getDashboard();
          final inspections = dashboard['inspections'] as List<dynamic>? ?? [];
          for (var inspection in inspections) {
            if (inspection['id']?.toString() == widget.inspectionId) {
              _inspectionStatus = inspection['status']?.toString().toLowerCase();
              print('📋 Inspection Status Loaded from dashboard: $_inspectionStatus');
              break;
            }
          }
        } catch (e2) {
          print('Note: Could not load inspection status from dashboard: $e2');
          _inspectionStatus = null;
        }
      }
      
      // Load inspection details (vehicle info, photos, etc.)
      // This would come from an API endpoint
      setState(() {
        _vehicleInfo = {
          'make': widget.car.make,
          'model': widget.car.model,
          'year': widget.car.year,
          'vin': widget.car.vin ?? '',
          'mileage': widget.car.mileage,
          'engine_type': 'V6',
          'drive_train': 'Automatic',
        };
        _vehiclePhotos = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      setState(() {
        _selectedPhotos.addAll(images.map((xFile) => File(xFile.path)));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking photos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_overallGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select overall grade'), backgroundColor: Colors.red),
      );
      return;
    }

    // Validate that at least some inspection items are filled
    bool hasData = false;
    for (var category in _categoryItems.keys) {
      if (_inspectionData[category] != null && _inspectionData[category]!.isNotEmpty) {
        hasData = true;
        break;
      }
    }

    if (!hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill at least one inspection category'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Inspection Report'),
        content: const Text('Are you sure you want to submit this inspection report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Ensure inspection is in progress before submitting
      // Only try to start if status is "assigned", otherwise assume it's already in progress
      if (_inspectionStatus == 'assigned') {
        try {
          await _inspectionService.startInspection(widget.inspectionId);
          // Reload status from API to ensure we have the latest
          await _reloadStatus();
          // Small delay to ensure status is updated
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          // If start fails, show error and return
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot submit: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      } else if (_inspectionStatus != 'in_progress') {
        // If status is not in_progress and not assigned, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot submit. Inspection status must be "in_progress". Current status: ${_inspectionStatus ?? "unknown"}. Please start the inspection first.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Prepare inspection data in the format expected by backend
      final Map<String, dynamic> inspectionDataMap = {};
      for (var category in _categoryItems.keys) {
        if (_inspectionData[category] != null) {
          final List<Map<String, dynamic>> items = [];
          _inspectionData[category]!.forEach((index, data) {
            items.add({
              'name': _categoryItems[category]![index],
              'grade': data['grade'],
              'notes': data['notes'] ?? '',
            });
          });
          inspectionDataMap[category] = items;
        }
      }

      // Submit detailed inspection report
      await _inspectionService.submitDetailedReport(
        inspectionId: widget.inspectionId,
        overallGrade: _overallGrade!,
        summary: _summaryController.text,
        recommendations: _recommendationsController.text,
        inspectionData: inspectionDataMap,
        photos: _selectedPhotos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        
        // Provide user-friendly error messages
        if (errorMessage.contains('must be in progress')) {
          errorMessage = 'Please start the inspection first. The inspection status needs to be "in progress" before submitting the report.';
        } else if (errorMessage.contains('Failed to submit detailed report')) {
          errorMessage = 'Failed to submit report. Please check your internet connection and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  TextEditingController _getNotesController(String category, int index, String initialText) {
    _notesControllers.putIfAbsent(category, () => {});
    if (!_notesControllers[category]!.containsKey(index)) {
      final controller = TextEditingController(text: initialText);
      controller.text = initialText;
      _notesControllers[category]![index] = controller;
    } else {
      // Update text if it changed
      if (_notesControllers[category]![index]!.text != initialText) {
        _notesControllers[category]![index]!.text = initialText;
      }
    }
    return _notesControllers[category]![index]!;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _recommendationsController.dispose();
    _scrollController.dispose();
    // Dispose all notes controllers
    for (var categoryControllers in _notesControllers.values) {
      for (var controller in categoryControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kWhiteColor,
        appBar: AppBar(
          backgroundColor: kAccentColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Continue Inspection',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Continue Inspection',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: ResponsiveHelper.safePadding(context, all: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start Inspection Button (show if not in_progress)
                if (_inspectionStatus != 'in_progress')
                  Container(
                    margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
                    padding: ResponsiveHelper.safePadding(context, all: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[300]!, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                            Expanded(
                              child: Text(
                                _inspectionStatus == 'assigned' 
                                    ? 'Please start the inspection before filling the form'
                                    : _inspectionStatus == 'pending'
                                        ? 'Inspection is pending. Click to claim and start inspection.'
                                        : 'Current status: ${_inspectionStatus ?? "loading..."}. Click to start inspection.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isStartingInspection ? null : _startInspection,
                            icon: _isStartingInspection
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(Icons.play_arrow),
                            label: Text(_isStartingInspection ? 'Starting...' : 'Start Inspection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: ResponsiveHelper.safePadding(context, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Vehicle Information Card
                _buildVehicleInfoCard(),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                
                // Inspection Categories
                _buildInspectionCategories(),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                
                // Overall Assessment
                _buildOverallAssessment(),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                
                // Inspection Photos
                _buildPhotoSection(),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                
                // Submit Button
                _buildSubmitSection(),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle Information',
            style: ResponsiveHelper.subheadingStyle(context, color: kBlackColor),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Image
                    Center(
                      child: Container(
                        width: ResponsiveHelper.safeWidth(context, mobile: 120),
                        height: ResponsiveHelper.safeHeight(context, mobile: 120),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 8),
                          ),
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 8),
                          ),
                          child: widget.car.imageUrl.startsWith('http')
                              ? Image.network(
                                  widget.car.imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 240, // Optimize memory (2x for retina)
                                  cacheHeight: 240,
                                  errorBuilder: (_, __, ___) => const Image(
                                    image: AssetImage('assets/images/car1.png'),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Image(
                                  image: AssetImage('assets/images/car1.png'),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    // Vehicle Details
                    _buildVehicleDetails(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Image
                    Container(
                      width: ResponsiveHelper.safeWidth(context, mobile: 120),
                      height: ResponsiveHelper.safeHeight(context, mobile: 120),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 8),
                        ),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 8),
                        ),
                          child: widget.car.imageUrl.startsWith('http')
                              ? Image.network(
                                  widget.car.imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 240, // Optimize memory (2x for retina)
                                  cacheHeight: 240,
                                  errorBuilder: (_, __, ___) => const Image(
                                    image: AssetImage('assets/images/car1.png'),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Image(
                                  image: AssetImage('assets/images/car1.png'),
                                  fit: BoxFit.cover,
                                ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                    // Vehicle Details
                    Expanded(
                      child: _buildVehicleDetails(),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_vehicleInfo?['make'] ?? widget.car.make} ${_vehicleInfo?['model'] ?? widget.car.model} (${_vehicleInfo?['year'] ?? widget.car.year})',
          style: ResponsiveHelper.subheadingStyle(context),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
        _buildInfoRow('VIN:', _vehicleInfo?['vin'] ?? widget.car.vin ?? 'N/A'),
        _buildInfoRow('Mileage:', '${_vehicleInfo?['mileage'] ?? widget.car.mileage} miles'),
        _buildInfoRow('Engine:', _vehicleInfo?['engine_type'] ?? 'N/A'),
        _buildInfoRow('Transmission:', _vehicleInfo?['drive_train'] ?? 'N/A'),
        _buildInfoRow('Location:', widget.location),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveHelper.safeWidth(context, mobile: 80),
            child: Text(
              label,
              style: ResponsiveHelper.bodyStyle(context, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveHelper.bodyStyle(context, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCategories() {
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inspection Details',
            style: ResponsiveHelper.subheadingStyle(context, color: kBlackColor),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          ..._categoryItems.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String categoryName, List<String> items) {
    final isExpanded = _expandedSections[categoryName] ?? true;
    
    return Container(
      key: _sectionKeys[categoryName],
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 8),
        ),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () {
              _toggleSection(categoryName);
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
              topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
            ),
            child: Container(
              padding: ResponsiveHelper.safePadding(context, all: 16),
              decoration: BoxDecoration(
                color: kAccentColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                  topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
                border: Border(left: BorderSide(color: kAccentColor, width: 4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(categoryName),
                          color: kAccentColor,
                          size: 24,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          categoryName,
                          style: ResponsiveHelper.subheadingStyle(context, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: kAccentColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          // Content (shown when expanded)
          if (isExpanded)
            Container(
              padding: ResponsiveHelper.safePadding(context, all: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.asMap().entries.map((entry) => _buildInspectionItem(categoryName, entry.key, entry.value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'Exterior':
        return Icons.directions_car;
      case 'Interior':
        return Icons.airline_seat_recline_normal;
      case 'Mechanical':
        return Icons.build;
      case 'Electrical':
        return Icons.electrical_services;
      case 'Undercarriage':
        return Icons.construction;
      case 'Test Drive':
        return Icons.drive_eta;
      default:
        return Icons.checklist;
    }
  }

  Widget _buildInspectionItem(String category, int index, String itemName) {
    final itemData = _inspectionData[category]?[index] ?? {};
    final currentGrade = itemData['grade'] ?? '';
    final currentNotes = itemData['notes'] ?? '';
    final isMobile = ResponsiveHelper.isMobile(context);

    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Row(
                  children: [
                    // Grade Dropdown
                    Expanded(
                      child: Container(
                        padding: ResponsiveHelper.safePadding(context, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 8),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentGrade.isEmpty ? null : currentGrade,
                            hint: Text(
                              'Grade',
                              style: ResponsiveHelper.captionStyle(context),
                            ),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: 'excellent',
                                child: Text('Excellent', style: ResponsiveHelper.captionStyle(context)),
                              ),
                              DropdownMenuItem(
                                value: 'good',
                                child: Text('Good', style: ResponsiveHelper.captionStyle(context)),
                              ),
                              DropdownMenuItem(
                                value: 'fair',
                                child: Text('Fair', style: ResponsiveHelper.captionStyle(context)),
                              ),
                              DropdownMenuItem(
                                value: 'poor',
                                child: Text('Poor', style: ResponsiveHelper.captionStyle(context)),
                              ),
                              DropdownMenuItem(
                                value: 'unsatisfactory',
                                child: Text('Unsatisfactory', style: ResponsiveHelper.captionStyle(context)),
                              ),
                              DropdownMenuItem(
                                value: 'not_applicable',
                                child: Text('N/A', style: ResponsiveHelper.captionStyle(context)),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _inspectionData.putIfAbsent(category, () => {});
                                _inspectionData[category]!.putIfAbsent(index, () => {});
                                _inspectionData[category]![index]!['grade'] = value ?? '';
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                // Notes Field
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _getNotesController(category, index, currentNotes),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\x00-\x7F]')), // Only ASCII characters
                    ],
                    decoration: InputDecoration(
                      hintText: 'Notes',
                      hintStyle: ResponsiveHelper.captionStyle(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 8),
                        ),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: ResponsiveHelper.safePadding(context, horizontal: 8, vertical: 8),
                    ),
                    style: ResponsiveHelper.captionStyle(context),
                    onChanged: (value) {
                      setState(() {
                        _inspectionData.putIfAbsent(category, () => {});
                        _inspectionData[category]!.putIfAbsent(index, () => {});
                        _inspectionData[category]![index]!['notes'] = value;
                      });
                    },
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    itemName,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                // Grade Dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: ResponsiveHelper.safePadding(context, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentGrade.isEmpty ? null : currentGrade,
                        hint: Text(
                          'Grade',
                          style: ResponsiveHelper.captionStyle(context),
                        ),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'excellent',
                            child: Text('Excellent', style: ResponsiveHelper.captionStyle(context)),
                          ),
                          DropdownMenuItem(
                            value: 'good',
                            child: Text('Good', style: ResponsiveHelper.captionStyle(context)),
                          ),
                          DropdownMenuItem(
                            value: 'fair',
                            child: Text('Fair', style: ResponsiveHelper.captionStyle(context)),
                          ),
                          DropdownMenuItem(
                            value: 'poor',
                            child: Text('Poor', style: ResponsiveHelper.captionStyle(context)),
                          ),
                          DropdownMenuItem(
                            value: 'unsatisfactory',
                            child: Text('Unsatisfactory', style: ResponsiveHelper.captionStyle(context)),
                          ),
                          DropdownMenuItem(
                            value: 'not_applicable',
                            child: Text('N/A', style: ResponsiveHelper.captionStyle(context)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _inspectionData.putIfAbsent(category, () => {});
                            _inspectionData[category]!.putIfAbsent(index, () => {});
                            _inspectionData[category]![index]!['grade'] = value ?? '';
                          });
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                // Notes Field
                Expanded(
                  flex: 3,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _getNotesController(category, index, currentNotes),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\x00-\x7F]')), // Only ASCII characters
                      ],
                      decoration: InputDecoration(
                        hintText: 'Notes',
                        hintStyle: ResponsiveHelper.captionStyle(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 8),
                          ),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: ResponsiveHelper.safePadding(context, horizontal: 8, vertical: 8),
                      ),
                      style: ResponsiveHelper.captionStyle(context),
                      onChanged: (value) {
                        setState(() {
                          _inspectionData.putIfAbsent(category, () => {});
                          _inspectionData[category]!.putIfAbsent(index, () => {});
                          _inspectionData[category]![index]!['notes'] = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverallAssessment() {
    final isExpanded = _expandedSections['Overall Assessment'] ?? true;
    
    return Container(
      key: _sectionKeys['Overall Assessment'],
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () {
              _toggleSection('Overall Assessment');
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
              topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            ),
            child: Container(
              padding: ResponsiveHelper.safePadding(context, all: 16),
              decoration: BoxDecoration(
                color: kAccentColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                  topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                ),
                border: Border(left: BorderSide(color: kAccentColor, width: 4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.assessment,
                          color: kAccentColor,
                          size: 24,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          'Overall Assessment',
                          style: ResponsiveHelper.subheadingStyle(context, fontWeight: FontWeight.bold, color: kBlackColor),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: kAccentColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          // Content (shown when expanded)
          if (isExpanded)
            Container(
              padding: ResponsiveHelper.safePadding(context, all: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Grade
                  DropdownButtonFormField<String>(
            value: _overallGrade,
            decoration: InputDecoration(
              labelText: 'Overall Vehicle Grade *',
              labelStyle: TextStyle(color: Colors.black),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 8),
                ),
              ),
              contentPadding: ResponsiveHelper.safePadding(context, horizontal: 12, vertical: 12),
            ),
            style: ResponsiveHelper.bodyStyle(context, color: Colors.black),
            dropdownColor: Colors.white,
            items: [
              DropdownMenuItem(value: 'excellent', child: Text('Excellent', style: ResponsiveHelper.bodyStyle(context, color: Colors.black))),
              DropdownMenuItem(value: 'good', child: Text('Good', style: ResponsiveHelper.bodyStyle(context, color: Colors.black))),
              DropdownMenuItem(value: 'fair', child: Text('Fair', style: ResponsiveHelper.bodyStyle(context, color: Colors.black))),
              DropdownMenuItem(value: 'poor', child: Text('Poor', style: ResponsiveHelper.bodyStyle(context, color: Colors.black))),
              DropdownMenuItem(value: 'unsatisfactory', child: Text('Unsatisfactory', style: ResponsiveHelper.bodyStyle(context, color: Colors.black))),
            ],
            onChanged: (value) {
              setState(() {
                _overallGrade = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select overall grade';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          // Summary
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextFormField(
              controller: _summaryController,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'Inspection Summary *',
                hintText: 'Provide a comprehensive summary of the vehicle\'s condition...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                contentPadding: ResponsiveHelper.safePadding(context, horizontal: 12, vertical: 12),
              ),
              style: ResponsiveHelper.bodyStyle(context),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide inspection summary';
                }
                return null;
              },
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          // Recommendations
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextFormField(
              controller: _recommendationsController,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'Recommendations',
                hintText: 'Provide recommendations for repairs, maintenance...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                contentPadding: ResponsiveHelper.safePadding(context, horizontal: 12, vertical: 12),
              ),
              style: ResponsiveHelper.bodyStyle(context),
              maxLines: 4,
            ),
          ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inspection Photos',
            style: ResponsiveHelper.subheadingStyle(context, color: kBlackColor),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          OutlinedButton.icon(
            onPressed: _pickPhotos,
            icon: Icon(Icons.photo_library, size: ResponsiveHelper.iconSize(context, mobile: 20)),
            label: Text('Upload Photos', style: ResponsiveHelper.bodyStyle(context)),
            style: OutlinedButton.styleFrom(
              padding: ResponsiveHelper.safePadding(context, vertical: 12, horizontal: 16),
            ),
          ),
          if (_selectedPhotos.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'Selected Photos:',
              style: ResponsiveHelper.bodyStyle(context, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 3,
                crossAxisSpacing: ResponsiveHelper.spacing(context, 8),
                mainAxisSpacing: ResponsiveHelper.spacing(context, 8),
              ),
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8),
                      ),
                      child: Image.file(
                        _selectedPhotos[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.red,
                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                        ),
                        onPressed: () => _removePhoto(index),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitSection() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: ResponsiveHelper.safePadding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ready to Submit Inspection Report',
                  style: ResponsiveHelper.subheadingStyle(context),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  'Review all information before submitting the final report.',
                  style: ResponsiveHelper.bodyStyle(context, color: Colors.grey[600]),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: ResponsiveHelper.bodyStyle(context)),
                        style: OutlinedButton.styleFrom(
                          padding: ResponsiveHelper.safePadding(context, vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitInspection,
                        icon: _isSubmitting
                            ? SizedBox(
                                width: ResponsiveHelper.iconSize(context, mobile: 16),
                                height: ResponsiveHelper.iconSize(context, mobile: 16),
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(Icons.check_circle, size: ResponsiveHelper.iconSize(context, mobile: 20)),
                        label: Text('Submit Report', style: ResponsiveHelper.bodyStyle(context)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          padding: ResponsiveHelper.safePadding(context, horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Submit Inspection Report',
                        style: ResponsiveHelper.subheadingStyle(context),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        'Review all information before submitting the final report.',
                        style: ResponsiveHelper.bodyStyle(context, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: ResponsiveHelper.bodyStyle(context)),
                  style: OutlinedButton.styleFrom(
                    padding: ResponsiveHelper.safePadding(context, vertical: 12, horizontal: 16),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitInspection,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: ResponsiveHelper.iconSize(context, mobile: 16),
                          height: ResponsiveHelper.iconSize(context, mobile: 16),
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.check_circle, size: ResponsiveHelper.iconSize(context, mobile: 20)),
                  label: Text('Submit Report', style: ResponsiveHelper.bodyStyle(context)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: ResponsiveHelper.safePadding(context, horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

