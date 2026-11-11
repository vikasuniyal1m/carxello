/// Model to represent decoded VIN data from NHTSA API
class NHTSAVehicleData {
  final String? make;
  final String? model;
  final int? year;
  final String? bodyClass;
  final String? engineType;
  final String? fuelType;
  final String? driveTrain;
  final String? displacement;
  final String? cylinders;
  final String? transmission;
  final String? trim;
  final String? doors;
  final String? seats;
  final String? gvwr;
  final String? plantCountry;
  final String? plantCity;
  final String? plantState;

  NHTSAVehicleData({
    this.make,
    this.model,
    this.year,
    this.bodyClass,
    this.engineType,
    this.fuelType,
    this.driveTrain,
    this.displacement,
    this.cylinders,
    this.transmission,
    this.trim,
    this.doors,
    this.seats,
    this.gvwr,
    this.plantCountry,
    this.plantCity,
    this.plantState,
  });

  /// Create from JSON map (from API response)
  factory NHTSAVehicleData.fromJson(Map<String, dynamic> json) {
    return NHTSAVehicleData(
      make: json['make']?.toString(),
      model: json['model']?.toString(),
      year: json['year'] != null ? int.tryParse(json['year'].toString()) : null,
      bodyClass: json['body_class']?.toString(),
      engineType: json['engine_type']?.toString(),
      fuelType: json['fuel_type']?.toString(),
      driveTrain: json['drive_train']?.toString(),
      displacement: json['displacement']?.toString(),
      cylinders: json['cylinders']?.toString(),
      transmission: json['transmission']?.toString(),
      trim: json['trim']?.toString(),
      doors: json['doors']?.toString(),
      seats: json['seats']?.toString(),
      gvwr: json['gvwr']?.toString(),
      plantCountry: json['plant_country']?.toString(),
      plantCity: json['plant_city']?.toString(),
      plantState: json['plant_state']?.toString(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'body_class': bodyClass,
      'engine_type': engineType,
      'fuel_type': fuelType,
      'drive_train': driveTrain,
      'displacement': displacement,
      'cylinders': cylinders,
      'transmission': transmission,
      'trim': trim,
      'doors': doors,
      'seats': seats,
      'gvwr': gvwr,
      'plant_country': plantCountry,
      'plant_city': plantCity,
      'plant_state': plantState,
    };
  }

  /// Check if data is valid (has at least make and model)
  bool get isValid => make != null && make!.isNotEmpty && model != null && model!.isNotEmpty;

  @override
  String toString() {
    return 'NHTSAVehicleData(make: $make, model: $model, year: $year, fuelType: $fuelType, driveTrain: $driveTrain)';
  }
}
