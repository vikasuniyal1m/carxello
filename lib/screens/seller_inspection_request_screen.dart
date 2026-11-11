import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/image_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/services/user_service.dart';
import 'package:carauction/screens/view_report_screen.dart';
import 'package:intl/intl.dart';

class SellerInspectionRequestScreen extends StatefulWidget {
  final Car car;

  const SellerInspectionRequestScreen({
    super.key,
    required this.car,
  });

  @override
  State<SellerInspectionRequestScreen> createState() => _SellerInspectionRequestScreenState();
}

class _SellerInspectionRequestScreenState extends State<SellerInspectionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final InspectionService _inspectionService = InspectionService();
  final UserService _userService = UserService();

  DateTime? _selectedDate;
  String? _selectedPriority = 'normal';
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Inspector selection
  String? _selectedInspectorId;
  String? _selectedInspectorName;
  List<Map<String, dynamic>> _availableInspectors = [];
  bool _isLoadingInspectors = false;

  bool _isSubmitting = false;
  bool _hasExistingRequest = false;
  Map<String, dynamic>? _existingRequest;
  String? _inspectionStatus; // Track inspection status
  String? _inspectionId; // Track inspection ID for viewing report

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.car.location;
    _checkExistingRequest();
    _loadAvailableInspectors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload inspection status when screen comes into focus
    // This ensures status updates (e.g., when inspection is completed) are reflected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkExistingRequest();
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
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
      print('⚠️ Failed to load inspectors: $e');
    }
  }

  // Helper method to check if inspection is completed
  bool get _isInspectionCompleted {
    if (!_hasExistingRequest || _inspectionStatus == null) {
      // No existing request or no status – user can submit new request (not an error)
      return false;
    }
    final normalizedStatus = _inspectionStatus!.toString().toLowerCase().trim();
    return normalizedStatus == 'completed';
  }

  Future<void> _checkExistingRequest() async {
    try {
      print('🔍 Checking existing inspection for vehicle: ${widget.car.id}');
      final inspection = await _inspectionService.getVehicleInspection(widget.car.id);
      print('📋 Inspection response: $inspection');

      if (inspection != null && inspection['inspection'] != null) {
        final inspectionData = inspection['inspection'] as Map<String, dynamic>;
        // Normalize status to lowercase for consistent comparison
        final status = inspectionData['status']?.toString().toLowerCase()?.trim();
        print('✅ Found inspection with status: "$status"');

        // Map inspector data properly (backend returns inspector_name, not inspector object)
        final inspectorName = inspectionData['inspector_name']?.toString();
        final inspectorEmail = inspectionData['inspector_email']?.toString();
        final inspectorPhone = inspectionData['inspector_phone']?.toString();

        // Create inspector object for display
        final inspectorData = inspectorName != null ? {
          'name': inspectorName,
          'email': inspectorEmail,
          'phone': inspectorPhone,
        } : null;

        setState(() {
          _hasExistingRequest = true;
          _existingRequest = {
            ...inspectionData,
            'inspector': inspectorData,
          };
          _inspectionStatus = status;
          _inspectionId = inspectionData['id']?.toString();
        });

        // Log the current state
        print('📊 Updated state - hasExistingRequest: $_hasExistingRequest, status: "$_inspectionStatus"');
        print('📊 Inspection ID: $_inspectionId');
        print('📊 Raw status from API: "${inspectionData['status']}"');
        print('📊 Normalized status: "$status"');
        print('📊 Is Completed: ${_isInspectionCompleted}');

        // Force rebuild to ensure UI updates
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                // Force rebuild
              });
            }
          });
        }
      } else {
        print('ℹ️ No inspection found in response');
        setState(() {
          _hasExistingRequest = false;
          _existingRequest = null;
          _inspectionStatus = null;
          _inspectionId = null;
        });
      }
    } catch (e) {
      print('⚠️ Error checking existing inspection: $e');
      // Don't reset state on error - keep existing state
      // Only reset if we're sure there's no inspection
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        setState(() {
          _hasExistingRequest = false;
          _existingRequest = null;
          _inspectionStatus = null;
          _inspectionId = null;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kAccentColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: kBlackColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildVehicleImage() {
    final imageUrl = widget.car.imageUrl;
    final bool isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final bool isAsset = imageUrl.startsWith('assets/');

    if (isNetwork) {
      return Image.network(
        ImageHelper.normalizeImageUrl(imageUrl),
        width: 70, // Pehle 80 tha
        height: 70, // Pehle 80 tha
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/car1.png',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          );
        },
      );
    } else if (isAsset) {
      return Image.asset(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/car1.png',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      final normalizedUrl = ImageHelper.normalizeImageUrl(imageUrl);
      return Image.network(
        normalizedUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/car1.png',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          );
        },
      );
    }
  }

  Future<void> _submitRequest() async {
    // Prevent duplicate requests if inspection is already completed or in progress
    // Normalize status for comparison
    final normalizedStatus = _inspectionStatus?.toString().toLowerCase().trim();

    if (_hasExistingRequest && normalizedStatus != null) {
      if (normalizedStatus == 'completed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This inspection is already completed. Please view the report instead.'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'View Report',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewReportScreen(car: widget.car),
                    ),
                  );
                },
              ),
            ),
          );
        }
        return;
      } else if (normalizedStatus == 'in_progress' || normalizedStatus == 'assigned') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Inspection is already ${_inspectionStatus == 'in_progress' ? 'in progress' : 'assigned'}. Cannot create duplicate request.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _inspectionService.createRequest(
        vehicleId: widget.car.id,
        scheduledDate: _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : null,
        location: _locationController.text.trim(),
        priority: _selectedPriority,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        inspectorId: _selectedInspectorId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18), // Pehle 20 tha
                SizedBox(width: 6), // Pehle 8 tha
                Expanded(
                  child: Text(result['message'] ?? 'Inspection request submitted successfully', style: const TextStyle(fontSize: 14)), // Added
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        await _checkExistingRequest();

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18), // Pehle 20 tha
                SizedBox(width: 6), // Pehle 8 tha
                Expanded(
                  child: Text('Failed to submit: ${e.toString().split(':').last.trim()}', style: const TextStyle(fontSize: 14)), // Added
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
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

  Widget _buildFormCard({required String title, required Widget child, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(context, all: 16), // Pehle 20 tha
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, // Pehle 8 tha
            offset: const Offset(0, 1), // Pehle 0,2 tha
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || title.isNotEmpty) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 6), // Pehle 8 tha
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6), // Pehle 8 tha
                    ),
                    child: Icon(icon, color: kAccentColor, size: ResponsiveHelper.iconSize(context, mobile: 18)), // Pehle 20 tha
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)), // Pehle 12 tha
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 17), // Pehle 16,18 tha
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)), // Pehle 16 tha
          ],
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Request Inspection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18), // Pehle 18,20 tha
          ),
        ),
        centerTitle: false,
        toolbarHeight: 56, // Added for compactness
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveHelper.padding(
            context,
            horizontal: 12, // Pehle 16 tha
            vertical: 16, // Pehle 20 tha
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Info Card - Enhanced
                Container(
                  width: double.infinity,
                  padding: ResponsiveHelper.padding(context, all: 16), // Pehle 20 tha
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kAccentColor.withOpacity(0.05),
                        kAccentColor.withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
                    border: Border.all(color: kAccentColor.withOpacity(0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: kAccentColor.withOpacity(0.1),
                        blurRadius: 8, // Pehle 12 tha
                        offset: const Offset(0, 2), // Pehle 0,4 tha
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8), // Pehle 10 tha
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6, // Pehle 8 tha
                              offset: const Offset(0, 1), // Pehle 0,2 tha
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8), // Pehle 10 tha
                          child: _buildVehicleImage(),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 12)), // Pehle 16 tha
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.car.year} ${widget.car.make} ${widget.car.model}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18), // Pehle 18,20 tha
                                fontWeight: FontWeight.bold,
                                color: kBlackColor,
                                letterSpacing: -0.3, // Pehle -0.5 tha
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 4)), // Pehle 8 tha
                            Row(
                              children: [
                                Icon(Icons.confirmation_number, size: 14, color: Colors.grey[600]), // Pehle 16 tha
                                SizedBox(width: 4), // Pehle 6 tha
                                Flexible(
                                  child: Text(
                                    'VIN: ${widget.car.vin ?? "N/A"}',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13), // Pehle 13,14 tha
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: ResponsiveHelper.spacing(context, 20)), // Pehle 24 tha

                // Existing Request Status Card
                if (_hasExistingRequest && _existingRequest != null)
                  _buildExistingRequestCard(),

                if (_hasExistingRequest && _existingRequest != null && !_isInspectionCompleted)
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Pehle 20 tha

                // If inspection is completed, show View Report button instead of form
                if (_isInspectionCompleted)
                  Container(
                    width: double.infinity,
                    padding: ResponsiveHelper.padding(context, all: 16), // Pehle 20 tha
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
                      border: Border.all(color: Colors.green[300]!, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 24), // Pehle 28 tha
                            SizedBox(width: ResponsiveHelper.spacing(context, 8)), // Pehle 12 tha
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inspection Completed',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18), // Pehle 18,20 tha
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                  SizedBox(height: 2), // Pehle 4 tha
                                  Text(
                                    'You can now view the inspection report',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14), // Pehle 14,15 tha
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 12)), // Pehle 16 tha
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewReportScreen(
                                    car: widget.car,
                                    inspectionId: _inspectionId,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.description, size: 18), // Pehle 20 tha
                            label: Text('View Inspection Report', style: const TextStyle(fontSize: 14)), // Added
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: ResponsiveHelper.padding(context, vertical: 14), // Pehle 16 tha
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Only show form if inspection is not completed
                // Check multiple conditions to ensure form is hidden when completed
                if (!_isInspectionCompleted) ...[

                  // Inspection Details Form Card
                  _buildFormCard(
                    title: 'Inspection Details',
                    icon: Icons.calendar_today,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preferred Date
                        Text(
                          'Preferred Inspection Date',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14), // Pehle 14,15 tha
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)), // Pehle 10 tha
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                          child: Container(
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: 14, // Pehle 16 tha
                              vertical: 14, // Pehle 16 tha
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              border: Border.all(color: Colors.grey[300]!, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: kAccentColor, size: 20), // Pehle 22 tha
                                SizedBox(width: ResponsiveHelper.spacing(context, 8)), // Pehle 12 tha
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                                        : 'Select preferred date',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                                      color: _selectedDate != null ? kBlackColor : Colors.grey[600],
                                      fontWeight: _selectedDate != null ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: Colors.grey[600], size: 22), // Pehle 24 tha
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Pehle 20 tha

                        // Vehicle Location
                        Text(
                          'Vehicle Location',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14), // Pehle 14,15 tha
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)), // Pehle 10 tha
                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            hintText: 'Enter vehicle location (ZIP code)',
                            hintStyle: const TextStyle(fontSize: 14), // Added
                            prefixIcon: Icon(Icons.location_on, color: kAccentColor, size: 20), // Pehle 22 tha
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              borderSide: BorderSide(color: kAccentColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: ResponsiveHelper.padding(
                              context,
                              horizontal: 14, // Pehle 16 tha
                              vertical: 14, // Pehle 16 tha
                            ),
                          ),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter vehicle location';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Pehle 20 tha

                        // Priority
                        Text(
                          'Priority Level',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14), // Pehle 14,15 tha
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)), // Pehle 10 tha
                        DropdownButtonFormField<String>(
                          value: _selectedPriority,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.flag, color: kAccentColor, size: 20), // Pehle 22 tha
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                              borderSide: BorderSide(color: kAccentColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: ResponsiveHelper.padding(
                              context,
                              horizontal: 14, // Pehle 16 tha
                              vertical: 14, // Pehle 16 tha
                            ),
                          ),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                            color: kBlackColor,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'low',
                              child: Row(
                                children: [
                                  Container(
                                    width: 10, // Pehle 12 tha
                                    height: 10, // Pehle 12 tha
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8), // Pehle 12 tha
                                  Text(
                                    'Low Priority',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                                      color: kBlackColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'normal',
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Normal Priority',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15),
                                      color: kBlackColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'High Priority',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15),
                                      color: kBlackColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPriority = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Pehle 20 tha

                  // Inspector Selection Card
                  _buildFormCard(
                    title: 'Inspector Selection',
                    icon: Icons.person_search,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select Inspector (Optional)',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14), // Pehle 14,15 tha
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)), // Pehle 10 tha
                        _isLoadingInspectors
                            ? Container(
                          width: double.infinity,
                          padding: ResponsiveHelper.padding(context, all: 16), // Pehle 20 tha
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18, // Pehle 20 tha
                                  height: 18, // Pehle 20 tha
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 8)), // Pehle 12 tha
                                Text(
                                  'Loading inspectors...',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            : SizedBox(
                          width: double.infinity,
                          child: DropdownButtonFormField<String>(
                            value: _selectedInspectorId,
                            decoration: InputDecoration(
                              hintText: 'Any Available Inspector',
                              hintStyle: const TextStyle(fontSize: 14), // Added
                              prefixIcon: Icon(Icons.person_outline, color: kAccentColor, size: 20), // Pehle 22 tha
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                                borderSide: BorderSide(color: kAccentColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: ResponsiveHelper.padding(
                                context,
                                horizontal: 14, // Pehle 16 tha
                                vertical: 14, // Pehle 16 tha
                              ),
                            ),
                            style: TextStyle(
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Row(
                                  children: [
                                    Icon(Icons.people_outline, size: 16, color: Colors.grey[600]), // Pehle 18 tha
                                    SizedBox(width: 8), // Pehle 10 tha
                                    Text(
                                      'Any Available Inspector',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ..._availableInspectors.map((inspector) {
                                return DropdownMenuItem(
                                  value: inspector['id'].toString(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 28, // Pehle 32 tha
                                        height: 28, // Pehle 32 tha
                                        decoration: BoxDecoration(
                                          color: kAccentColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          size: 16, // Pehle 18 tha
                                          color: kAccentColor,
                                        ),
                                      ),
                                      SizedBox(width: 8), // Pehle 12 tha
                                      Flexible(
                                        child: Text(
                                          inspector['name'] ?? inspector['full_name'] ?? 'Unknown',
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                                            fontWeight: FontWeight.w500,
                                            color: kBlackColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedInspectorId = value;
                                if (value != null) {
                                  final inspector = _availableInspectors.firstWhere(
                                        (i) => i['id'].toString() == value,
                                  );
                                  _selectedInspectorName = inspector['name'] ?? inspector['full_name'];
                                } else {
                                  _selectedInspectorName = null;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Pehle 20 tha

                  // Additional Notes Card
                  _buildFormCard(
                    title: 'Additional Information',
                    icon: Icons.note_outlined,
                    child: TextFormField(
                      controller: _notesController,
                      maxLines: 4, // Pehle 5 tha
                      decoration: InputDecoration(
                        hintText: 'Add any additional information or special requirements...',
                        hintStyle: const TextStyle(fontSize: 14), // Added
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Pehle 10 tha
                          borderSide: BorderSide(color: kAccentColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: ResponsiveHelper.padding(
                          context,
                          all: 14, // Pehle 16 tha
                        ),
                      ),
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15), // Pehle 15,16 tha
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 24)), // Pehle 32 tha

                  // Submit Button - Only show if inspection is NOT completed
                  // Explicit check: hide button if inspection exists and status is 'completed'
                  if (!(_hasExistingRequest == true && _inspectionStatus != null && _inspectionStatus!.toString().toLowerCase().trim() == 'completed'))
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
                        boxShadow: [
                          BoxShadow(
                            color: kAccentColor.withOpacity(0.3),
                            blurRadius: 8, // Pehle 12 tha
                            offset: const Offset(0, 2), // Pehle 0,4 tha
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        icon: _isSubmitting
                            ? SizedBox(
                          width: 20, // Pehle 22 tha
                          height: 20, // Pehle 22 tha
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Icon(
                          Icons.send_rounded,
                          size: ResponsiveHelper.iconSize(context, mobile: 20), // Pehle 22 tha
                        ),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Request', // Pehle 'Submitting Request...' tha
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 17), // Pehle 16,18 tha
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3, // Pehle 0.5 tha
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: ResponsiveHelper.padding(
                            context,
                            horizontal: 20, // Pehle 24 tha
                            vertical: 16, // Pehle 18 tha
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Pehle 20 tha
                ], // End of conditional form display
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingRequestCard() {
    final status = _inspectionStatus ?? 'unknown';
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_empty;
        statusText = 'In Progress';
        break;
      case 'assigned':
        statusColor = Colors.orange;
        statusIcon = Icons.person_add;
        statusText = 'Assigned';
        break;
      case 'pending':
        statusColor = Colors.yellow[700]!;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline;
        statusText = status.toUpperCase();
    }

    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(context, all: 12), // Pehle 16 tha
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)), // Pehle 12 tha
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: ResponsiveHelper.padding(context, all: 6), // Pehle 8 tha
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 18), // Pehle 20 tha
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)), // Pehle 12 tha
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspection Status: $statusText',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14), // Pehle 14,15 tha
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_existingRequest != null && _existingRequest!['inspector'] != null && _existingRequest!['inspector']['name'] != null) ...[
                  SizedBox(height: 2), // Pehle 4 tha
                  Text(
                    'Inspector: ${_existingRequest!['inspector']['name']}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12), // Pehle 12,13 tha
                      color: Colors.grey[700],
                    ),
                  ),
                ] else if (_existingRequest != null && _existingRequest!['inspector_name'] != null) ...[
                  SizedBox(height: 2), // Pehle 4 tha
                  Text(
                    'Inspector: ${_existingRequest!['inspector_name']}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12), // Pehle 12,13 tha
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}