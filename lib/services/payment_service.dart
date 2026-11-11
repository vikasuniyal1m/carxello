import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class PaymentService {
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

  Future<Map<String, dynamic>> processPayment({
    required String invoiceId,
    required String paymentMethod,
    String? paymentReference,
    String? paymentToken,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/payments/process'),
        headers: headers,
        body: json.encode({
          'invoice_id': invoiceId,
          'payment_method': paymentMethod,
          'payment_reference': paymentReference,
          'payment_token': paymentToken,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to process payment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/payments/history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['payments']);
      } else {
        throw Exception('Failed to load payment history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load payment history: $e');
    }
  }
}

