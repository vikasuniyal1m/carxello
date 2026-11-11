class Car {
  final String id;
  final String make;
  final String model;
  final int year;
  final String imageUrl;
  final double startingBid;
  final double buyNowPrice;
  final int mileage;
  final String location;
  final String distance;
  final DateTime auctionEndTime;
  final String status; // Added status property
  final String? vin;
  final double? wonAmount;
  final String? transportStatus;
  final String? expectedDeliveryDate;
  final String? invoiceNumber;
  final String? titleStatus;
  final String? inspectionStatus;
  final String? swapOfferStatus;
  final String? description;
  final String? lastMatch;
  final int? currentMatches;
  final bool? alerts;
  final double? price;
  final String? purchaseMethod; // 'bidding', 'buy_now', 'swap'
  final double? purchaseAmount;
  final String? sellerId; // Seller's user ID for chat
  final String? sellerName; // Seller's name for chat
  final String? contactPhone; // Seller's contact phone number
  final String? contactEmail; // Seller's contact email
  final List<Map<String, dynamic>>? photos; // Vehicle photos from backend
  final double? currentBid; // Current highest bid amount
  final String? exteriorColor; // Exterior color
  final String? interiorColor; // Interior color
  final String? condition; // Vehicle condition
  final String? engineType; // Engine type
  final String? fuelType; // Fuel type
  final String? driveTrain; // Drive train
  final bool? hasInspectionRequest; // True if someone raised an inspection request for this vehicle (seller view)
  final String? auctionEndTimeDisplay; // Display-friendly ET string from backend
  final bool? hasAuction;
  /// Seller disclosure / history (from listing form)
  final bool? isSmokerVehicle;
  final bool? hasRedLightOrSalvage;
  final bool? thirdPartyInspected;
  final bool isFeatured;

  bool get isEndingSoon => auctionEndTime.difference(DateTime.now()).inHours < 24 && auctionEndTime.isAfter(DateTime.now());

  Car({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.imageUrl,
    required this.startingBid,
    required this.buyNowPrice,
    required this.mileage,
    required this.location,
    required this.distance,
    required this.auctionEndTime,
    required this.status, // Added status to constructor
    this.vin,
    this.wonAmount,
    this.transportStatus,
    this.expectedDeliveryDate,
    this.invoiceNumber,
    this.titleStatus,
    this.inspectionStatus,
    this.swapOfferStatus,
    this.description,
    this.lastMatch,
    this.currentMatches,
    this.alerts,
    this.price,
    this.purchaseMethod,
    this.purchaseAmount,
    this.sellerId,
    this.sellerName,
    this.contactPhone,
    this.contactEmail,
    this.photos,
    this.currentBid,
    this.exteriorColor,
    this.interiorColor,
    this.condition,
    this.engineType,
    this.fuelType,
    this.driveTrain,
    this.hasInspectionRequest,
    this.auctionEndTimeDisplay,
    this.hasAuction,
    this.isSmokerVehicle,
    this.hasRedLightOrSalvage,
    this.thirdPartyInspected,
    this.isFeatured = false,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      imageUrl: json['imageUrl'],
      startingBid: (json['hasAuction'] == true)
          ? (json['startingBid'] as num?)?.toDouble() ?? 0.0
          : 0.0,
      buyNowPrice: (json['buyNowPrice'] as num?)?.toDouble() ?? 0.0,
      mileage: json['mileage'],
      location: json['location'],
      distance: json['distance'],
      auctionEndTime: (json['hasAuction'] == true && json['auctionEndTime'] != null)
        ? DateTime.parse(json['auctionEndTime'])
        : DateTime.now(),
      status: json['status'] ?? 'draft', // Default to 'draft' if status is null
      vin: json['vin'],
      wonAmount: json['wonAmount']?.toDouble(),
      transportStatus: json['transportStatus'],
      expectedDeliveryDate: json['expectedDeliveryDate'],
      invoiceNumber: json['invoiceNumber'],
      titleStatus: json['titleStatus'],
      inspectionStatus: json['inspectionStatus'],
      swapOfferStatus: json['swapOfferStatus'],
      description: json['description'],
      lastMatch: json['lastMatch'],
      currentMatches: json['currentMatches'] is int 
        ? json['currentMatches'] 
        : (json['currentMatches'] as num?)?.toInt(),
      alerts: json['alerts'] == null 
        ? null 
        : (json['alerts'] is bool 
          ? json['alerts'] as bool
          : (json['alerts'] is int 
            ? (json['alerts'] as int) != 0 
            : (json['alerts'] as num?)?.toInt() != 0)),
      price: json['price']?.toDouble(),
      purchaseMethod: json['purchase_method'],
      purchaseAmount: json['purchase_amount']?.toDouble(),
      sellerId: json['sellerId']?.toString(),
      sellerName: json['sellerName'],
      contactPhone: json['contactPhone'] ?? json['contact_phone'],
      contactEmail: json['contactEmail'] ?? json['contact_email'],
      photos: json['photos'] != null
        ? List<Map<String, dynamic>>.from(json['photos'])
        : null,
      currentBid: (json['currentBid'] as num?)?.toDouble() ?? 
                  (json['current_bid'] as num?)?.toDouble() ??
                  (json['highest_bid'] as num?)?.toDouble(),
      exteriorColor: json['exteriorColor'] ?? json['exterior_color'],
      interiorColor: json['interiorColor'] ?? json['interior_color'],
      condition: json['condition'],
      engineType: json['engineType'] ?? json['engine_type'],
      fuelType: json['fuelType'] ?? json['fuel_type'],
      driveTrain: json['driveTrain'] ?? json['drive_train'],
      hasInspectionRequest: json['has_inspection_request'] == true || json['hasInspectionRequest'] == true,
      auctionEndTimeDisplay: json['auctionEndTimeDisplay'] ?? json['auction_end_time_display'],
      hasAuction: json['hasAuction'] == true,
      isSmokerVehicle: json['is_smoker_vehicle'] == true || json['is_smoker'] == true,
      hasRedLightOrSalvage:
          json['has_red_light'] == true || json['has_salvage_title'] == true,
      thirdPartyInspected:
          json['third_party_inspected'] == true || json['is_third_party_inspected'] == true,
      isFeatured: json['is_featured'] == true || json['isFeatured'] == true || json['is_featured'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'imageUrl': imageUrl,
      'startingBid': startingBid,
      'buyNowPrice': buyNowPrice,
      'mileage': mileage,
      'location': location,
      'distance': distance,
      'auctionEndTime': auctionEndTime.toIso8601String(),
      'status': status, // Added status to toJson
      'vin': vin,
      'wonAmount': wonAmount,
      'transportStatus': transportStatus,
      'expectedDeliveryDate': expectedDeliveryDate,
      'invoiceNumber': invoiceNumber,
      'titleStatus': titleStatus,
      'inspectionStatus': inspectionStatus,
      'swapOfferStatus': swapOfferStatus,
      'description': description,
      'lastMatch': lastMatch,
      'currentMatches': currentMatches,
      'alerts': alerts,
      'price': price,
      'purchase_method': purchaseMethod,
      'purchase_amount': purchaseAmount,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'photos': photos,
      'exteriorColor': exteriorColor,
      'interiorColor': interiorColor,
      'condition': condition,
      'engineType': engineType,
      'fuelType': fuelType,
      'driveTrain': driveTrain,
      'auctionEndTimeDisplay': auctionEndTimeDisplay,
      'hasAuction': hasAuction,
      'is_featured': isFeatured,
    };
  }
}
