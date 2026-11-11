import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class ShippingAddressService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  /// Get user's shipping addresses
  Future<List<Map<String, dynamic>>> getShippingAddresses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/shipping-addresses'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['addresses'] ?? []);
      } else {
        throw Exception('Failed to load shipping addresses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load shipping addresses: $e');
    }
  }

  /// Save shipping address
  Future<Map<String, dynamic>> saveShippingAddress({
    required String address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    bool isDefault = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/shipping-addresses'),
        headers: headers,
        body: json.encode({
          'address': address,
          'city': city,
          'state': state,
          'zip_code': zipCode,
          'country': country ?? 'USA',
          'is_default': isDefault,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['address'] ?? data);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to save shipping address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to save shipping address: $e');
    }
  }

  /// Update shipping address
  Future<Map<String, dynamic>> updateShippingAddress(
    String addressId, {
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    bool? isDefault,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/shipping-addresses/$addressId'),
        headers: headers,
        body: json.encode({
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (zipCode != null) 'zip_code': zipCode,
          if (country != null) 'country': country,
          if (isDefault != null) 'is_default': isDefault,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['address'] ?? data);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update shipping address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update shipping address: $e');
    }
  }

  /// Delete shipping address
  Future<void> deleteShippingAddress(String addressId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/shipping-addresses/$addressId'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete shipping address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete shipping address: $e');
    }
  }
}

