import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/dispute_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/models/car.dart';

class CreateDisputeScreen extends StatefulWidget {
  final String? vehicleId;

  const CreateDisputeScreen({super.key, this.vehicleId});

  @override
  State<CreateDisputeScreen> createState() => _CreateDisputeScreenState();
}

class _CreateDisputeScreenState extends State<CreateDisputeScreen> {
  final DisputeService _service = DisputeService();
  final CarService _carService = CarService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedVehicleId;
  String _selectedType = 'vehicle_condition';
  List<Car> _myVehicles = [];
  bool _isLoadingVehicles = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _disputeTypes = [
    {'value': 'vehicle_condition', 'label': 'Vehicle Condition'},
    {'value': 'payment_issue', 'label': 'Payment Issue'},
    {'value': 'delivery_problem', 'label': 'Delivery Problem'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
    _loadMyVehicles();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMyVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final cars = await _carService.fetchCars();
      setState(() {
        _myVehicles = cars.where((car) => car.status == 'sold').toList();
        _isLoadingVehicles = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingVehicles = false;
      });
    }
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _service.createDispute(
        vehicleId: _selectedVehicleId!,
        disputeType: _selectedType,
        description: _descriptionController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispute created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create dispute: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: const Text('Create Dispute'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Selection
              const Text(
                'Select Vehicle *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingVehicles
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedVehicleId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _myVehicles.map((car) {
                        return DropdownMenuItem(
                          value: car.id,
                          child: Text('${car.year} ${car.make} ${car.model}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedVehicleId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a vehicle';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 24),
              // Dispute Type
              const Text(
                'Dispute Type *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _disputeTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              // Description
              const Text(
                'Description *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Describe your dispute in detail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dispute description';
                  }
                  if (value.length < 20) {
                    return 'Description must be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDispute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Dispute',
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
}

