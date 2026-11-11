import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class SearchAlertService {
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

  /// Get user's search alerts
  Future<List<dynamic>> getSearchAlerts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/search-alerts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['alerts'] as List<dynamic>? ?? [];
      } else {
        throw Exception('Failed to load search alerts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load search alerts: $e');
    }
  }

  /// Mark alert as read
  Future<void> markAlertAsRead(String alertId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/search-alerts/$alertId/read'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to mark alert as read');
      }
    } catch (e) {
      throw Exception('Failed to mark alert as read: $e');
    }
  }

  /// Mark all alerts as read
  Future<void> markAllAlertsAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/search-alerts/read-all'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to mark all alerts as read');
      }
    } catch (e) {
      throw Exception('Failed to mark all alerts as read: $e');
    }
  }

  /// Delete alert
  Future<void> deleteAlert(String alertId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/search-alerts/$alertId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete alert');
      }
    } catch (e) {
      throw Exception('Failed to delete alert: $e');
    }
  }
}

