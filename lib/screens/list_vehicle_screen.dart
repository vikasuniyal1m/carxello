import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/valuation_service.dart';
import 'package:carauction/services/nhtsa_service.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/models/nhtsa_vehicle_data.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/home_page_controller.dart';

class ListVehicleScreen extends StatefulWidget {
  final Car? car;

  const ListVehicleScreen({super.key, this.car});

  @override
  State<ListVehicleScreen> createState() => _ListVehicleScreenState();
}

class _ListVehicleScreenState extends State<ListVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _vinController = TextEditingController();
  String? _selectedMake;
  String? _selectedModel;
  String? _selectedYear;
  String? _selectedCondition;
  final _exteriorColorController = TextEditingController();
  final _interiorColorController = TextEditingController();
  final _engineTypeController = TextEditingController();
  String? _selectedFuelType;
  String? _selectedDriveTrain;
  String? _selectedEngineType;
  String? _selectedExteriorColor;
  String? _selectedInteriorColor;
  final _mileageController = TextEditingController();
  final _locationZipController = TextEditingController();
  List<File> _selectedImages = [];
  bool _isSubmitting = false;

  // NHTSA Service
  final NHTSAService _nhtsaService = NHTSAService();
  final CarService _carService = CarService();

  // Cache for models
  final Map<String, List<String>> _modelsCache = {};
  final Map<String, List<String>> _modelsCacheByYear = {};

  // Dynamic dropdown options
  List<String> _makeOptions = [];
  List<String> _modelOptions = [];

  // Loading states
  bool _isLoadingMakes = false;
  bool _isDecodingVin = false;
  bool _isLoadingModels = false;

  // Market Valuation states
  double? _marketAverage;
  double? _recommendedPrice;
  bool _isLoadingValuation = false;
  bool _vinDecoded = false;
  Timer? _vinDecodeTimer;

  String? _userRole;
  bool _isEditing = false;
  String? _vehicleId;

  // Vehicle History
  bool _isSmokerVehicle = false;
  bool _hasSalvageTitle = false;
  bool _thirdPartyInspected = false;

  // Seller Disclosure
  bool _sellerDisclosureAccepted = false;
  final _sellerDisclosureController = TextEditingController();

  // Auction Settings
  bool _createAuction = true;
  final _startPriceController = TextEditingController();
  final _minBidIncrementController = TextEditingController(text: '100.00');
  final _buyNowPriceController = TextEditingController();
  final _fixedPriceController = TextEditingController();
  DateTime? _auctionStartTime;
  DateTime? _auctionEndTime;
  String? _selectedAuctionDays;
  final List<String> _auctionDaysOptions = ['1', '3', '7', '14', '30'];

  // Technical Specs
  final _transmissionController = TextEditingController();
  final _trimController = TextEditingController();
  final _bodyStyleController = TextEditingController();
  final _doorsController = TextEditingController();
  final _engineCylindersController = TextEditingController();
  final _displacementLController = TextEditingController();
  final _fuelInjectionController = TextEditingController();
  final _turboController = TextEditingController();
  final _gvwrController = TextEditingController();
  final _plantCityController = TextEditingController();
  final _plantStateController = TextEditingController();
  final _plantCountryController = TextEditingController();
  final _tpmsController = TextEditingController();
  final _brakeSystemController = TextEditingController();
  final _fuelTankCapacityController = TextEditingController();
  final _fuelTankMaterialController = TextEditingController();
  final _fuelTankTypeController = TextEditingController();
  String _expandedSection = 'vehicle_info';
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _vehicleInfoKey = GlobalKey();
  final GlobalKey _vehicleDetailsKey = GlobalKey();
  final GlobalKey _technicalSpecsKey = GlobalKey();
  final GlobalKey _vehicleHistoryKey = GlobalKey();
  final GlobalKey _auctionSettingsKey = GlobalKey();
  bool _buyNowEdited = false;
  String? _lastFixedPriceSynced;
  bool _isSyncingPrices = false;

  // Focus nodes
  final FocusNode _vinFocusNode = FocusNode();
  final FocusNode _mileageFocusNode = FocusNode();
  final FocusNode _locationZipFocusNode = FocusNode();
  final FocusNode _startPriceFocusNode = FocusNode();
  final FocusNode _minBidIncrementFocusNode = FocusNode();
  final FocusNode _buyNowPriceFocusNode = FocusNode();

  // Dropdown Options
  final List<String> _yearOptions = List.generate(
      DateTime.now().year - 1990 + 1,
          (i) => (DateTime.now().year - i).toString()
  );
  final List<String> _conditionOptions = [
    'excellent', 'very_good', 'good', 'fair', 'poor'
  ];
  final List<String> _fuelTypeOptions = [
    'gasoline', 'diesel', 'electric', 'hybrid'
  ];
  final List<String> _driveTrainOptions = [
    'fwd', 'rwd', 'awd', '4wd'
  ];
  final List<String> _transmissionOptions = [
    'Automatic',
    'Manual',
    'CVT',
    'Dual-Clutch',
    'Semi-Automatic',
  ];
  final List<String> _bodyStyleOptions = [
    'Sedan',
    'SUV',
    'Hatchback',
    'Coupe',
    'Convertible',
    'Wagon',
    'Pickup',
    'Van',
    'Minivan',
  ];
  final List<String> _doorOptions = ['2', '3', '4', '5'];
  final List<String> _engineCylinderOptions = ['3', '4', '5', '6', '8', '10', '12'];
  final List<String> _displacementOptions = [
    '1.0',
    '1.2',
    '1.5',
    '1.6',
    '1.8',
    '2.0',
    '2.5',
    '3.0',
    '3.5',
    '4.0',
    '5.0',
    '6.2',
  ];
  final List<String> _fuelInjectionOptions = [
    'Direct Injection',
    'Port Injection',
    'Multi-Point Injection',
    'Throttle Body Injection',
    'Common Rail',
    'Carbureted',
  ];
  final List<String> _turboOptions = ['NA', 'Turbocharged', 'Twin-Turbo', 'Supercharged'];
  final List<String> _gvwrOptions = [
    '< 6000 lbs',
    '6001-7000 lbs',
    '7001-8000 lbs',
    '8001-9000 lbs',
    '9001-10000 lbs',
    '> 10000 lbs',
  ];
  final List<String> _tpmsOptions = ['Direct', 'Indirect', 'Not Equipped'];
  final List<String> _brakeSystemOptions = [
    'ABS',
    'Disc Front / Disc Rear',
    'Disc Front / Drum Rear',
    'Drum',
    'Regenerative + Disc',
  ];
  final List<String> _fuelTankCapacityOptions = [
    '< 40 L',
    '40-49 L',
    '50-59 L',
    '60-69 L',
    '70-79 L',
    '80+ L',
  ];
  final List<String> _fuelTankMaterialOptions = ['Steel', 'Aluminum', 'Plastic (HDPE)', 'Composite'];
  final List<String> _fuelTankTypeOptions = ['Single', 'Dual', 'Saddle'];
  List<String> _engineTypeOptions = [
    'Inline 4', 'Inline 6', 'V6', 'V8', 'V10', 'V12',
    'Flat 4', 'Flat 6', 'W12', 'Rotary', 'Electric',
    'Hybrid', 'Plug-in Hybrid', 'Diesel', 'Turbocharged',
    'Supercharged', 'Twin-Turbo', 'Twin-Supercharged'
  ];
  List<String> _exteriorColorOptions = [];
  List<String> _interiorColorOptions = [];
  bool _isLoadingExteriorColors = false;
  bool _isLoadingInteriorColors = false;

  static const _placeholderOptions = ['Loading...', 'Select make first', 'No models found'];

  @override
  void initState() {
    super.initState();
    _auctionStartTime = DateTime.now();
    _auctionEndTime = DateTime.now().add(const Duration(days: 7));
    _selectedAuctionDays = '7';

    _makeOptions = ['Toyota', 'Honda', 'Ford', 'BMW', 'Mercedes', 'Audi', 'Nissan', 'Chevrolet'];

    _vinController.addListener(_onVinChanged);
    _fixedPriceController.addListener(() {
      if (_isSyncingPrices) return;
      final fixed = _fixedPriceController.text.trim();
      if (!_buyNowEdited || _buyNowPriceController.text.trim().isEmpty || _buyNowPriceController.text.trim() == (_lastFixedPriceSynced ?? '')) {
        _isSyncingPrices = true;
        _buyNowPriceController.text = fixed;
        _lastFixedPriceSynced = fixed;
        _isSyncingPrices = false;
      }
    });
    _buyNowPriceController.addListener(() {
      if (_isSyncingPrices) return;
      final bn = _buyNowPriceController.text.trim();
      if (bn.isNotEmpty && bn != (_lastFixedPriceSynced ?? '')) {
        _buyNowEdited = true;
      }
    });

    PreferencesHelper.getUserRole().then((role) {
      if (mounted) setState(() => _userRole = role?.toLowerCase());
    });

    _loadExteriorColors();
    _loadInteriorColors();

    if (widget.car != null) {
      _isEditing = true;
      _vehicleId = widget.car!.id;
      _loadVehicleData(widget.car!);
    }
  }

  void _loadVehicleData(Car car) {
    setState(() {
      _selectedMake = car.make;
      _selectedModel = car.model;
      _selectedYear = car.year.toString();
      _mileageController.text = car.mileage.toString();
      _vinController.text = _cleanVin(car.vin ?? '');
      _locationZipController.text = car.location;
      _selectedExteriorColor = car.exteriorColor;
      _selectedInteriorColor = car.interiorColor;
      _sellerDisclosureController.text = car.description ?? '';

      if (car.make != null && car.make!.isNotEmpty) {
        _loadModelsForMake(car.make!);
      }

      if (_exteriorColorOptions.isEmpty) {
        _loadExteriorColors();
      }
      if (_interiorColorOptions.isEmpty) {
        _loadInteriorColors();
      }
    });
  }

  @override
  void dispose() {
    _vinDecodeTimer?.cancel();
    _vinController.removeListener(_onVinChanged);
    _vinController.dispose();
    _vinFocusNode.dispose();
    _mileageFocusNode.dispose();
    _locationZipFocusNode.dispose();
    _startPriceFocusNode.dispose();
    _minBidIncrementFocusNode.dispose();
    _buyNowPriceFocusNode.dispose();
    _sellerDisclosureController.dispose();
    _exteriorColorController.dispose();
    _interiorColorController.dispose();
    _engineTypeController.dispose();
    _mileageController.dispose();
    _locationZipController.dispose();
    _startPriceController.dispose();
    _minBidIncrementController.dispose();
    _buyNowPriceController.dispose();
    _fixedPriceController.dispose();
    _transmissionController.dispose();
    _trimController.dispose();
    _bodyStyleController.dispose();
    _doorsController.dispose();
    _engineCylindersController.dispose();
    _displacementLController.dispose();
    _fuelInjectionController.dispose();
    _turboController.dispose();
    _gvwrController.dispose();
    _plantCityController.dispose();
    _plantStateController.dispose();
    _plantCountryController.dispose();
    _tpmsController.dispose();
    _brakeSystemController.dispose();
    _fuelTankCapacityController.dispose();
    _fuelTankMaterialController.dispose();
    _fuelTankTypeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper to check if mandatory field is missing
  bool _isMandatoryFieldMissing(String fieldName) {
    switch (fieldName) {
      case 'vin':
        return _vinController.text.trim().isEmpty;
      case 'make':
        return _selectedMake == null;
      case 'model':
        return _selectedModel == null;
      case 'year':
        return _selectedYear == null;
      case 'price':
        return _fixedPriceController.text.trim().isEmpty;
      default:
        return false;
    }
  }

  bool _canUseValuationForRole() {
    final role = (_userRole ?? '').toLowerCase().trim();
    return role == 'dealer' ||
        role == 'seller' ||
        role == 'individual' ||
        role == 'seller/buyer';
  }

  // Warning banner - sirf mandatory fields
  String? _getMissingFieldWarning() {
    List<String> missing = [];

    if (_isMandatoryFieldMissing('vin')) missing.add('VIN');
    if (_isMandatoryFieldMissing('make')) missing.add('Make');
    if (_isMandatoryFieldMissing('model')) missing.add('Model');
    if (_isMandatoryFieldMissing('year')) missing.add('Year');
    if (_isMandatoryFieldMissing('price')) missing.add('Price');

    if (missing.isEmpty) return null;

    if (missing.length == 1) {
      return '⚠️ Missing: ${missing[0]}';
    } else if (missing.length == 2) {
      return '⚠️ Missing: ${missing[0]} and ${missing[1]}';
    } else {
      return '⚠️ Missing: ${missing.length} required fields';
    }
  }

  void _onVinChanged() {
    final vin = _cleanVin(_vinController.text);

    _vinDecodeTimer?.cancel();

    if (vin.length != 17) {
      setState(() {
        _vinDecoded = false;
        _isDecodingVin = false;
      });
      return;
    }

    if (vin.length == 17 && !_vinDecoded) {
      _vinDecodeTimer = Timer(const Duration(milliseconds: 800), () {
        final currentVin = _cleanVin(_vinController.text);
        if (currentVin.length == 17 && !_vinDecoded) {
          _decodeVin(currentVin);
        }
      });
    }
  }

  Future<void> _decodeVin(String vin) async {
    if (_isDecodingVin) return;

    if (vin.length != 17) return;

    setState(() {
      _isDecodingVin = true;
      _vinDecoded = false;
    });

    try {
      final decodedData = await _nhtsaService.decodeVin(vin);

      if (decodedData != null && decodedData.isNotEmpty) {
        final vehicleData = NHTSAVehicleData.fromJson(decodedData);

        if (vehicleData.isValid) {
          String? decodedMake = vehicleData.make;
          String? decodedModel = vehicleData.model;

          if (decodedMake != null && decodedMake.isNotEmpty) {
            String? foundMake;
            try {
              foundMake = _makeOptions.firstWhere(
                    (make) => make.toUpperCase() == decodedMake.toUpperCase(),
              );
            } catch (e) {
              foundMake = null;
            }

            if (foundMake == null) {
              setState(() {
                _makeOptions.add(decodedMake);
                _makeOptions.sort();
              });
              foundMake = decodedMake;
            }

            setState(() {
              _selectedMake = foundMake;
            });

            _loadModelsForMake(foundMake).then((_) {
              if (mounted && decodedModel != null && decodedModel.isNotEmpty) {
                setState(() {
                  String? foundModel;
                  try {
                    foundModel = _modelOptions.firstWhere(
                          (model) => model.toUpperCase() == decodedModel.toUpperCase(),
                    );
                  } catch (e) {
                    foundModel = null;
                  }

                  if (foundModel != null && foundModel.isNotEmpty) {
                    _selectedModel = foundModel;
                  } else {
                    _selectedModel = decodedModel;
                  }
                });
              }
            });
          }

          if (vehicleData.year != null) {
            setState(() {
              _selectedYear = vehicleData.year.toString();
            });

            if (_selectedMake != null && _selectedMake!.isNotEmpty) {
              _loadModelsForMake(_selectedMake!).then((_) {
                if (mounted && decodedModel != null && decodedModel.isNotEmpty) {
                  setState(() {
                    String? foundModel;
                    try {
                      foundModel = _modelOptions.firstWhere(
                            (model) => model.toUpperCase() == decodedModel.toUpperCase(),
                      );
                    } catch (e) {
                      foundModel = null;
                    }

                    if (foundModel != null && foundModel.isNotEmpty) {
                      _selectedModel = foundModel;
                    } else {
                      _selectedModel = decodedModel;
                    }
                  });
                }
              });
            }

            setState(() {
              if (vehicleData.transmission != null) {
                _transmissionController.text = vehicleData.transmission!;
              }
              if (vehicleData.trim != null) {
                _trimController.text = vehicleData.trim!;
              }
              if (vehicleData.bodyClass != null) {
                _bodyStyleController.text = vehicleData.bodyClass!;
              }
              if (vehicleData.doors != null) {
                _doorsController.text = vehicleData.doors!;
              }
              if (vehicleData.cylinders != null) {
                _engineCylindersController.text = vehicleData.cylinders!;
              }
              if (vehicleData.displacement != null) {
                _displacementLController.text = vehicleData.displacement!;
              }
              if (vehicleData.gvwr != null) {
                _gvwrController.text = vehicleData.gvwr!;
              }
              if (vehicleData.plantCity != null) {
                _plantCityController.text = vehicleData.plantCity!;
              }
              if (vehicleData.plantState != null) {
                _plantStateController.text = vehicleData.plantState!;
              }
              if (vehicleData.plantCountry != null) {
                _plantCountryController.text = vehicleData.plantCountry!;
              }
            });
          } else if (decodedModel != null && decodedModel.isNotEmpty && _modelOptions.isEmpty) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  String? foundModel;
                  try {
                    foundModel = _modelOptions.firstWhere(
                          (model) => model.toUpperCase() == decodedModel.toUpperCase(),
                    );
                  } catch (e) {
                    foundModel = null;
                  }

                  if (foundModel != null && foundModel.isNotEmpty) {
                    _selectedModel = foundModel;
                  } else {
                    _selectedModel = decodedModel;
                  }
                });
              }
            });
          } else if (decodedModel != null && decodedModel.isNotEmpty && _modelOptions.isNotEmpty) {
            setState(() {
              String? foundModel;
              try {
                foundModel = _modelOptions.firstWhere(
                      (model) => model.toUpperCase() == decodedModel.toUpperCase(),
                );
              } catch (e) {
                foundModel = null;
              }

              if (foundModel != null && foundModel.isNotEmpty) {
                _selectedModel = foundModel;
              } else {
                _selectedModel = decodedModel;
              }
            });
          }

          setState(() {
            if (vehicleData.fuelType != null) {
              final fuelTypeLower = vehicleData.fuelType!.toLowerCase();
              if (_fuelTypeOptions.any((f) => f.toLowerCase() == fuelTypeLower)) {
                _selectedFuelType = _fuelTypeOptions.firstWhere(
                      (f) => f.toLowerCase() == fuelTypeLower,
                );
              } else {
                _selectedFuelType = vehicleData.fuelType;
              }
            }

            if (vehicleData.driveTrain != null && vehicleData.driveTrain!.isNotEmpty) {
              final driveTrainLower = vehicleData.driveTrain!.toLowerCase().trim();

              String? matchedDriveTrain;
              try {
                matchedDriveTrain = _driveTrainOptions.firstWhere(
                      (d) => d.toLowerCase().trim() == driveTrainLower,
                );
              } catch (e) {
                try {
                  matchedDriveTrain = _driveTrainOptions.firstWhere(
                        (d) => driveTrainLower.contains(d.toLowerCase().trim()) ||
                        d.toLowerCase().trim().contains(driveTrainLower),
                  );
                } catch (e2) {
                  matchedDriveTrain = driveTrainLower;
                }
              }

              if (matchedDriveTrain != null) {
                _selectedDriveTrain = matchedDriveTrain;
              }
            }

            if (vehicleData.engineType != null && vehicleData.engineType!.isNotEmpty) {
              final decodedEngine = vehicleData.engineType!;
              String? foundEngine;
              try {
                foundEngine = _engineTypeOptions.firstWhere(
                      (e) => e.toLowerCase().trim() == decodedEngine.toLowerCase().trim(),
                );
              } catch (e) {
                foundEngine = null;
              }
              if (foundEngine == null) {
                _engineTypeOptions.add(decodedEngine);
                _engineTypeOptions = _engineTypeOptions.toSet().toList();
                _engineTypeOptions.sort();
                foundEngine = decodedEngine;
              }
              _selectedEngineType = foundEngine;
            }

            _vinDecoded = true;
            _isDecodingVin = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('VIN decoded successfully! Vehicle details auto-filled.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          setState(() {
            _isDecodingVin = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('VIN decoded but incomplete data. Please fill remaining fields manually.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        setState(() {
          _isDecodingVin = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not decode VIN. Please enter vehicle details manually.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isDecodingVin = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error decoding VIN: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadModelsForMake(String make) async {
    if (make.isEmpty) {
      setState(() {
        _modelOptions = [];
        _selectedModel = null;
      });
      return;
    }

    String? cacheKey;
    if (_selectedYear != null) {
      final year = int.tryParse(_selectedYear!);
      if (year != null) {
        cacheKey = '$make-$year';
        if (_modelsCacheByYear.containsKey(cacheKey)) {
          setState(() {
            _modelOptions = _modelsCacheByYear[cacheKey]!;
            _isLoadingModels = false;
          });
          return;
        }
      }
    }

    if ((cacheKey == null || cacheKey.isEmpty) && _modelsCache.containsKey(make)) {
      setState(() {
        _modelOptions = _modelsCache[make]!;
        _isLoadingModels = false;
      });
      _fetchModelsInBackground(make);
      return;
    }

    setState(() {
      _isLoadingModels = true;
      _modelOptions = [];
      _selectedModel = null;
    });

    try {
      if (_selectedYear != null) {
        final year = int.tryParse(_selectedYear!);
        if (year != null) {
          final models = await _nhtsaService.getModelsForMakeYear(make, year);
          _modelsCacheByYear[cacheKey!] = models;

          setState(() {
            _modelOptions = models;
            if (!models.contains(_selectedModel)) _selectedModel = null;
            _isLoadingModels = false;
          });
          return;
        }
      }

      final models = await _nhtsaService.getModelsForMake(make);
      _modelsCache[make] = models;

      setState(() {
        _modelOptions = models;
        if (!models.contains(_selectedModel)) _selectedModel = null;
        _isLoadingModels = false;
      });
    } catch (e) {
      setState(() {
        _modelOptions = [];
        _selectedModel = null;
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _fetchModelsInBackground(String make) async {
    try {
      if (_selectedYear != null) {
        final year = int.tryParse(_selectedYear!);
        if (year != null) {
          final models = await _nhtsaService.getModelsForMakeYear(make, year);
          _modelsCacheByYear['$make-$year'] = models;
          if (_selectedMake == make && mounted) {
            setState(() {
              _modelOptions = models;
              if (!models.contains(_selectedModel)) _selectedModel = null;
            });
          }
          return;
        }
      }

      final models = await _nhtsaService.getModelsForMake(make);
      _modelsCache[make] = models;
      if (_selectedMake == make && mounted) {
        setState(() {
          _modelOptions = models;
          if (!models.contains(_selectedModel)) _selectedModel = null;
        });
      }
    } catch (e) {
      print('⚠️ Background fetch failed: $e');
    }
  }

  Future<void> _loadExteriorColors() async {
    if (_isLoadingExteriorColors || _exteriorColorOptions.isNotEmpty) return;
    if (!mounted) return;

    setState(() => _isLoadingExteriorColors = true);

    try {
      final colors = await _nhtsaService.getExteriorColors();
      if (!mounted) return;
      setState(() {
        _exteriorColorOptions = colors;
        _isLoadingExteriorColors = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingExteriorColors = false;
        if (_exteriorColorOptions.isEmpty) {
          _exteriorColorOptions = ['Black', 'White', 'Silver', 'Gray', 'Red', 'Blue'];
        }
      });
    }
  }

  Future<void> _loadInteriorColors() async {
    if (_isLoadingInteriorColors || _interiorColorOptions.isNotEmpty) return;
    if (!mounted) return;

    setState(() => _isLoadingInteriorColors = true);

    try {
      final colors = await _nhtsaService.getInteriorColors();
      if (!mounted) return;
      setState(() {
        _interiorColorOptions = colors;
        _isLoadingInteriorColors = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInteriorColors = false;
        if (_interiorColorOptions.isEmpty) {
          _interiorColorOptions = ['Black', 'Gray', 'Beige', 'Tan', 'Brown', 'Cream'];
        }
      });
    }
  }

  Future<void> _getMarketValuation() async {
    final vinClean = _cleanVin(_vinController.text);
    final hasVehicleBasics = (_selectedMake?.isNotEmpty ?? false) &&
        (_selectedModel?.isNotEmpty ?? false) &&
        (_selectedYear?.isNotEmpty ?? false);
    if (vinClean.length != 17 && !hasVehicleBasics) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter valid VIN or select make/model/year first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingValuation = true;
      _marketAverage = null;
      _recommendedPrice = null;
    });

    try {
      final result = await ValuationService().getValuation(
        vin: vinClean.length == 17 ? vinClean : null,
        make: _selectedMake,
        model: _selectedModel,
        year: int.tryParse(_selectedYear ?? ''),
        mileage: int.tryParse(_mileageController.text.trim().replaceAll(RegExp(r'[^0-9]'), '')),
        condition: _selectedCondition,
        zipcode: _locationZipController.text.trim().isNotEmpty ? _locationZipController.text.trim() : null,
      );

      if (mounted) {
        final marketAvgObj = result['average'] ?? result['internal'];
        final marketAvg = marketAvgObj != null ? (marketAvgObj['retail'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final sourcesCount = result['average'] != null ? (result['average']['sources_count'] as int? ?? 1) : 1;

        if (marketAvg > 0) {
          final recommended = (result['recommended_price'] as num?)?.toDouble() ?? (marketAvg * 0.95);

          setState(() {
            _marketAverage = marketAvg;
            _recommendedPrice = recommended;
            _isLoadingValuation = false;
          });

          final message = sourcesCount > 1
              ? 'Market valuation found from $sourcesCount sources!'
              : 'Market valuation found!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() => _isLoadingValuation = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] as String? ?? 'Vehicle not found in database. Please enter estimated value manually.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.fixed,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingValuation = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get market valuation: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  bool _validateForm({bool saveAsDraft = false}) {
    return true;
  }

  void _onSectionTap(String section) {
    setState(() {
      _expandedSection = _expandedSection == section ? '' : section;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _keyForSection(section);
      final ctx = key.currentContext;
      if (ctx != null) {
        final renderObject = ctx.findRenderObject();
        if (renderObject != null) {
          final viewport = RenderAbstractViewport.of(renderObject);
          if (viewport != null && _scrollController.hasClients) {
            final offset = viewport.getOffsetToReveal(renderObject, 0.0).offset;
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
            return;
          }
        }
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    });
  }

  GlobalKey _keyForSection(String section) {
    switch (section) {
      case 'vehicle_info':
        return _vehicleInfoKey;
      case 'vehicle_details':
        return _vehicleDetailsKey;
      case 'technical_specs':
        return _technicalSpecsKey;
      case 'vehicle_history':
        return _vehicleHistoryKey;
      case 'auction_settings':
        return _auctionSettingsKey;
      default:
        return _vehicleInfoKey;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFiles.isNotEmpty) {
      final remainingSlots = 10 - _selectedImages.length;
      final filesToAdd = pickedFiles.take(remainingSlots).map((file) => File(file.path)).toList();

      setState(() {
        if (_selectedImages.isEmpty) {
          _selectedImages = filesToAdd;
        } else {
          _selectedImages.addAll(filesToAdd);
        }
      });

      if (pickedFiles.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only ${remainingSlots} photos added. Maximum 10 photos allowed.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _pickSingleImage() async {
    if (_selectedImages.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 10 photos allowed. Please remove a photo first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitForm({bool saveAsDraft = false}) async {
    if (!saveAsDraft) {
      final vinForSubmit = _cleanVin(_vinController.text);
      if (vinForSubmit.length != 17) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('VIN must be exactly 17 characters long'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.fixed,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final carService = CarService();

      final vinForSubmit = _cleanVin(_vinController.text);
      final priceValue = _fixedPriceController.text.trim().isNotEmpty
          ? double.tryParse(_fixedPriceController.text.trim()) ?? 0
          : 0;
      final buyNowValue = _buyNowPriceController.text.trim().isNotEmpty
          ? double.tryParse(_buyNowPriceController.text.trim()) ?? priceValue
          : priceValue;

      final vehicleData = {
        'vin': vinForSubmit,
        'make': _selectedMake!,
        'model': _selectedModel!,
        'year': int.parse(_selectedYear!),
        'price': priceValue,
        'buyNowPrice': buyNowValue,
        'condition': _selectedCondition,
        'exterior_color': _selectedExteriorColor ?? _exteriorColorController.text.trim(),
        'interior_color': _selectedInteriorColor ?? _interiorColorController.text.trim(),
        'engine_type': _selectedEngineType ?? _engineTypeController.text.trim(),
        'fuel_type': _selectedFuelType,
        'drive_train': _selectedDriveTrain,
        'mileage': _mileageController.text.isNotEmpty ? int.parse(_mileageController.text) : 0,
        'location_zip': _locationZipController.text.trim(),
        'is_smoker_vehicle': _isSmokerVehicle,
        'has_salvage_title': _hasSalvageTitle,
        'third_party_inspected': _thirdPartyInspected,
        'description': _sellerDisclosureController.text.trim().isEmpty ? null : _sellerDisclosureController.text.trim(),
        'transmission': _transmissionController.text.trim().isEmpty ? null : _transmissionController.text.trim(),
        'trim': _trimController.text.trim().isEmpty ? null : _trimController.text.trim(),
        'body_style': _bodyStyleController.text.trim().isEmpty ? null : _bodyStyleController.text.trim(),
        'doors': _doorsController.text.trim().isNotEmpty ? int.tryParse(_doorsController.text.trim()) : null,
        'engine_cylinders': _engineCylindersController.text.trim().isEmpty ? null : _engineCylindersController.text.trim(),
        'displacement_l': _displacementLController.text.trim().isEmpty ? null : _displacementLController.text.trim(),
        'fuel_injection': _fuelInjectionController.text.trim().isEmpty ? null : _fuelInjectionController.text.trim(),
        'turbo': _turboController.text.trim().isEmpty ? null : _turboController.text.trim(),
        'gvwr': _gvwrController.text.trim().isEmpty ? null : _gvwrController.text.trim(),
        'plant_city': _plantCityController.text.trim().isEmpty ? null : _plantCityController.text.trim(),
        'plant_state': _plantStateController.text.trim().isEmpty ? null : _plantStateController.text.trim(),
        'plant_country': _plantCountryController.text.trim().isEmpty ? null : _plantCountryController.text.trim(),
        'tpms': _tpmsController.text.trim().isEmpty ? null : _tpmsController.text.trim(),
        'brake_system': _brakeSystemController.text.trim().isEmpty ? null : _brakeSystemController.text.trim(),
        'fuel_tank_capacity': _fuelTankCapacityController.text.trim().isEmpty ? null : _fuelTankCapacityController.text.trim(),
        'fuel_tank_material': _fuelTankMaterialController.text.trim().isEmpty ? null : _fuelTankMaterialController.text.trim(),
        'fuel_tank_type': _fuelTankTypeController.text.trim().isEmpty ? null : _fuelTankTypeController.text.trim(),
      };

      if (saveAsDraft) {
        vehicleData['status'] = 'draft';
      }

      if (_createAuction) {
        vehicleData['create_auction'] = 'yes';
        if (_startPriceController.text.isNotEmpty) {
          vehicleData['start_price'] = double.parse(_startPriceController.text);
        }
        if (_minBidIncrementController.text.isNotEmpty) {
          vehicleData['min_bid_increment'] = double.parse(_minBidIncrementController.text);
        }
        if (_buyNowPriceController.text.isNotEmpty) {
          vehicleData['buy_now_price'] = double.parse(_buyNowPriceController.text);
        }
        final days = int.tryParse(_selectedAuctionDays ?? '7') ?? 7;
        vehicleData['auction_days'] = days;
      }

      if (_selectedImages.isEmpty && !_isEditing && !saveAsDraft) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one vehicle photo'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final imagePaths = _selectedImages.map((file) => file.path).toList();

      if (_isEditing && _vehicleId != null) {
        await carService.updateVehicle(_vehicleId!, vehicleData);
      } else {
        await carService.createVehicle(
          vehicleData,
          imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: kAccentColor, size: 24),
                const SizedBox(width: 8),
                const Text('Success!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              saveAsDraft
                  ? 'Draft saved! You can edit and publish it later from My Listings.'
                  : (_isEditing ? 'Vehicle listing updated successfully!' : 'Vehicle listing submitted successfully!'),
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            const Text('Processing...', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  );

                  try {
                    final homeController = Get.find<HomePageController>();
                    await homeController.toggleBuyerSeller(false);
                    homeController.updateSelectedSellerTab(0);
                    await homeController.fetchSellerDashboardData();
                  } catch (e) {
                    print('⚠️ HomePageController not found: $e');
                  }

                  navigator.pop();
                  navigator.popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      enableScroll: false,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 56,
        title: Text(
          _isEditing ? 'Edit Listing' : 'List Vehicle',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Warning Banner - sirf mandatory fields
              if (!_isSubmitting && _getMissingFieldWarning() != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getMissingFieldWarning()!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kAccentColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kAccentColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Create New Listing',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: kBlackColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fill in all details to list your vehicle',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Content
                      _buildVehicleForm(),
                      const SizedBox(height: 20),

                      // Seller Disclosure
                      _buildSellerDisclosure(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Submit Buttons
              _buildSubmitButton(),
              const SizedBox(height: 8),
              _buildSaveAsDraftButton(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Information Section
          Container(
            key: _vehicleInfoKey,
            child: InkWell(
              onTap: () => _onSectionTap('vehicle_info'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.info_outline, color: kAccentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vehicle Information',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                  Icon(
                    _expandedSection == 'vehicle_info' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kAccentColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Visibility(
            visible: _expandedSection == 'vehicle_info',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // VIN (mandatory - red highlight)
                _buildTextField(
                  'VIN *',
                  'Enter 17-character VIN',
                  _vinController,
                  Icons.qr_code_scanner,
                  maxLength: 17,
                  required: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
                  focusNode: _vinFocusNode,
                  nextFocus: _mileageFocusNode,
                  suffixIcon: _isDecodingVin
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
                    ),
                  )
                      : null,
                  fieldName: 'vin',
                ),
                const SizedBox(height: 12),

                // Make (mandatory - red highlight)
                _buildDropdownField(
                  'Make *',
                  _selectedMake,
                  _makeOptions,
                  Icons.directions_car,
                      (value) {
                    setState(() {
                      _selectedMake = value;
                      if (value != null) {
                        _loadModelsForMake(value);
                      } else {
                        _modelOptions = [];
                        _selectedModel = null;
                      }
                    });
                  },
                  required: true,
                  enabled: true,
                  fieldName: 'make',
                ),
                const SizedBox(height: 12),



                // Year (mandatory - red highlight)
                _buildDropdownField(
                  'Year *',
                  _selectedYear,
                  _yearOptions,
                  Icons.calendar_today,
                      (value) {
                    setState(() => _selectedYear = value);
                    if (_selectedMake != null && _selectedMake!.isNotEmpty && value != null) {
                      _loadModelsForMake(_selectedMake!);
                    }
                  },
                  required: true,
                  fieldName: 'year',
                ),
                const SizedBox(height: 12),

                // Model (mandatory - red highlight)
                _buildDropdownField(
                  'Model *',
                  _selectedModel,
                  _isLoadingModels
                      ? ['Loading...']
                      : (_selectedMake == null || _selectedMake!.isEmpty
                      ? ['Select make first']
                      : _modelOptions.isEmpty
                      ? ['No models found']
                      : _modelOptions),
                  Icons.category,
                      (value) => setState(() => _selectedModel = value),
                  required: true,
                  enabled: !_isLoadingModels && _selectedMake != null && _selectedMake!.isNotEmpty && _modelOptions.isNotEmpty && !_modelOptions.contains('Loading...') && !_modelOptions.contains('Select make first'),
                  fieldName: 'model',
                ),
                const SizedBox(height: 12),

                // Trim (optional - normal)
                _buildTextField(
                  'Trim',
                  'Enter trim (e.g. Lariat, SE)',
                  _trimController,
                  Icons.style,
                ),
                const SizedBox(height: 12),

                // Price (mandatory - red highlight)
                _buildTextField(
                  'Price (\$) *',
                  'Enter Fixed Price',
                  _fixedPriceController,
                  Icons.attach_money,
                  keyboardType: TextInputType.number,
                  required: true,
                  fieldName: 'price',
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter a price or click "Get Valuation" for market-based suggestions',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),

                // Get Valuation / CARFAX
                if (_canUseValuationForRole()) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingValuation ? null : _getMarketValuation,
                              icon: _isLoadingValuation
                                  ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : Icon(Icons.calculate, size: 16),
                              label: Text(
                                _isLoadingValuation ? 'Loading...' : 'Get Valuation',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_marketAverage != null && _recommendedPrice != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Market Average: \$${_formatNumber(_marketAverage!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '💡 ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Recommended: \$${_formatNumber(_recommendedPrice!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _buyNowPriceController.text = _recommendedPrice!.toStringAsFixed(0);
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Use',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Tooltip(
                    message: 'Market valuation is available for Seller/Dealer/Individual accounts',
                    child: Text(
                      'Valuation (Seller/Dealer/Individual)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Condition (optional - normal)
                _buildDropdownField(
                  'Vehicle Condition',
                  _selectedCondition != null
                      ? _selectedCondition!.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')
                      : null,
                  _conditionOptions.map((c) => c.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')).toList(),
                  Icons.build,
                      (value) {
                    setState(() {
                      final index = _conditionOptions.indexWhere((c) => c.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ') == value);
                      _selectedCondition = index >= 0 ? _conditionOptions[index] : null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle Details Section
          Container(
            key: _vehicleDetailsKey,
            child: InkWell(
              onTap: () => _onSectionTap('vehicle_details'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.details, color: kAccentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vehicle Details',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                  Icon(
                    _expandedSection == 'vehicle_details' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kAccentColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Visibility(
            visible: _expandedSection == 'vehicle_details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exterior Color (optional - normal)
                _buildDropdownField(
                  'Exterior Color',
                  _selectedExteriorColor,
                  _isLoadingExteriorColors
                      ? ['Loading...']
                      : _exteriorColorOptions.isEmpty
                      ? ['Loading...']
                      : _exteriorColorOptions,
                  Icons.color_lens,
                      (value) {
                    setState(() {
                      _selectedExteriorColor = value;
                    });
                  },
                  enabled: !_isLoadingExteriorColors && _exteriorColorOptions.isNotEmpty,
                ),
                const SizedBox(height: 12),

                // Interior Color (optional - normal)
                _buildDropdownField(
                  'Interior Color',
                  _selectedInteriorColor,
                  _isLoadingInteriorColors
                      ? ['Loading...']
                      : _interiorColorOptions.isEmpty
                      ? ['Loading...']
                      : _interiorColorOptions,
                  Icons.palette,
                      (value) {
                    setState(() {
                      _selectedInteriorColor = value;
                    });
                  },
                  enabled: !_isLoadingInteriorColors && _interiorColorOptions.isNotEmpty,
                ),
                const SizedBox(height: 12),

                // Engine Type (optional - normal)
                _buildDropdownField(
                  'Engine Type',
                  _selectedEngineType != null
                      ? _selectedEngineType!
                      : null,
                  _engineTypeOptions,
                  Icons.engineering,
                      (value) {
                    setState(() {
                      _selectedEngineType = value;
                    });
                  },
                  enabled: true,
                ),
                const SizedBox(height: 12),

                // Fuel Type (optional - normal)
                _buildDropdownField(
                  'Fuel Type',
                  _selectedFuelType != null
                      ? _selectedFuelType![0].toUpperCase() + _selectedFuelType!.substring(1)
                      : null,
                  _fuelTypeOptions.map((f) => f[0].toUpperCase() + f.substring(1)).toList(),
                  Icons.local_gas_station,
                      (value) {
                    setState(() {
                      final index = _fuelTypeOptions.indexWhere((f) => f[0].toUpperCase() + f.substring(1) == value);
                      _selectedFuelType = index >= 0 ? _fuelTypeOptions[index] : null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Drive Train (optional - normal)
                _buildDropdownField(
                  'Drive Train',
                  _selectedDriveTrain != null
                      ? _selectedDriveTrain!.toUpperCase()
                      : null,
                  _driveTrainOptions.map((d) => d.toUpperCase()).toList(),
                  Icons.settings,
                      (value) {
                    setState(() {
                      final index = _driveTrainOptions.indexWhere((d) => d.toUpperCase() == value);
                      _selectedDriveTrain = index >= 0 ? _driveTrainOptions[index] : null;
                    });
                  },
                  enabled: true,
                ),
                const SizedBox(height: 12),

                // Mileage (optional - normal)
                _buildTextField(
                  'Mileage',
                  'Enter mileage',
                  _mileageController,
                  Icons.speed,
                  keyboardType: TextInputType.number,
                  focusNode: _mileageFocusNode,
                  nextFocus: _locationZipFocusNode,
                ),
                const SizedBox(height: 12),

                // Location ZIP (optional - normal)
                _buildTextField(
                  'Location ZIP',
                  'Enter ZIP code',
                  _locationZipController,
                  Icons.location_on,
                  focusNode: _locationZipFocusNode,
                  nextFocus: _startPriceFocusNode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Technical Specs Section
          Container(
            key: _technicalSpecsKey,
            child: InkWell(
              onTap: () => _onSectionTap('technical_specs'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.settings_suggest, color: kAccentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Technical Specs',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                  Icon(
                    _expandedSection == 'technical_specs' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kAccentColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: _expandedSection == 'technical_specs',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControllerDropdownField(
                  'Transmission',
                  _transmissionController,
                  _transmissionOptions,
                  Icons.swap_horiz,
                ),
                const SizedBox(height: 8),
                _buildTextField('Trim', 'e.g. Sport, EX, Limited', _trimController, Icons.style),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Body Style',
                  _bodyStyleController,
                  _bodyStyleOptions,
                  Icons.directions_car,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Doors',
                  _doorsController,
                  _doorOptions,
                  Icons.meeting_room,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Engine Cylinders',
                  _engineCylindersController,
                  _engineCylinderOptions,
                  Icons.view_week,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Displacement (L)',
                  _displacementLController,
                  _displacementOptions,
                  Icons.straighten,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Fuel Injection',
                  _fuelInjectionController,
                  _fuelInjectionOptions,
                  Icons.electrical_services,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Turbo',
                  _turboController,
                  _turboOptions,
                  Icons.blur_on,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'GVWR',
                  _gvwrController,
                  _gvwrOptions,
                  Icons.scale,
                ),
                const SizedBox(height: 8),
                _buildTextField('Plant City', 'Manufacturing plant city', _plantCityController, Icons.location_city),
                const SizedBox(height: 8),
                _buildTextField('Plant State', 'Manufacturing plant state', _plantStateController, Icons.map),
                const SizedBox(height: 8),
                _buildTextField('Plant Country', 'Manufacturing plant country', _plantCountryController, Icons.public),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'TPMS',
                  _tpmsController,
                  _tpmsOptions,
                  Icons.tire_repair,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Brake System',
                  _brakeSystemController,
                  _brakeSystemOptions,
                  Icons.car_repair,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Fuel Tank Capacity',
                  _fuelTankCapacityController,
                  _fuelTankCapacityOptions,
                  Icons.invert_colors,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Fuel Tank Material',
                  _fuelTankMaterialController,
                  _fuelTankMaterialOptions,
                  Icons.category,
                ),
                const SizedBox(height: 8),
                _buildControllerDropdownField(
                  'Fuel Tank Type',
                  _fuelTankTypeController,
                  _fuelTankTypeOptions,
                  Icons.local_gas_station,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle History Section
          Container(
            key: _vehicleHistoryKey,
            child: InkWell(
              onTap: () => _onSectionTap('vehicle_history'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.history, color: kAccentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vehicle History',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                  Icon(
                    _expandedSection == 'vehicle_history' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kAccentColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: _expandedSection == 'vehicle_history',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCheckboxField(
                  'Smoker Vehicle',
                  _isSmokerVehicle,
                      (value) => setState(() => _isSmokerVehicle = value ?? false),
                  Icons.smoking_rooms,
                ),
                const SizedBox(height: 8),
                _buildCheckboxField(
                  'Red Light/Salvage Title',
                  _hasSalvageTitle,
                      (value) => setState(() => _hasSalvageTitle = value ?? false),
                  Icons.warning,
                ),
                const SizedBox(height: 8),
                _buildCheckboxField(
                  'Third Party Inspected',
                  _thirdPartyInspected,
                      (value) => setState(() => _thirdPartyInspected = value ?? false),
                  Icons.verified,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Auction Settings Section
          Container(
            key: _auctionSettingsKey,
            child: InkWell(
              onTap: () => _onSectionTap('auction_settings'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.gavel, color: kAccentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Auction Settings',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                  Icon(
                    _expandedSection == 'auction_settings' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kAccentColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buy Now Price will auto-use the Price entered above.',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: _expandedSection == 'auction_settings',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Create Auction Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _createAuction,
                      onChanged: (value) => setState(() => _createAuction = value ?? true),
                      activeColor: kAccentColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Create auction for this vehicle',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_createAuction) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Start Price (\$)',
                    'Enter start price',
                    _startPriceController,
                    Icons.attach_money,
                    keyboardType: TextInputType.number,
                    focusNode: _startPriceFocusNode,
                    nextFocus: _minBidIncrementFocusNode,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Minimum Bid Increment (\$)',
                    'Enter minimum bid increment',
                    _minBidIncrementController,
                    Icons.trending_up,
                    keyboardType: TextInputType.number,
                    focusNode: _minBidIncrementFocusNode,
                    nextFocus: _buyNowPriceFocusNode,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Buy Now Price (\$)',
                    'Buy now price',
                    _buyNowPriceController,
                    Icons.shopping_cart,
                    keyboardType: TextInputType.number,
                    focusNode: _buyNowPriceFocusNode,
                  ),
                  const SizedBox(height: 12),
                  _buildDateTimeField(
                    'Auction Start Time *',
                    _auctionStartTime ?? DateTime.now(),
                    Icons.access_time,
                        (dateTime) => setState(() => _auctionStartTime = dateTime),
                  ),
                  const SizedBox(height: 12),
                  _buildDateTimeField(
                    'Auction End Time *',
                    _auctionEndTime ?? DateTime.now().add(const Duration(days: 7)),
                    Icons.event,
                        (dateTime) => setState(() => _auctionEndTime = dateTime),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownFieldWithDisplay(
                    'Or Select Duration (Days)',
                    _selectedAuctionDays,
                    _auctionDaysOptions,
                        (d) => '$d Day${d == '1' ? '' : 's'}',
                    Icons.calendar_today,
                        (value) {
                      setState(() {
                        final days = int.tryParse(value ?? '7') ?? 7;
                        _selectedAuctionDays = days.toString();
                        _auctionEndTime = (_auctionStartTime ?? DateTime.now()).add(Duration(days: days));
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Image Upload Section
          _buildImageUploadSection(),
        ],
      ),
    );
  }

  Widget _buildSellerDisclosure() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: kAccentColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Seller Disclosure',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'I confirm that the information provided about this vehicle is accurate to the best of my knowledge. '
                'I have disclosed any known defects, accident history, or title issues. '
                'I understand that misrepresentation may result in cancellation of the listing or other actions.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Additional disclosure (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mention tyre condition, overall condition, known faults, scratches, or any other details buyers should know.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _sellerDisclosureController,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'e.g. Tyres 70% life, minor scratch on rear bumper, AC needs recharge...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: BorderSide(color: kAccentColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              counterStyle: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _sellerDisclosureAccepted,
                onChanged: (value) => setState(() => _sellerDisclosureAccepted = value ?? false),
                activeColor: kAccentColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'I accept the Seller Disclosure',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kBlackColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool isDraft = _isEditing && (widget.car?.status == 'draft');
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () => _submitForm(saveAsDraft: false),
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                isDraft
                    ? 'Publish Listing'
                    : (_isEditing ? 'Update Listing' : 'List Vehicle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveAsDraftButton() {
    return Container(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => _submitForm(saveAsDraft: true),
        style: OutlinedButton.styleFrom(
          foregroundColor: kAccentColor,
          side: BorderSide(color: kAccentColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_alt, size: 18),
            const SizedBox(width: 6),
            Text(
              _isEditing && widget.car?.status == 'draft' ? 'Update Draft' : 'Save as Draft',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kAccentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.photo_library, color: kAccentColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vehicle Photos',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
            ),
            Text(
              '(${_selectedImages.length}/10)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_selectedImages.isEmpty)
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[600]),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to add photos',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Max 10 photos',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_selectedImages.length == 1)
          _buildSinglePhotoExpanded(context)
        else
          _buildMultiplePhotosCompact(context),
      ],
    );
  }

  Widget _buildSinglePhotoExpanded(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Image.file(
                  _selectedImages[0],
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () => _removeImage(0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_selectedImages.length < 10)
          InkWell(
            onTap: _pickSingleImage,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 24, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Add more photos (${_selectedImages.length}/10)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMultiplePhotosCompact(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int columns = 3;
    if (width >= 1000) {
      columns = 5;
    } else if (width >= 700) {
      columns = 4;
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: _selectedImages.length + (_selectedImages.length < 10 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _selectedImages.length) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  _selectedImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 10),
                  ),
                ),
              ),
            ],
          );
        } else {
          return InkWell(
            onTap: _pickImage,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Center(
                child: Icon(Icons.add, size: 24, color: Colors.grey[600]),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> options, IconData icon,
      Function(String?) onChanged, {bool required = false, bool enabled = true, String? fieldName}) {

    final bool isPlaceholderList = options.length == 1 && _placeholderOptions.contains(options.first);
    final String? effectiveValue = isPlaceholderList ? null : (value != null && options.contains(value) ? value : null);
    final List<String> uniqueOptions = isPlaceholderList ? options : options.toSet().toList();
    final isMissing = fieldName != null && _isMandatoryFieldMissing(fieldName);

    final List<DropdownMenuItem<String?>> items = isPlaceholderList
        ? [DropdownMenuItem<String?>(value: null, child: Text(uniqueOptions.first, style: const TextStyle(fontSize: 13)))]
        : uniqueOptions.map((option) {
      return DropdownMenuItem<String?>(
        value: option,
        child: Text(
          option,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontSize: 13),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isMissing ? Colors.red[700] : kAccentColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isMissing ? Colors.red[700] : kBlackColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 2),
              Text('*', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.grey[50] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMissing ? Colors.red[300]! : Colors.grey[300]!,
              width: isMissing ? 2 : 1,
            ),
          ),
          child: DropdownButtonFormField<String?>(
            value: effectiveValue,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select ${label.replaceAll('*', '').trim()}',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(icon, color: isMissing ? Colors.red[400] : Colors.grey[600], size: 18),
              suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
            ),
            items: items,
            onChanged: enabled ? onChanged : null,
            style: TextStyle(color: enabled ? kBlackColor : Colors.grey[600], fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildControllerDropdownField(
    String label,
    TextEditingController controller,
    List<String> options,
    IconData icon, {
    bool required = false,
    bool enabled = true,
  }) {
    final rawValue = controller.text.trim();
    final merged = <String>[...options];
    if (rawValue.isNotEmpty && !merged.contains(rawValue)) {
      merged.insert(0, rawValue);
    }
    return _buildDropdownField(
      label,
      rawValue.isEmpty ? null : rawValue,
      merged,
      icon,
      (value) {
        controller.text = value ?? '';
      },
      required: required,
      enabled: enabled,
    );
  }

  Widget _buildDropdownFieldWithDisplay(String label, String? value, List<String> options,
      String Function(String) displayFormatter, IconData icon, Function(String?) onChanged, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kAccentColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kBlackColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 2),
              Text('*', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select ${label.replaceAll('*', '').trim()}',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(icon, color: Colors.grey[600], size: 18),
              suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  displayFormatter(option),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            style: const TextStyle(color: kBlackColor, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxField(String label, bool value, Function(bool?) onChanged, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kAccentColor),
        const SizedBox(width: 6),
        Expanded(
          child: CheckboxListTile(
            title: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kBlackColor,
              ),
            ),
            value: value,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: kAccentColor,
            dense: true,
          ),
        ),
      ],
    );
  }

  String _cleanVin(String vin) {
    return vin.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, IconData icon,
      {TextInputType? keyboardType, bool required = false, int? maxLength, Widget? suffixIcon,
        List<TextInputFormatter>? inputFormatters, TextCapitalization textCapitalization = TextCapitalization.none,
        FocusNode? focusNode, FocusNode? nextFocus, String? fieldName}) {

    final useNext = nextFocus != null;
    final isMissing = fieldName != null && _isMandatoryFieldMissing(fieldName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isMissing ? Colors.red[700] : kAccentColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isMissing ? Colors.red[700] : kBlackColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 2),
              Text('*', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          textInputAction: useNext ? TextInputAction.next : TextInputAction.done,
          onSubmitted: useNext ? (_) => FocusScope.of(context).requestFocus(nextFocus!) : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: Icon(icon, color: isMissing ? Colors.red[400] : Colors.grey[600], size: 18),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isMissing ? Colors.red[300]! : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isMissing ? Colors.red[300]! : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kAccentColor, width: 2),
            ),
            filled: true,
            fillColor: isMissing ? Colors.red[50] : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            counterText: maxLength != null ? null : '',
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDateTimeField(String label, DateTime initialDate, IconData icon, Function(DateTime) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kAccentColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kBlackColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(initialDate),
              );
              if (time != null) {
                final dateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                onChanged(dateTime);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(initialDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final us = _toUsEastern(dateTime);
    final month = us.month.toString().padLeft(2, '0');
    final day = us.day.toString().padLeft(2, '0');
    final year = us.year;
    final minute = us.minute.toString().padLeft(2, '0');
    final amPm = us.hour >= 12 ? 'PM' : 'AM';
    final displayHour = us.hour > 12 ? us.hour - 12 : (us.hour == 0 ? 12 : us.hour);
    return '$month/$day/$year ${displayHour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  DateTime _toUsEastern(DateTime dt) {
    final utc = dt.toUtc();
    final year = utc.year;
    final dstStart = _secondSundayOfMonth(year, 3, 2);
    final dstEnd = _firstSundayOfMonth(year, 11, 2);
    final isDst = utc.isAfter(dstStart) && utc.isBefore(dstEnd);
    final offsetHours = isDst ? -4 : -5;
    return utc.add(Duration(hours: offsetHours));
  }

  DateTime _firstSundayOfMonth(int year, int month, int hour) {
    final firstDay = DateTime.utc(year, month, 1, hour);
    final weekday = firstDay.weekday;
    final addDays = (DateTime.sunday - weekday) % 7;
    return firstDay.add(Duration(days: addDays));
  }

  DateTime _secondSundayOfMonth(int year, int month, int hour) {
    final first = _firstSundayOfMonth(year, month, hour);
    return first.add(const Duration(days: 7));
  }
}