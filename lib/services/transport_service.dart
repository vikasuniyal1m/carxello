import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class TransportService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/dashboard'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error'] ?? 'Failed to load dashboard: ${response.statusCode}';
        print('❌ Dashboard API Error (${response.statusCode}): $errorMessage');
        if (errorBody['error_details'] != null) {
          print('❌ Error Details: ${errorBody['error_details']}');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Dashboard Service Error: $e');
      // Don't double-wrap exceptions
      if (e.toString().contains('Failed to load dashboard')) {
        rethrow;
      }
      throw Exception('Failed to load dashboard: $e');
    }
  }

  Future<List<dynamic>> getPickupSchedule() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/pickup-schedule'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to load pickup schedule: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load pickup schedule: $e');
    }
  }

  Future<Map<String, dynamic>> markPickupComplete(String orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/orders/$orderId/pickup-complete'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to mark pickup complete');
      }
    } catch (e) {
      throw Exception('Failed to mark pickup complete: $e');
    }
  }

  Future<Map<String, dynamic>> claimOrder(String orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/orders/$orderId/claim'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = response.body.isNotEmpty ? json.decode(response.body) : {};
        final msg = errorBody['error'] ?? 'Failed to claim order';
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception('Failed to claim order: $e');
    }
  }

  Future<List<dynamic>> getDeliveryConfirmations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/delivery-confirmations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to load delivery confirmations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load delivery confirmations: $e');
    }
  }

  Future<Map<String, dynamic>> confirmDeliveryTimelineFlexible(
      String orderId, {
        String? deliveryDateTime,
        String? deliveryDate,
        String? deliveryTime,
        String? notes,
      }) async {
    try {
      final baseHeaders = await _getHeaders();
      final headers = <String, String>{
        ...baseHeaders,
        'Content-Type': 'application/json',
      };
      final body = <String, dynamic>{};
      if (deliveryDateTime != null && deliveryDateTime.isNotEmpty) {
        body['delivery_datetime'] = deliveryDateTime;
      } else {
        if (deliveryDate != null) body['delivery_date'] = deliveryDate;
        if (deliveryTime != null) body['delivery_time'] = deliveryTime;
      }
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/orders/$orderId/confirm-timeline'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to confirm delivery timeline');
      }
    } catch (e) {
      throw Exception('Failed to confirm delivery timeline: $e');
    }
  }

  // Backward compatible wrapper
  Future<Map<String, dynamic>> confirmDeliveryTimeline(
      String orderId,
      String deliveryDate,
      String deliveryTime,
      ) {
    return confirmDeliveryTimelineFlexible(
      orderId,
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
    );
  }

  Future<Map<String, dynamic>> uploadProof(
      String transportOrderId,
      String vin,
      File imageFile,
      ) async {
    try {
      final headers = await _getHeaders();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transport/upload-proof'),
      );

      // Add headers
      request.headers.addAll(headers);

      // Add fields
      request.fields['transport_order_id'] = transportOrderId;
      request.fields['vin'] = vin;

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'proof_image',
          imageFile.path,
          filename: imageFile.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to upload proof');
      }
    } catch (e) {
      throw Exception('Failed to upload proof: $e');
    }
  }

  Future<void> updateLocation(String orderId, String currentLocation, String notes) async {
    try {
      final headers = await _getHeaders();
      final jsonHeaders = <String, String>{
        ...headers,
        'Content-Type': 'application/json',
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/orders/$orderId/location-update'),
        headers: jsonHeaders,
        body: json.encode({
          'current_location': currentLocation,
          if (notes.isNotEmpty) 'location_notes': notes,
        }),
      );
      if (response.statusCode != 200) {
        try {
          final errorBody = response.body.isNotEmpty ? json.decode(response.body) : {'error': 'Unknown error'};
          throw Exception(errorBody['error'] ?? 'Failed to update location');
        } catch (_) {
          throw Exception('Failed to update location');
        }
      }
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  Future<List<dynamic>> getUploadHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/upload-history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to load upload history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load upload history: $e');
    }
  }

  Future<Map<String, dynamic>> trackVIN(String vin) async {
    try {
      final baseHeaders = await _getHeaders();
      final headers = <String, String>{
        ...baseHeaders,
        'Content-Type': 'application/json',
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/track-vin'),
        headers: headers,
        body: json.encode({
          'vin': vin,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        String message = 'Failed to track VIN';
        try {
          final errorBody = json.decode(response.body);
          message = errorBody['error']?.toString() ?? message;
        } catch (_) {
          if (response.statusCode == 401) message = 'Unauthorized. Transporter access only.';
        }
        throw Exception(message);
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> getTransportOrder(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/orders/vehicle/$vehicleId'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // 404 = no transport order for this vehicle (normal - not yet scheduled)
        return {'order': null};
      } else {
        final errorBody = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? 'Failed to load transport order: ${response.statusCode}';
        print('❌ Get Transport Order Error (${response.statusCode}): $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('❌ Network Error: ${e.message}');
      throw Exception('Network error: Unable to connect to server. Please check your internet connection.');
    } on HttpException catch (e) {
      print('❌ HTTP Error: ${e.message}');
      throw Exception('Server error: ${e.message}');
    } catch (e) {
      print('❌ Get Transport Order Exception: $e');
      final errorMessage = e.toString();

      // Check for common network errors
      if (errorMessage.contains('Failed host lookup') ||
          errorMessage.contains('No address associated with hostname') ||
          errorMessage.contains('SocketException')) {
        throw Exception('Network error: Unable to reach server. Please check your internet connection and try again.');
      } else if (errorMessage.contains('timeout') || errorMessage.contains('TimeoutException')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else {
        throw Exception('Failed to load transport order: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/orders/$orderId/cancel'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Order cancelled successfully');
        return;
      } else {
        final errorBody = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? 'Failed to cancel order: ${response.statusCode}';
        print('❌ Cancel Order Error (${response.statusCode}): $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Cancel Order Exception: $e');
      throw Exception('Failed to cancel order: $e');
    }
  }

  Future<List<dynamic>> getTransporters() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/transporters'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['transporters'] as List<dynamic>? ?? []);
      } else {
        final errorBody = response.body.isNotEmpty ? json.decode(response.body) : {};
        final msg = errorBody['error'] ?? 'Failed to load transporters';
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception('Failed to load transporters: $e');
    }
  }

  Future<Map<String, dynamic>> scheduleTransport({
    required String vehicleId,
    required String pickupLocation,
    required String deliveryLocation,
    String? pickupCity,
    String? deliveryCity,
    String? pickupState,
    String? deliveryState,
    String? scheduledPickupDate,
    String? scheduledDeliveryDate,
    String? pickupDate,
    String? deliveryDate,
    String? deliveryZip,
    String? specialInstructions,
    String? transporterId,
    String? selectedShippingOption,
    String? selectedDeliveryOption,
    String? selectedInsurance,
    bool? rushDelivery,
    double? totalCost,
    bool? usePlatformTransport,
  }) async {
    try {
      final baseHeaders = await _getHeaders();
      final headers = <String, String>{
        ...baseHeaders,
        'Content-Type': 'application/json',
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/schedule'),
        headers: headers,
        body: json.encode({
          'vehicle_id': vehicleId,
          'transporter_id': transporterId,
          'pickup_location': pickupLocation,
          'delivery_location': deliveryLocation,
          'delivery_zip': deliveryZip,
          'pickup_city': pickupCity,
          'delivery_city': deliveryCity,
          'pickup_state': pickupState,
          'delivery_state': deliveryState,
          'scheduled_pickup_date': scheduledPickupDate,
          'scheduled_delivery_date': scheduledDeliveryDate,
          'pickup_date': pickupDate,
          'delivery_date': deliveryDate,
          'selected_shipping_option': selectedShippingOption,
          'selected_delivery_option': selectedDeliveryOption,
          'selected_insurance': selectedInsurance,
          'rush_delivery': rushDelivery,
          'total_cost': totalCost,
          'cost': totalCost,
          'special_instructions': specialInstructions,
          'notes': specialInstructions,
          'use_platform_transport': usePlatformTransport ?? true,
        }),
      );

      print('📡 Schedule Transport API Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Transport scheduled successfully');
        print('   📄 Order ID: ${result['order']?['id'] ?? 'N/A'}');
        print('   📍 Delivery Address: ${result['order']?['delivery_address'] ?? 'N/A'}');
        print('   📊 Status: ${result['order']?['status'] ?? 'N/A'}');
        return result;
      } else {
        final errorBody = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? errorBody['message'] ?? 'Failed to schedule transport: ${response.statusCode}';
        print('❌ Schedule Transport failed: $errorMessage');

        // Handle "already scheduled" error more gracefully
        if (errorMessage.toString().toLowerCase().contains('already scheduled')) {
          print('   ℹ️ Transport order already exists - this is normal if re-scheduling');
          // Still throw error but with clearer message
          throw Exception('Transport is already scheduled. Please check your transport orders.');
        }

        if (errorBody['errors'] != null) {
          print('   Validation errors: ${errorBody['errors']}');
        }
        throw Exception('Failed to schedule transport: $errorMessage');
      }
    } catch (e) {
      throw Exception('Failed to schedule transport: $e');
    }
  }

  Future<List<dynamic>> getSellerPendingRequests() async {
    try {
      print('📦 TransportService.getSellerPendingRequests: Starting...');
      final headers = await _getHeaders();
      print('📍 URL: $_baseUrl/transport/seller/pending');

      final response = await http.get(
        Uri.parse('$_baseUrl/transport/seller/pending'),
        headers: headers,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final orders = data['orders'] as List<dynamic>? ?? [];
        print('✅ Successfully fetched ${orders.length} pending transport requests');
        return orders;
      } else {
        final errorBody = json.decode(response.body);
        final errorMsg = errorBody['error'] ?? 'Failed to load pending transport requests: ${response.statusCode}';
        print('❌ Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ TransportService.getSellerPendingRequests Error: $e');
      throw Exception('Failed to load pending transport requests: $e');
    }
  }

  Future<Map<String, dynamic>> sellerApproveTransportDates(String orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transport/orders/$orderId/seller/approve'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to approve transport dates');
      }
    } catch (e) {
      throw Exception('Failed to approve transport dates: $e');
    }
  }

  // ✅ NEW: Get my transports (for both buyer and transporter)
  Future<List<Map<String, dynamic>>> getMyTransports() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transport/orders/my'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        if (data['transports'] != null) {
          return List<Map<String, dynamic>>.from(data['transports']);
        } else if (data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [];
        }
      } else if (response.statusCode == 404) {
        return [];
      } else {
        print('⚠️ Failed to load my transports: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('⚠️ Error in getMyTransports: $e');
      return [];
    }
  }
}
