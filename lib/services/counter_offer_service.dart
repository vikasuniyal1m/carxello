import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class CounterOfferService {
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

  Future<Map<String, dynamic>> createCounterOffer({
    required String vehicleId,
    String? bidId,
    required double counterAmount,
    String? message,
    String? expiresAt,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/counter-offers'),
        headers: headers,
        body: json.encode({
          'vehicle_id': vehicleId,
          'bid_id': bidId,
          'counter_amount': counterAmount,
          'message': message,
          'expires_at': expiresAt,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create counter offer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create counter offer: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCounterOffers({String? vehicleId, bool forBuyer = false}) async {
    try {
      final headers = await _getHeaders();
      String url = '$_baseUrl/counter-offers';
      if (vehicleId != null || forBuyer) {
        url += '?';
        if (vehicleId != null) url += 'vehicle_id=$vehicleId';
        if (vehicleId != null && forBuyer) url += '&';
        if (forBuyer) url += 'for_buyer=true';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['counter_offers']);
      } else {
        throw Exception('Failed to load counter offers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load counter offers: $e');
    }
  }

  Future<Map<String, dynamic>> acceptCounterOffer(String counterOfferId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/counter-offers/$counterOfferId/accept'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to accept counter offer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to accept counter offer: $e');
    }
  }

  Future<Map<String, dynamic>> rejectCounterOffer(String counterOfferId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/counter-offers/$counterOfferId/reject'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to reject counter offer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to reject counter offer: $e');
    }
  }
}

