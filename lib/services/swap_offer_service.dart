import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class SwapOfferService {
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

  Future<Map<String, dynamic>> createSwapOffer({
    required String vehicleId,
    required String buyerVehicleVIN,
    required double buyerVehicleValue,
    required double additionalPayment,
    required String paymentType,
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/swap-offers'),
        headers: headers,
        body: json.encode({
          'vehicle_id': vehicleId,
          'buyer_vehicle_vin': buyerVehicleVIN,
          'buyer_vehicle_value': buyerVehicleValue,
          'additional_payment': additionalPayment,
          'payment_type': paymentType, // 'add' or 'resolve'
          'notes': notes,
        }),
      );

      print('📡 Swap Offer API Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');
      
      if (response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Swap offer created successfully');
        print('   📄 Swap Offer ID: ${result['swap_offer']?['id'] ?? 'N/A'}');
        print('   🚗 Vehicle ID: ${result['swap_offer']?['vehicle_id'] ?? 'N/A'}');
        return result;
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? errorBody['message'] ?? 'Failed to create swap offer: ${response.statusCode}';
        print('❌ Swap offer creation failed: $errorMessage');
        if (errorBody['errors'] != null) {
          print('   Validation errors: ${errorBody['errors']}');
        }
        throw Exception('Failed to create swap offer: $errorMessage');
      }
    } catch (e) {
      print('❌ Swap offer creation error: $e');
      if (e.toString().contains('Failed to create swap offer')) {
        rethrow;
      }
      throw Exception('Failed to create swap offer: $e');
    }
  }

  Future<List<dynamic>> getVehicleSwapOffers(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/swap-offers/vehicle/$vehicleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to load swap offers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load swap offers: $e');
    }
  }

  /// Check if user has a swap offer for a vehicle (as buyer)
  Future<bool> hasSwapOffer(String vehicleId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/swap-offers/my-offers/$vehicleId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['has_offer'] == true;
      } else if (response.statusCode == 404 || response.statusCode == 401) {
        return false;
      } else {
        print('⚠️ Error checking swap offer: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error checking swap offer: $e');
      return false;
    }
  }

  /// Get user's swap offer for a specific vehicle (as buyer)
  Future<Map<String, dynamic>?> getMySwapOffer(String vehicleId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/swap-offers/my-offers/$vehicleId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['has_offer'] == true && data['swap_offer'] != null) {
          return data['swap_offer'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting swap offer: $e');
      return null;
    }
  }

  /// Get all user's swap offers (as buyer)
  Future<List<Map<String, dynamic>>> getMySwapOffers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/swap-offers/my-offers'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else {
        print('⚠️ Error fetching swap offers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('⚠️ Error fetching swap offers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptOffer(String offerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/swap-offers/$offerId/accept'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Swap offer accepted successfully');
        return result;
      } else {
        final errorBody = json.decode(response.body);
        print('❌ Swap offer acceptance failed: ${errorBody['error']}');
        throw Exception(errorBody['error'] ?? 'Failed to accept offer');
      }
    } catch (e) {
      print('❌ Swap offer acceptance error: $e');
      throw Exception('Failed to accept offer: $e');
    }
  }

  Future<Map<String, dynamic>> rejectOffer(String offerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/swap-offers/$offerId/reject'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Swap offer rejected successfully');
        return result;
      } else {
        final errorBody = json.decode(response.body);
        print('❌ Swap offer rejection failed: ${errorBody['error']}');
        throw Exception(errorBody['error'] ?? 'Failed to reject offer');
      }
    } catch (e) {
      print('❌ Swap offer rejection error: $e');
      throw Exception('Failed to reject offer: $e');
    }
  }

  /// Cancel own swap offer (buyer only). Removes from active list; backend sets status to cancelled.
  Future<Map<String, dynamic>> cancelOffer(String bidId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/swap-offers/$bidId/cancel'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Swap offer cancelled successfully');
        return result;
      } else {
        final errorBody = response.body.isNotEmpty ? json.decode(response.body) : <String, dynamic>{};
        final err = errorBody['error'] ?? 'Failed to cancel offer';
        print('❌ Swap offer cancel failed: $err');
        throw Exception(err.toString());
      }
    } catch (e) {
      print('❌ Swap offer cancel error: $e');
      rethrow;
    }
  }
}

