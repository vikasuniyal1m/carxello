import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class NHTSAService {
  String get _baseUrl => ApiConfig.baseUrl;

  /// Decode VIN and return vehicle data
  /// 
  /// [vin] - 17-character VIN number
  /// [modelYear] - Optional model year for better accuracy
  /// Returns decoded vehicle data or null if error
  Future<Map<String, dynamic>?> decodeVin(String vin, {int? modelYear}) async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/decode-vin');
      
      final body = <String, dynamic>{
        'vin': vin.toUpperCase().trim(),
      };
      
      if (modelYear != null) {
        body['model_year'] = modelYear;
      }

      print('🔍 NHTSA: Decoding VIN: $vin');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📡 NHTSA: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📋 NHTSA: Response data type: ${data.runtimeType}');
        print('📋 NHTSA: Data content: $data');
        
        if (data['success'] == true) {
          final responseData = data['data'];
          
          // Handle empty array/object
          if (responseData == null || (responseData is List && responseData.isEmpty) || (responseData is Map && responseData.isEmpty)) {
            print('⚠️ NHTSA: VIN decoded but no data returned (empty response)');
            print('⚠️ NHTSA: This might mean VIN is invalid or NHTSA has no data for this VIN');
            return null;
          }
          
          print('✅ NHTSA: VIN decoded successfully');
          
          // Handle both Map and List responses
          if (responseData is Map<String, dynamic>) {
            return responseData;
          } else if (responseData is List) {
            // If it's a list, it's empty or wrong format
            print('⚠️ NHTSA: Received List instead of Map');
            return null;
          } else {
            print('⚠️ NHTSA: Unexpected data type: ${responseData.runtimeType}');
            return null;
          }
        } else {
          print('❌ NHTSA: VIN decode failed: ${data['error'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ NHTSA: API error: ${errorData['error'] ?? 'Unknown error'}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ NHTSA: Exception decoding VIN: $e');
      print('❌ NHTSA: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get full VIN details: decode (build sheet) + safety ratings/features + recalls
  /// Returns { decode: {...}, safety: { ratings: {...}, safety_features: {...} }, recalls: [...] } or null
  Future<Map<String, dynamic>?> getVinFullDetails(String vin, {int? modelYear}) async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/vin-full-details');
      final body = <String, dynamic>{'vin': vin.toUpperCase().trim()};
      if (modelYear != null) body['model_year'] = modelYear;
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 25), onTimeout: () => throw Exception('Request timeout'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('❌ NHTSA: getVinFullDetails error: $e');
      return null;
    }
  }

  /// Get all vehicle makes
  /// Returns list of make names or empty list if error
  Future<List<String>> getAllMakes() async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/makes');
      
      print('🔍 NHTSA: Fetching all makes');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📡 NHTSA: Makes response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final makes = List<String>.from(data['data']);
          print('✅ NHTSA: Retrieved ${makes.length} makes');
          return makes;
        } else {
          print('❌ NHTSA: Failed to fetch makes: ${data['error'] ?? 'Unknown error'}');
          return [];
        }
      } else {
        print('❌ NHTSA: API error fetching makes');
        return [];
      }
    } catch (e) {
      print('❌ NHTSA: Exception fetching makes: $e');
      return [];
    }
  }

  /// Title-case a make name (e.g. "LAND ROVER" -> "Land Rover") for NHTSA API.
  static String _titleCaseMake(String make) {
    if (make.isEmpty) return make;
    return make.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Get models for a specific make
  /// 
  /// [make] - Vehicle manufacturer name
  /// Returns list of model names or empty list if error
  Future<List<String>> getModelsForMake(String make) async {
    try {
      if (make.isEmpty) return [];
      // Try title case first (NHTSA often expects "Land Rover" not "LAND ROVER")
      final makeToTry = _titleCaseMake(make);
      final list = await _getModelsForMakeOnce(makeToTry);
      if (list.isNotEmpty) return list;
      if (makeToTry != make) {
        final list2 = await _getModelsForMakeOnce(make);
        return list2;
      }
      return list;
    } catch (e) {
      print('❌ NHTSA: Exception fetching models: $e');
      return [];
    }
  }

  Future<List<String>> _getModelsForMakeOnce(String make) async {
    final encodedMake = Uri.encodeComponent(make);
    final url = Uri.parse('$_baseUrl/nhtsa/models/$encodedMake');
    print('🔍 NHTSA: Fetching models for make: $make');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception('Request timeout');
    });
    print('📡 NHTSA: Models response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('❌ NHTSA: API error fetching models (status ${response.statusCode})');
      return [];
    }
    final data = jsonDecode(response.body);
    if (data['success'] == true && data['data'] != null) {
      final models = List<String>.from(data['data']);
      print('✅ NHTSA: Retrieved ${models.length} models for $make');
      return models;
    }
    print('❌ NHTSA: Failed to fetch models: ${data['error'] ?? 'Unknown error'}');
    return [];
  }

  /// Get models for a specific make and year
  /// 
  /// [make] - Vehicle manufacturer name
  /// [year] - Model year
  /// Returns list of model names or empty list if error
  Future<List<String>> getModelsForMakeYear(String make, int year) async {
    try {
      if (make.isEmpty) return [];
      // Try title case first (NHTSA often expects "Land Rover" not "LAND ROVER")
      final makeToTry = _titleCaseMake(make);
      final list = await _getModelsForMakeYearOnce(makeToTry, year);
      if (list.isNotEmpty) return list;
      if (makeToTry != make) {
        final list2 = await _getModelsForMakeYearOnce(make, year);
        return list2;
      }
      // On 400/empty, fallback to models for make only (no year)
      final fallback = await getModelsForMake(make);
      return fallback;
    } catch (e) {
      print('❌ NHTSA: Exception fetching models: $e');
      return [];
    }
  }

  Future<List<String>> _getModelsForMakeYearOnce(String make, int year) async {
    final encodedMake = Uri.encodeComponent(make);
    final url = Uri.parse('$_baseUrl/nhtsa/models/$encodedMake/$year');
    print('🔍 NHTSA: Fetching models for make: $make, year: $year');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception('Request timeout');
    });
    print('📡 NHTSA: Models response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('❌ NHTSA: API error fetching models (status ${response.statusCode})');
      return [];
    }
    final data = jsonDecode(response.body);
    if (data['success'] == true && data['data'] != null) {
      final models = List<String>.from(data['data']);
      print('✅ NHTSA: Retrieved ${models.length} models for $make $year');
      return models;
    }
    print('❌ NHTSA: Failed to fetch models: ${data['error'] ?? 'Unknown error'}');
    return [];
  }

  /// Get fuel type options
  /// Returns list of fuel type strings
  Future<List<String>> getFuelTypes() async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/fuel-types');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(data['data']);
        }
      }
      return ['gasoline', 'diesel', 'electric', 'hybrid']; // Fallback
    } catch (e) {
      print('❌ NHTSA: Exception fetching fuel types: $e');
      return ['gasoline', 'diesel', 'electric', 'hybrid']; // Fallback
    }
  }

  /// Get drive type options
  /// Returns list of drive type strings
  Future<List<String>> getDriveTypes() async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/drive-types');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(data['data']);
        }
      }
      return ['fwd', 'rwd', 'awd', '4wd']; // Fallback
    } catch (e) {
      print('❌ NHTSA: Exception fetching drive types: $e');
      return ['fwd', 'rwd', 'awd', '4wd']; // Fallback
    }
  }

  /// Get engine type options
  /// Returns list of engine type strings
  Future<List<String>> getEngineTypes() async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/engine-types');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(data['data']);
        }
      }
      return ['Inline 4', 'V6', 'V8', 'Electric', 'Hybrid']; // Fallback
    } catch (e) {
      print('❌ NHTSA: Exception fetching engine types: $e');
      return ['Inline 4', 'V6', 'V8', 'Electric', 'Hybrid']; // Fallback
    }
  }

  /// Get exterior color options
  /// Returns list of exterior color strings
  Future<List<String>> getExteriorColors() async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/exterior-colors');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(data['data']);
        }
      }
      return ['Black', 'White', 'Silver', 'Gray', 'Red', 'Blue']; // Fallback
    } catch (e) {
      print('❌ NHTSA: Exception fetching exterior colors: $e');
      return ['Black', 'White', 'Silver', 'Gray', 'Red', 'Blue']; // Fallback
    }
  }

  /// Get interior color options
  /// Returns list of interior color strings
  Future<List<String>> getInteriorColors() async {
    try {
      final url = Uri.parse('$_baseUrl/nhtsa/interior-colors');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(data['data']);
        }
      }
      return ['Black', 'Gray', 'Beige', 'Tan', 'Brown', 'Cream']; // Fallback
    } catch (e) {
      print('❌ NHTSA: Exception fetching interior colors: $e');
      return ['Black', 'Gray', 'Beige', 'Tan', 'Brown', 'Cream']; // Fallback
    }
  }
}
