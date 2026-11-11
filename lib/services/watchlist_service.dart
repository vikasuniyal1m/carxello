import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class WatchlistService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    // Try multiple ways to get token
    String? token;
    
    // Method 1: Use AuthService
    try {
      token = await _authService.getToken();
      if (token != null && token.isNotEmpty) {
        print('🔑 WatchlistService: Token found via AuthService: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      }
    } catch (e) {
      print('⚠️ WatchlistService: Error getting token from AuthService: $e');
    }
    
    // Method 2: Direct SharedPreferences access (fallback)
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('token');
        if (token != null && token.isNotEmpty) {
          print('🔑 WatchlistService: Token found via SharedPreferences: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        }
      } catch (e) {
        print('⚠️ WatchlistService: Error getting token from SharedPreferences: $e');
      }
    }
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      print('   📤 Authorization header: Bearer ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    } else {
      print('   ❌ WatchlistService: No token found - user may not be logged in');
      // Don't throw error here - let the API return 401 so we can handle it properly
    }
    
    return headers;
  }

  /// Get user's watchlist
  Future<List<dynamic>> getWatchlist() async {
    try {
      print('📋 WatchlistService: Fetching watchlist...');
      final headers = await _getHeaders();
      print('   📍 URL: $_baseUrl/watchlist');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/watchlist'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      print('📡 WatchlistService: Response Status: ${response.statusCode}');
      print('   📦 Response Body Length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('   ✅ Parsed response data');
        
        final watchlistItems = data['watchlist'] as List<dynamic>? ?? [];
        print('   📊 Found ${watchlistItems.length} watchlist items');
        
        // Debug: Print first item if exists
        if (watchlistItems.isNotEmpty) {
          print('   📦 First item: ${watchlistItems[0]}');
        }
        
        return watchlistItems;
      } else if (response.statusCode == 401) {
        print('   ❌ Authentication failed (401)');
        print('   📄 Response: ${response.body}');
        
        // Parse error response
        String errorMessage = 'Authentication failed. Please login again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          print('   ⚠️ Error parsing error response: $e');
        }
        
        // Check if token exists before clearing
        final prefs = await SharedPreferences.getInstance();
        final existingToken = prefs.getString('token');
        
        if (existingToken != null && existingToken.isNotEmpty) {
          // Token exists but is invalid/expired - clear it
          await prefs.remove('token');
          print('   🔑 Cleared expired/invalid token');
        } else {
          // No token found - user needs to login
          print('   ⚠️ No token found - user needs to login');
        }
        
        throw Exception('Authentication failed: $errorMessage');
      } else {
        print('   ❌ Failed with status ${response.statusCode}');
        print('   📄 Response: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        throw Exception('Failed to load watchlist: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ WatchlistService Error: $e');
      throw Exception('Failed to load watchlist: $e');
    }
  }

  /// Add vehicle to watchlist
  Future<Map<String, dynamic>> addToWatchlist(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/watchlist'),
        headers: headers,
        body: json.encode({
          'vehicle_id': vehicleId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to add to watchlist: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add to watchlist: $e');
    }
  }

  /// Remove vehicle from watchlist
  Future<void> removeFromWatchlist(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/watchlist/$vehicleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to remove from watchlist: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove from watchlist: $e');
    }
  }

  /// Check if vehicle is in watchlist
  Future<bool> checkWatchlist(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/watchlist/check/$vehicleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_watched'] as bool? ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}

