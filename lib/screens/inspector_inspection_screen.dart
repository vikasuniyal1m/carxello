import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/inspection_service.dart';

class InspectorInspectionScreen extends StatefulWidget {
  final Car car;
  final String inspectionId;
  final String date;
  final String location;

  const InspectorInspectionScreen({
    super.key,
    required this.car,
    required this.inspectionId,
    required this.date,
    required this.location,
  });

  @override
  State<InspectorInspectionScreen> createState() => _InspectorInspectionScreenState();
}

class _InspectorInspectionScreenState extends State<InspectorInspectionScreen> {
  int _currentStep = 0; // 0: VIN/Document, 1: Upload Data, 2: Report
  final TextEditingController _vinController = TextEditingController();
  bool _vinValidated = false;
  
  // Document checklist
  final Map<String, bool> _documents = {
    'Registration Certificate (RC) copy': false,
    'Valid Insurance PaperWork': false,
    'PUC (Pollution Under Control) Certificate': false,
    'Fitness Certificate': false,
  };

  // Upload Data step
  double _vehicleGrade = 5.0;
  final TextEditingController _notesController = TextEditingController();
  final List<String> _uploadedPhotos = [];

  @override
  void initState() {
    super.initState();
    _vinController.text = widget.car.vin ?? '';
  }

  @override
  void dispose() {
    _vinController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateVIN() {
    if (_vinController.text.isNotEmpty) {
      setState(() {
        _vinValidated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIN validated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && !_vinValidated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please validate VIN first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_currentStep == 0 && _documents.values.every((v) => v)) {
      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      setState(() {
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      _submitReport();
    }
  }

  Future<void> _submitReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Report'),
        content: const Text('Are you sure you want to submit this inspection report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final inspectionService = InspectionService();
      
      // Convert documents map to the format expected by backend
      final documentsStatus = <String, bool>{
        'Registration Certificate (RC) copy': _documents['Registration Certificate (RC) copy'] ?? false,
        'Valid Insurance PaperWork': _documents['Valid Insurance PaperWork'] ?? false,
        'PUC (Pollution Under Control) Certificate': _documents['PUC (Pollution Under Control) Certificate'] ?? false,
        'Fitness Certificate': _documents['Fitness Certificate'] ?? false,
      };

      await inspectionService.submitReport(
        inspectionId: widget.inspectionId,
        vehicleGrade: _vehicleGrade.round(),
        vinVerified: _vinValidated,
        documentsStatus: documentsStatus,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        photoUrls: _uploadedPhotos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inspection Documents and Report',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            height: 180,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/car1.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      'We Deliver the Dream Drive',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 20,
                    right: 20,
                    child: Text(
                      '1/5',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress Steps
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProgressStep('VIN/Document', 0),
                _buildProgressStep('Upload Data', 1),
                _buildProgressStep('Report', 2),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _currentStep == 0
                  ? _buildVINDocumentStep()
                  : _currentStep == 1
                      ? _buildUploadDataStep()
                      : _buildReportStep(),
            ),
          ),
          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_currentStep > 0) {
                        setState(() {
                          _currentStep--;
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_currentStep == 2 ? 'SUBMIT' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String title, int step) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isActive || isCompleted ? Colors.blue : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isActive || isCompleted ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVINDocumentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // VIN Validation
        const Text(
          'VIN Validation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _vinController,
          decoration: InputDecoration(
            hintText: 'Enter VIN',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          enabled: !_vinValidated,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _vinValidated ? null : _validateVIN,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_vinValidated ? 'VIN Verified' : 'Validate VIN'),
          ),
        ),
        const SizedBox(height: 32),
        // Documentation Checklist
        const Text(
          'Documentation Checklist',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._documents.keys.map((doc) => CheckboxListTile(
          title: Text(doc),
          value: _documents[doc],
          onChanged: (value) {
            setState(() {
              _documents[doc] = value ?? false;
            });
          },
          activeColor: Colors.green,
        )),
      ],
    );
  }

  Widget _buildUploadDataStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Your Car Photos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            // Photo upload functionality
            setState(() {
              _uploadedPhotos.add('Photo ${_uploadedPhotos.length + 1}');
            });
          },
          icon: const Icon(Icons.attach_file),
          label: const Text('Choose File'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.teal,
            side: const BorderSide(color: Colors.teal),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_uploadedPhotos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No File Chosen',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        if (_uploadedPhotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_uploadedPhotos.length} file(s) chosen',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Please Upload at least 10 Photos recommended.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
        const SizedBox(height: 32),
        // Vehicle Grading
        const Text(
          'Vehicle Grading (1 - Poor, 10 - Excellent)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Slider(
          value: _vehicleGrade,
          min: 1,
          max: 10,
          divisions: 9,
          label: _vehicleGrade.round().toString(),
          activeColor: Colors.teal,
          onChanged: (value) {
            setState(() {
              _vehicleGrade = value;
            });
          },
        ),
        Center(
          child: Text(
            'Grade: ${_vehicleGrade.round()}/10',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Additional Notes
        const Text(
          'Additional Notes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Write vehicle condition, damage or special remark here.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildReportStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review And Submission',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Final Report Summary',
          style: TextStyle(
            fontSize: 16,
            color: Colors.blue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildReportRow('VIN', widget.car.vin ?? 'N/A'),
        _buildReportRow('VIN Verified', _vinValidated ? 'Yes' : 'No'),
        _buildReportRow('Make Model', '${widget.car.make} ${widget.car.model}'),
        _buildReportRow('Vehicle Grade', '${_vehicleGrade.round()}/10'),
        const SizedBox(height: 16),
        const Text(
          'Document Status:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._documents.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                entry.value ? Icons.check_circle : Icons.circle_outlined,
                color: entry.value ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(entry.key),
            ],
          ),
        )),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Overall Document Status: ${_documents.values.every((v) => v) ? "Complete" : "Incomplete"}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Inspector Notes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _notesController.text.isEmpty
                ? 'No Notes Provided'
                : _notesController.text,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

