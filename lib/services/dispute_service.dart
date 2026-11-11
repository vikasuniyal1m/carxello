import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class DisputeService {
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

  Future<Map<String, dynamic>> createDispute({
    required String vehicleId,
    required String disputeType,
    required String description,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/disputes'),
        headers: headers,
        body: json.encode({
          'vehicle_id': vehicleId,
          'dispute_type': disputeType,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create dispute: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create dispute: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDisputes() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/disputes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['disputes']);
      } else {
        throw Exception('Failed to load disputes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load disputes: $e');
    }
  }

  Future<Map<String, dynamic>> getDispute(String disputeId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/disputes/$disputeId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load dispute: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load dispute: $e');
    }
  }
}

