import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/car.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class CarService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    print('🔑 CarService: Getting headers...');
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      print('   ✅ Token found: ${token.substring(0, 20)}...');
    } else {
      print('   ⚠️ No token found');
    }
    
    return headers;
  }

  /// Helper method to map backend field names to Flutter model field names
  Map<String, dynamic> _mapBackendToFlutterFields(Map<String, dynamic> item) {
    final mappedItem = Map<String, dynamic>.from(item);
    
    // Field name mapping (Second SQL structure ke according)
    if (mappedItem.containsKey('fixed_price')) {
      mappedItem['buyNowPrice'] = mappedItem['fixed_price'];
    }
    if (mappedItem.containsKey('opening_bid')) {
      mappedItem['startingBid'] = mappedItem['opening_bid'];
    }
    if (mappedItem.containsKey('image_url')) {
      mappedItem['imageUrl'] = mappedItem['image_url'];
    }
    if (mappedItem.containsKey('auction_end_time')) {
      mappedItem['auctionEndTime'] = mappedItem['auction_end_time'];
    }
    // Also support old field names (backward compatibility)
    if (!mappedItem.containsKey('buyNowPrice') && mappedItem.containsKey('buy_now_price')) {
      mappedItem['buyNowPrice'] = mappedItem['buy_now_price'];
    }
    if (!mappedItem.containsKey('startingBid') && mappedItem.containsKey('starting_bid')) {
      mappedItem['startingBid'] = mappedItem['starting_bid'];
    }
    if (!mappedItem.containsKey('imageUrl') && mappedItem.containsKey('image_url')) {
      mappedItem['imageUrl'] = mappedItem['image_url'];
    }
    
    // Ensure status field exists with default value
    if (!mappedItem.containsKey('status') || mappedItem['status'] == null) {
      mappedItem['status'] = 'draft';
    }
    
    return mappedItem;
  }

  /// Helper method to map Flutter field names to backend field names
  Map<String, dynamic> _mapFlutterToBackendFields(Map<String, dynamic> data) {
    final mappedData = Map<String, dynamic>.from(data);
    
    // Map startingBid to opening_bid
    if (mappedData.containsKey('startingBid')) {
      mappedData['opening_bid'] = mappedData.remove('startingBid');
    }
    
    // Map buyNowPrice to fixed_price
    if (mappedData.containsKey('buyNowPrice')) {
      mappedData['fixed_price'] = mappedData.remove('buyNowPrice');
    }
    
    // Map location to location_zip (database column name)
    if (mappedData.containsKey('location')) {
      mappedData['location_zip'] = mappedData.remove('location');
    }
    
    // Remove distance - this column doesn't exist in database
    mappedData.remove('distance');
    
    // Also keep old field names for backward compatibility
    if (mappedData.containsKey('starting_bid') && !mappedData.containsKey('opening_bid')) {
      mappedData['opening_bid'] = mappedData['starting_bid'];
      mappedData.remove('starting_bid');
    }
    if (mappedData.containsKey('buy_now_price') && !mappedData.containsKey('fixed_price')) {
      mappedData['fixed_price'] = mappedData['buy_now_price'];
      mappedData.remove('buy_now_price');
    }
    
    return mappedData;
  }

  /// Get a single vehicle by ID
  Future<Car?> getVehicleById(String id) async {
    try {
      print('🚗 CarService.getVehicleById: Starting...');
      print('   📍 URL: $_baseUrl/vehicles/$id');
      
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mappedData = _mapBackendToFlutterFields(data);
        return Car.fromJson(mappedData);
      } else if (response.statusCode == 404) {
        print('   ⚠️ Vehicle not found: $id');
        return null;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to fetch vehicle: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching vehicle by ID: $e');
      throw Exception('Failed to fetch vehicle: $e');
    }
  }

  Future<List<Car>> fetchCars({Map<String, dynamic>? filters, String? sortBy}) async {
    try {
      print('🚗 CarService.fetchCars: Starting...');
      print('   📍 URL: $_baseUrl/cars');
      print('   🔍 Filters: $filters');
      print('   📊 Sort: $sortBy');
      
      final headers = await _getHeaders();
      
      // Build query parameters
      final uri = Uri.parse('$_baseUrl/cars');
      final queryParams = <String, String>{};
      
      // Add filters to query params
      if (filters != null) {
        // Year filters
        if (filters['year_min'] != null) {
          queryParams['year_min'] = filters['year_min'].toString();
        }
        if (filters['year_max'] != null) {
          queryParams['year_max'] = filters['year_max'].toString();
        }
        
        // Make and Model
        if (filters['make'] != null) {
          queryParams['make'] = filters['make'];
        }
        if (filters['model'] != null) {
          queryParams['model'] = filters['model'];
        }
        
        // Price filters
        if (filters['price_min'] != null) {
          queryParams['price_min'] = filters['price_min'].toString();
        }
        if (filters['price_max'] != null) {
          queryParams['price_max'] = filters['price_max'].toString();
        }
        
        // Odometer/Mileage filters
        if (filters['odometer_min'] != null) {
          queryParams['odometer_min'] = filters['odometer_min'].toString();
        }
        if (filters['odometer_max'] != null) {
          queryParams['odometer_max'] = filters['odometer_max'].toString();
        }
        
        // Fuel Type
        if (filters['fuel_type'] != null) {
          queryParams['fuel_type'] = filters['fuel_type'];
        }
        
        // Exterior Color
        if (filters['exterior_color'] != null) {
          queryParams['exterior_color'] = filters['exterior_color'];
        }
        
        // Interior Color
        if (filters['interior_color'] != null) {
          queryParams['interior_color'] = filters['interior_color'];
        }
        
        // Drive Train
        if (filters['drive_train'] != null) {
          queryParams['drive_train'] = filters['drive_train'];
        }
        
        // Location Zip
        if (filters['location_zip'] != null) {
          queryParams['location_zip'] = filters['location_zip'];
        }

        // Radius around the zip code (if backend supports it)
        if (filters['radius'] != null) {
          queryParams['radius'] = filters['radius'].toString();
        }

        // Spread / Book Value filters (if backend supports it)
        if (filters['spread'] != null) {
          queryParams['spread'] = filters['spread'].toString();
        }
        if (filters['max_book_value'] != null) {
          queryParams['max_book_value'] = filters['max_book_value'].toString();
        }
        if (filters['book_value'] != null) {
          queryParams['book_value'] = filters['book_value'].toString();
        }
        
        // Checkbox filters
        if (filters['exclude_reviewed'] == true) {
          queryParams['exclude_reviewed'] = '1';
        }
        if (filters['exclude_smokers'] == true) {
          queryParams['exclude_smokers'] = '1';
        }
        if (filters['exclude_red_light'] == true) {
          queryParams['exclude_red_light'] = '1';
        }
        if (filters['third_party_inspected'] == true) {
          queryParams['third_party_inspected'] = '1';
        }
        if (filters['opening_price_100'] == true) {
          queryParams['opening_price_100'] = '1';
        }
        if (filters['new_reduced_price'] == true) {
          queryParams['new_reduced_price'] = '1';
        }
        if (filters['exclude_my_postings'] == true) {
          queryParams['exclude_my_postings'] = '1';
        }
        if (filters['include_my_listings'] == true) {
          queryParams['include_my_listings'] = '1';
        }
      }
      
      // Add sort parameter
      if (sortBy != null && sortBy.isNotEmpty) {
        // Map frontend sort options to backend format
        final sortMap = {
          'Price: Low to High': 'price_low_high',
          'Price: High to Low': 'price_high_low',
          'Year: Newest First': 'year_newest',
          'Year: Oldest First': 'year_oldest',
        };
        queryParams['sort_by'] = sortMap[sortBy] ?? 'newest';
      }
      
      final uriWithParams = uri.replace(queryParameters: queryParams);
      
      print('🔗 CarService: Fetching cars from: $uriWithParams');
      print('   📤 Headers: ${headers.keys.join(", ")}');
      
      final response = await http.get(
        uriWithParams,
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('   ⏱️ TIMEOUT: Request took more than 30 seconds');
          throw Exception('Connection timeout. Server may be unreachable. Please check your network connection.');
        },
      );
      
      print('📡 CarService: Response Status: ${response.statusCode}');
      print('   📦 Response Body Length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        List<Car> cars = body.map((dynamic item) {
          final mappedItem = _mapBackendToFlutterFields(item as Map<String, dynamic>);
          return Car.fromJson(mappedItem);
        }).toList();
        print('   ✅ CarService: Successfully fetched ${cars.length} cars');
        return cars;
      } else {
        print('   ❌ CarService: Failed with status ${response.statusCode}');
        print('   📄 Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        throw Exception('Failed to load cars: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ CarService: Exception occurred: $e');
      throw Exception('Failed to load cars: $e');
    }
  }

  /// Create vehicle with multiple photos (matching sell-a-car.php)
  Future<Map<String, dynamic>> createVehicle(
    Map<String, dynamic> vehicleData, {
    List<String>? imagePaths, // Changed from single imagePath to list
  }) async {
    try {
      print('🚗 CarService: Creating vehicle...');
      print('   📋 Vehicle data: ${vehicleData.keys.join(", ")}');
      print('   📸 Photos: ${imagePaths?.length ?? 0}');
      
      final token = await _authService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Always use multipart request (even without photos) for consistency
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/vehicles'),
      );
      
      // Add headers
      request.headers.addAll(headers);
      
      // Field name mapping: Flutter field names ko backend field names mein convert karo
      final mappedData = _mapFlutterToBackendFields(vehicleData);
      
      // Add vehicle data fields (convert to strings, matching sell-a-car.php)
      mappedData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });
      
      print('   🔧 create_auction: ${request.fields['create_auction'] ?? 'no'}');
      print('   🔧 auction_days: ${request.fields['auction_days'] ?? 'N/A'}');
      print('   🔧 start_price: ${request.fields['start_price'] ?? 'N/A'}');
      
      // Add multiple photo files (like sell-a-car.php)
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (int i = 0; i < imagePaths.length; i++) {
          final imagePath = imagePaths[i];
          if (imagePath.isNotEmpty && 
              imagePath != 'assets/images/car1.png' && 
              File(imagePath).existsSync()) {
            try {
              var file = await http.MultipartFile.fromPath('photos[]', imagePath);
              request.files.add(file);
              print('   ✅ Added photo $i: $imagePath');
            } catch (e) {
              print('   ⚠️ Failed to add photo $i: $e');
              // Continue with other photos
            }
          }
        }
      }
      
      print('   📤 Sending request with ${request.files.length} photos...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('   📡 Response Status: ${response.statusCode}');
      print('   📦 Response Body: ${response.body}');
      
      if (response.statusCode == 201) {
        final result = json.decode(response.body);
        print('   ✅ Vehicle created successfully');
        try {
          final vehicleInfo = result['vehicle'] as Map<String, dynamic>? ?? {};
          final vid = vehicleInfo['id']?.toString() ?? '';
          if (vid.isNotEmpty) {
            print('   🔎 Fetching uploaded photos for vehicle: $vid');
            try {
              final photosRes = await http.get(
                Uri.parse('$_baseUrl/vehicles/$vid/photos'),
                headers: headers,
              );
              if (photosRes.statusCode == 200) {
                final photosData = json.decode(photosRes.body) as Map<String, dynamic>;
                final photos = (photosData['photos'] as List<dynamic>? ?? []);
                print('   🖼️ Photos count: ${photos.length}');
                for (int i = 0; i < photos.length; i++) {
                  final p = photos[i] as Map<String, dynamic>;
                  final raw = p['photo_url']?.toString() ?? '';
                  print('      [$i] raw: $raw');
                }
              } else {
                print('   ⚠️ Failed to fetch photos: ${photosRes.statusCode}');
              }
            } catch (e) {
              print('   ⚠️ Error fetching photos: $e');
            }
          }
        } catch (e) {
          print('   ⚠️ Post-create logging failed: $e');
        }
        return result;
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? 'Failed to create vehicle: ${response.statusCode}';
        print('   ❌ Error: $errorMessage');
        if (errorBody['errors'] != null) {
          print('   📋 Validation errors: ${errorBody['errors']}');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('   ❌ Exception: $e');
      if (e.toString().contains('Failed to create vehicle')) {
        rethrow;
      }
      throw Exception('Failed to create vehicle: $e');
    }
  }

  Future<List<Car>> getMyListings() async {
    try {
      print('🏪 ========================================');
      print('🏪 CarService.getMyListings: Starting...');
      print('🏪 ========================================');
      print('   📍 URL: $_baseUrl/vehicles/my-listings');
      final headers = await _getHeaders();
      print('   📤 Headers: ${headers.keys.join(", ")}');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/my-listings'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('   ⏱️ TIMEOUT: Request took more than 30 seconds');
          throw Exception('Connection timeout');
        },
      );

      print('📡 CarService.getMyListings: Response Status: ${response.statusCode}');
      print('   📦 Response Body Length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        print('   📋 Parsed ${body.length} listings from response');
        print('   📊 Raw data sample (first 3):');
        for (int i = 0; i < (body.length > 3 ? 3 : body.length); i++) {
          final item = body[i] as Map<String, dynamic>;
          print('      ${i + 1}. ID: ${item['id']}, Status: ${item['status']}, Make: ${item['make']}, Model: ${item['model']}');
        }
        
        List<Car> cars = [];
        for (var item in body) {
          try {
            final mappedItem = _mapBackendToFlutterFields(item as Map<String, dynamic>);
            final car = Car.fromJson(mappedItem);
            cars.add(car);
          } catch (e) {
            print('   ⚠️ Error parsing listing item: $e');
            print('   📄 Item data: $item');
          }
        }
        
        print('   ✅ CarService.getMyListings: Successfully parsed ${cars.length} listings');
        print('   📊 Final parsed listings:');
        for (var car in cars) {
          print('      - ID: ${car.id}, Status: ${car.status}, Make: ${car.make}, Model: ${car.model}');
        }
        print('🏪 ========================================');
        return cars;
      } else {
        print('   ❌ CarService.getMyListings: Failed with status ${response.statusCode}');
        print('   📄 Response: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        throw Exception('Failed to load listings: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ CarService.getMyListings: Exception occurred: $e');
      throw Exception('Failed to load listings: $e');
    }
  }

  Future<Map<String, dynamic>> updateVehicle(String id, Map<String, dynamic> vehicleData) async {
    try {
      final headers = await _getHeaders();
      
      // Field name mapping: Flutter field names ko backend field names mein convert karo
      final mappedData = _mapFlutterToBackendFields(vehicleData);
      
      final response = await http.put(
        Uri.parse('$_baseUrl/vehicles/$id'),
        headers: headers,
        body: json.encode(mappedData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update vehicle: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update vehicle: $e');
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/vehicles/$id'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete vehicle: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  Future<void> archiveVehicle(String id) async {
    try {
      final headers = await _getHeaders();
      // Using PATCH or POST depending on backend convention, assuming PATCH /archive
      final response = await http.post(
        Uri.parse('$_baseUrl/vehicles/$id/archive'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to archive vehicle: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to archive vehicle: $e');
    }
  }

  Future<List<Car>> getWonVehicles() async {
    try {
      print('🏆 CarService.getWonVehicles: Starting...');
      final headers = await _getHeaders();
      print('📍 URL: $_baseUrl/vehicles/won');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/won'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        print('📦 Received ${body.length} won vehicles from backend');
        
        List<Car> cars = body.map((dynamic item) {
          try {
            final mappedItem = _mapBackendToFlutterFields(item as Map<String, dynamic>);
            return Car.fromJson(mappedItem);
          } catch (e) {
            print('⚠️ Error parsing won vehicle item: $e');
            print('   Item data: $item');
            rethrow;
          }
        }).toList();
        
        print('✅ Successfully parsed ${cars.length} won vehicles');
        return cars;
      } else {
        final errorBody = json.decode(response.body);
        final errorMsg = errorBody['error'] ?? 'Failed to load won vehicles: ${response.statusCode}';
        print('❌ Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ CarService.getWonVehicles Error: $e');
      throw Exception('Failed to load won vehicles: $e');
    }
  }

  Future<List<Car>> getPurchaseHistory() async {
    try {
      print('🛒 CarService.getPurchaseHistory: Starting...');
      final headers = await _getHeaders();
      print('📍 URL: $_baseUrl/vehicles/purchased');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/purchased'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        print('📦 Received ${body.length} purchase history items from backend');
        
        // Handle empty array gracefully
        if (body.isEmpty) {
          print('✅ Purchase History: Empty (no purchases yet)');
          return <Car>[];
        }
        
        List<Car> cars = body.map((dynamic item) {
          try {
            final mappedItem = _mapBackendToFlutterFields(item as Map<String, dynamic>);
            return Car.fromJson(mappedItem);
          } catch (e) {
            print('⚠️ Error parsing purchase item: $e');
            print('   Item data: $item');
            return null;
          }
        }).whereType<Car>().toList();
        
        print('✅ Successfully parsed ${cars.length} purchase history items');
        return cars;
      } else if (response.statusCode == 404) {
        // 404 means no purchases yet - return empty list
        print('✅ Purchase History: 404 (no purchases yet)');
        return <Car>[];
      } else {
        final errorBody = json.decode(response.body);
        final errorMsg = errorBody['error'] ?? 'Failed to load purchase history: ${response.statusCode}';
        print('❌ Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ CarService.getPurchaseHistory Error: $e');
      throw Exception('Failed to load purchase history: $e');
    }
  }

  Future<Map<String, dynamic>> getBuyerDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/buyer/dashboard'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error'] ?? 'Failed to load buyer dashboard: ${response.statusCode}';
        print('❌ Buyer Dashboard API Error (${response.statusCode}): $errorMessage');
        if (errorBody['error_details'] != null) {
          print('❌ Error Details: ${errorBody['error_details']}');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Buyer Dashboard Service Error: $e');
      if (e.toString().contains('Failed to load buyer dashboard')) {
        rethrow;
      }
      throw Exception('Failed to load buyer dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> getSellerStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load seller stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load seller stats: $e');
    }
  }

  Future<List<dynamic>> getPendingOffers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/pending-offers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load pending offers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load pending offers: $e');
    }
  }

  Future<List<dynamic>> getLiveAuctions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/live-auctions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load live auctions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load live auctions: $e');
    }
  }

  /// Get seller's vehicles with auction data (for dashboard)
  Future<List<dynamic>> getSellerVehicles() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/vehicles'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load seller vehicles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load seller vehicles: $e');
    }
  }

  Future<List<dynamic>> getEndedAuctions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/ended-auctions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load ended auctions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load ended auctions: $e');
    }
  }

  Future<List<Car>> getPendingTransport() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/pending-transport'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        List<Car> cars = body.map((dynamic item) => Car.fromJson(item)).toList();
        return cars;
      } else {
        throw Exception('Failed to load pending transport: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load pending transport: $e');
    }
  }

  Future<List<Car>> getScheduledTransport() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/seller/scheduled-transport'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        List<Car> cars = body.map((dynamic item) => Car.fromJson(item)).toList();
        return cars;
      } else {
        throw Exception('Failed to load scheduled transport: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load scheduled transport: $e');
    }
  }

  /// Get vehicle photos from backend
  Future<List<Map<String, dynamic>>> getVehiclePhotos(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/$vehicleId/photos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final photos = List<Map<String, dynamic>>.from(data['photos'] ?? []);
        print('🖼️ Vehicle $vehicleId photos fetched: count=${photos.length}');
        for (final p in photos) {
          final path = p['photo_path'] ?? p['photo_url'];
          final url = p['photo_url'];
          print('   • saved_path=$path | fetch_url=$url');
        }
        return photos;
      } else {
        throw Exception('Failed to load photos: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error fetching vehicle photos: $e');
      return [];
    }
  }

  /// Get vehicle value by VIN (for market valuation)
  /// Calculates market average from similar vehicles (make, model, year)
  /// Similar to website's "Get Valuation" functionality
  Future<Map<String, dynamic>> getVehicleValueByVIN(
    String? vin, {
    String? make,
    String? model,
    String? year,
    String? mileage,
    String? condition,
    String? zipcode,
  }) async {
    try {
      final headers = await _getHeaders();
      
      // Build query parameters (match website: VIN optional; Laravel rejects non-17-char vin)
      final queryParams = <String, String>{};
      final vinTrimmed = (vin ?? '').trim();
      if (vinTrimmed.length == 17) {
        queryParams['vin'] = vinTrimmed;
      }
      
      // Add optional make/model/year for better market average calculation
      if (make != null && make.isNotEmpty) {
        queryParams['make'] = make;
      }
      if (model != null && model.isNotEmpty) {
        queryParams['model'] = model;
      }
      if (year != null && year.isNotEmpty) {
        queryParams['year'] = year;
      }
      if (mileage != null && mileage.isNotEmpty) {
        queryParams['mileage'] = mileage;
      }
      if (condition != null && condition.isNotEmpty) {
        queryParams['condition'] = condition;
      }
      if (zipcode != null && zipcode.isNotEmpty) {
        queryParams['zipcode'] = zipcode;
      }
      
      final uri = Uri.parse('$_baseUrl/vehicles/value-by-vin').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // Some deployed environments still route /vehicles/value-by-vin
        // to /vehicles/{id}. Fallback to website endpoint for compatibility.
        final fallback = await _getValuationFromWebsiteEndpoint(
          vin: vin,
          make: make,
          model: model,
          year: year,
          mileage: mileage,
          condition: condition,
          zipcode: zipcode,
          headers: headers,
        );
        if (fallback != null) {
          return fallback;
        }

        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to get vehicle value: ${response.statusCode}');
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to get vehicle value: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error fetching vehicle value by VIN: $e');
      // Return default value if error
      return {
        'value': 0.0,
        'market_average': 0.0,
        'similar_vehicles_count': 0,
        'source': 'error',
        'vehicle_found': false,
        'message': 'Unable to fetch vehicle value. Please enter manually.',
      };
    }
  }

  Future<Map<String, dynamic>?> _getValuationFromWebsiteEndpoint({
    required String? vin,
    required String? make,
    required String? model,
    required String? year,
    required String? mileage,
    required String? condition,
    required String? zipcode,
    required Map<String, String> headers,
  }) async {
    try {
      final root = _baseUrl.replaceFirst(RegExp(r'/api$'), '');
      final queryParams = <String, String>{};

      if (vin != null && vin.isNotEmpty) {
        queryParams['vin'] = vin;
      }
      if (make != null && make.isNotEmpty) {
        queryParams['make'] = make;
      }
      if (model != null && model.isNotEmpty) {
        queryParams['model'] = model;
      }
      if (year != null && year.isNotEmpty) {
        queryParams['year'] = year;
      }
      if (mileage != null && mileage.isNotEmpty) {
        queryParams['mileage'] = mileage;
      }
      if (condition != null && condition.isNotEmpty) {
        queryParams['condition'] = condition;
      }
      if (zipcode != null && zipcode.isNotEmpty) {
        queryParams['zipcode'] = zipcode;
      }

      final fallbackUri =
          Uri.parse('$root/get-valuation.php').replace(queryParameters: queryParams);
      final fallbackRes = await http.get(fallbackUri, headers: headers);
      if (fallbackRes.statusCode != 200) {
        return null;
      }

      final decoded = json.decode(fallbackRes.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if (decoded['success'] != true) {
        return null;
      }

      final vals = (decoded['valuations'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final avg = (vals['average'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final internal = (vals['internal'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final kbb = (vals['kbb'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final mmr = (vals['mmr'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final jd = (vals['jd_power'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final retail = (avg['retail'] as num?)?.toDouble() ??
          (internal['retail'] as num?)?.toDouble() ??
          (kbb['retail'] as num?)?.toDouble() ??
          (mmr['retail'] as num?)?.toDouble() ??
          (jd['retail'] as num?)?.toDouble() ??
          0.0;

      final tradeIn = (avg['trade_in'] as num?)?.toDouble() ??
          (internal['trade_in'] as num?)?.toDouble() ??
          (kbb['trade_in'] as num?)?.toDouble() ??
          (mmr['trade_in'] as num?)?.toDouble() ??
          (jd['trade_in'] as num?)?.toDouble() ??
          0.0;

      final privateParty = (internal['private_party'] as num?)?.toDouble() ??
          (kbb['private_party'] as num?)?.toDouble() ??
          (mmr['private_party'] as num?)?.toDouble() ??
          0.0;

      final recommended =
          (vals['recommended_price'] as num?)?.toDouble() ?? (retail * 0.95);

      return <String, dynamic>{
        'value': retail,
        'market_average': retail,
        'trade_in_value': tradeIn,
        'private_party_value': privateParty,
        'retail_value': retail,
        'recommended_price': recommended,
        'similar_vehicles_count': (avg['sources_count'] as num?)?.toInt() ?? 0,
        'source': 'website_fallback',
        'vehicle_found': retail > 0,
        'message': 'Valuation loaded from website endpoint.',
        'sources': <String, dynamic>{
          'kbb': kbb,
          'mmr': mmr,
          'jd_power': jd,
          'internal': internal,
        },
      };
    } catch (_) {
      return null;
    }
  }

  /// Calculate distance between two ZIP codes
  Future<Map<String, dynamic>> calculateDistance(String zip1, String zip2) async {
    try {
      print('📍 Calculating distance between ZIP codes:');
      print('   Vehicle ZIP: "$zip1"');
      print('   User ZIP: "$zip2"');
      
      final headers = await _getHeaders();
      final requestBody = {
        'zip1': zip1,
        'zip2': zip2,
      };
      print('   Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/zip-codes/calculate-distance'),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      print('   Response status: ${response.statusCode}');
      print('   Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to calculate distance: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error calculating distance: $e');
      throw Exception('Failed to calculate distance: $e');
    }
  }
}
