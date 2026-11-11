class SavedSearch {
  final String id;
  final String searchName;
  final String? make;
  final String? model;
  final int? yearFrom;
  final int? yearTo;
  final double? priceMin;
  final double? priceMax;
  final int? maxMileage;
  final String? condition;
  final String? zipCode;
  final int? searchRadius; // in miles
  final bool enableEmailAlerts;
  final String alertFrequency; // 'Immediate', 'Daily', 'Weekly'
  final DateTime createdAt;
  final String? lastMatch;
  final int currentMatches;

  SavedSearch({
    required this.id,
    required this.searchName,
    this.make,
    this.model,
    this.yearFrom,
    this.yearTo,
    this.priceMin,
    this.priceMax,
    this.maxMileage,
    this.condition,
    this.zipCode,
    this.searchRadius,
    this.enableEmailAlerts = false,
    this.alertFrequency = 'Immediate',
    required this.createdAt,
    this.lastMatch,
    this.currentMatches = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'searchName': searchName,
      'make': make,
      'model': model,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'maxMileage': maxMileage,
      'condition': condition,
      'zipCode': zipCode,
      'searchRadius': searchRadius,
      'enableEmailAlerts': enableEmailAlerts,
      'alertFrequency': alertFrequency,
      'createdAt': createdAt.toIso8601String(),
      'lastMatch': lastMatch,
      'currentMatches': currentMatches,
    };
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'],
      searchName: json['searchName'],
      make: json['make'],
      model: json['model'],
      yearFrom: json['yearFrom'],
      yearTo: json['yearTo'],
      priceMin: json['priceMin']?.toDouble(),
      priceMax: json['priceMax']?.toDouble(),
      maxMileage: json['maxMileage'],
      condition: json['condition'],
      zipCode: json['zipCode'],
      searchRadius: json['searchRadius'],
      enableEmailAlerts: json['enableEmailAlerts'] ?? false,
      alertFrequency: json['alertFrequency'] ?? 'Immediate',
      createdAt: DateTime.parse(json['createdAt']),
      lastMatch: json['lastMatch'],
      currentMatches: json['currentMatches'] ?? 0,
    );
  }

  // Helper method to get a description string
  String getDescription() {
    final parts = <String>[];
    if (make != null && make!.isNotEmpty && make != 'Any Make') {
      parts.add(make!);
    }
    if (model != null && model!.isNotEmpty && model != 'Any Model') {
      parts.add(model!);
    }
    if (yearFrom != null || yearTo != null) {
      final yearStr = yearFrom != null && yearTo != null
          ? '$yearFrom-$yearTo'
          : yearFrom != null
              ? '$yearFrom+'
              : 'Up to $yearTo';
      parts.add('Year $yearStr');
    }
    return parts.isEmpty ? searchName : parts.join(', ');
  }
}

