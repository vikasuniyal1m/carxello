import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class UserService {
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

  Future<List<Map<String, dynamic>>> getAvailableInspectors() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/users/inspectors'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['inspectors'] as List);
      } else {
        throw Exception('Failed to load inspectors: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load inspectors: $e');
    }
  }

  /// Fetch current user profile from backend
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      print('👤 UserService.getUserProfile: Starting...');
      print('   📍 URL: $_baseUrl/user');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: headers,
      );

      print('📡 UserService: Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('   ✅ UserService: Successfully fetched user profile');
        return Map<String, dynamic>.from(data);
      } else {
        print('   ❌ UserService: Failed with status ${response.statusCode}');
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ UserService: Exception occurred: $e');
      throw Exception('Failed to load user profile: $e');
    }
  }

  /// Update user profile on backend
  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/user'),
        headers: headers,
        body: json.encode(profileData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}

