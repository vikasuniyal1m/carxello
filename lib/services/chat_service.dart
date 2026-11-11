import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/preferences_helper.dart';
import 'auth_service.dart';

class ChatService {
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

  Future<Map<String, dynamic>> getOrCreateConversation({
    required String otherUserId,
    String? relatedType,
    int? relatedId,
    int? transportOrderId,
  }) async {
    try {
      final normalizedOther = otherUserId.trim();
      if (normalizedOther.isEmpty) {
        throw Exception('Invalid recipient.');
      }
      final me = await PreferencesHelper.getUserId();
      if (me != null && me.trim().isNotEmpty && me.trim() == normalizedOther) {
        throw Exception('You cannot start a conversation with yourself.');
      }

      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'other_user_id': normalizedOther,
        if (relatedType != null) 'related_type': relatedType,
        if (relatedId != null) 'related_id': relatedId,
        if (transportOrderId != null) 'transport_order_id': transportOrderId,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/conversations'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to get/create conversation');
      }
    } catch (e) {
      throw Exception('Failed to get/create conversation: $e');
    }
  }

  Future<Map<String, dynamic>> getConversations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/chat/conversations'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Get current user info - we'll get it from backend in future or decode from token
        // For now, we'll extract from conversation data
        return {
          'conversations': data['conversations'] as List<dynamic>? ?? [],
          'current_user_id': data['current_user_id']?.toString(),
        };
      } else {
        // Try to parse error message from response
        try {
          final errorBody = json.decode(response.body);
          final errorMessage = errorBody['error'] ?? 'Failed to load conversations: ${response.statusCode}';
          print('❌ Chat API Error (${response.statusCode}): $errorMessage');
          throw Exception(errorMessage);
        } catch (e) {
          if (e.toString().contains('Failed to load')) {
            rethrow;
          }
          throw Exception('Failed to load conversations: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Don't double-wrap exceptions
      if (e.toString().contains('Failed to load conversations') || 
          e.toString().contains('Connection timeout')) {
        rethrow;
      }
      print('❌ Chat Service Error: $e');
      throw Exception('Failed to load conversations: $e');
    }
  }

  Future<Map<String, dynamic>> getMessages(String conversationId) async {
    try {
      print('💬 ChatService: Fetching messages for conversation: $conversationId');
      final headers = await _getHeaders();
      final url = '$_baseUrl/chat/conversations/$conversationId/messages';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ChatService Error: $e');
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String message,
    String messageType = 'text',
    String? attachmentUrl,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/conversations/$conversationId/messages'),
        headers: headers,
        body: json.encode({
          'message': message,
          'message_type': messageType,
          'attachment_url': attachmentUrl,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['message'] as Map<String, dynamic>;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to send message');
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}

