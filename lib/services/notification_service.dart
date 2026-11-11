import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';
import '../utils/preferences_helper.dart';

class NotificationService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Map<String, dynamic> _emptyNotificationsResponse() => {
        'notifications': <dynamic>[],
        'unread_count': 0,
      };

  Future<bool> _hasAuthToken() async {
    final t = await PreferencesHelper.getAuthToken();
    return t != null && t.isNotEmpty;
  }

  Future<Map<String, String>> _getHeaders() async {
    try {
      final token = await _authService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        print('🔑 NotificationService: Token found: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        print('   📤 Authorization header: Bearer ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      } else {
        print('   ⚠️ NotificationService: No token found');
      }
      
      return headers;
    } catch (e) {
      print('⚠️ NotificationService._getHeaders: Error getting token: $e');
      // Return headers without token if SharedPreferences fails
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }
  }

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      if (!await _hasAuthToken()) {
        return _emptyNotificationsResponse();
      }

      print('🔔 NotificationService.getNotifications: Starting...');
      final role = (await PreferencesHelper.getEffectiveRoleForNotifications()).toLowerCase();
      final userId = await PreferencesHelper.getUserId();
      final uri = Uri.parse('$_baseUrl/notifications').replace(
        queryParameters: {
          if (role.isNotEmpty) 'role': role,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        },
      );
      print('   📍 URL: $uri');
      
      final headers = await _getHeaders();
      final response = await http.get(
        uri,
        headers: headers,
      );

      print('📡 NotificationService: Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('   ✅ NotificationService: Successfully fetched notifications');
        return data;
      } else if (response.statusCode == 401) {
        print('   ❌ NotificationService: Authentication failed (401)');
        print('   📄 Response: ${response.body}');
        String errorMessage = 'Authentication failed. Please login again.';
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          errorMessage =
              (errorData['message'] ?? errorMessage).toString();
        } catch (_) {}
        throw Exception('Authentication failed: $errorMessage');
      } else {
        print('   ❌ NotificationService: Failed with status ${response.statusCode}');
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ NotificationService: Exception occurred: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      if (!await _hasAuthToken()) return;
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/$notificationId/read'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      if (!await _hasAuthToken()) return;
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/read-all'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      if (!await _hasAuthToken()) return;
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/notifications/$notificationId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification');
      }
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Backend helper for creating notification events.
  /// Backend should validate role targeting and linked resources.
  Future<void> createNotificationEvent({
    required String title,
    required String message,
    required String type,
    required List<String> targetRoles,
    String? relatedType,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    if (!await _hasAuthToken()) {
      throw Exception('Not authenticated');
    }
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/notifications'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'message': message,
        'type': type,
        'target_roles': targetRoles,
        if (relatedType != null) 'related_type': relatedType,
        if (relatedId != null) 'related_id': relatedId,
        if (data != null) 'data': data,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create notification event: ${response.statusCode}');
    }
  }
}

