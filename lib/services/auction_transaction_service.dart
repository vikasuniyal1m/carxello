import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';
import '../models/auction_transaction.dart';

/// Service for managing auction transactions with escrow workflow
/// 
/// This service handles the 10-step transaction flow:
/// 1. Auction Ends
/// 2. Winner Notified  
/// 3. Invoice Generated
/// 4. Buyer Payment Processing
/// 5. Funds Held in Escrow
/// 6. Seller Ships Vehicle
/// 7. Buyer Confirms Receipt
/// 8. Funds Released to Seller
/// 9. Platform Fee Deducted
/// 10. Transaction Complete
class AuctionTransactionService {
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

  // ==================== GET TRANSACTIONS ====================

  /// Get all transactions for the current user (both buyer and seller)
  Future<List<AuctionTransaction>> getMyTransactions({
    TransactionStatus? status,
    String? role, // 'buyer' or 'seller'
  }) async {
    try {
      final headers = await _getHeaders();
      
      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null) {
        queryParams['status'] = status.name;
      }
      if (role != null) {
        queryParams['role'] = role;
      }
      
      final uri = Uri.parse('$_baseUrl/transactions').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final transactions = data['transactions'] as List<dynamic>;
        return transactions
            .map((json) => AuctionTransaction.fromJson(json))
            .toList();
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    }
  }

  /// Get a specific transaction by ID
  Future<AuctionTransaction> getTransaction(String transactionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions/$transactionId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transaction: $e');
    }
  }

  /// Get transaction for a specific auction
  Future<AuctionTransaction?> getTransactionByAuction(String auctionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/auctions/$auctionId/transaction'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['transaction'] != null) {
          return AuctionTransaction.fromJson(data['transaction']);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transaction: $e');
    }
  }

  // ==================== BUYER ACTIONS ====================

  /// Step 4: Process buyer payment and hold funds in escrow
  /// 
  /// This initiates the payment process and moves funds into the escrow account
  Future<AuctionTransaction> processBuyerPayment({
    required String transactionId,
    required String paymentMethod, // 'credit_card', 'bank_transfer', 'wire'
    String? paymentToken, // Stripe token or similar
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$transactionId/pay'),
        headers: headers,
        body: json.encode({
          'payment_method': paymentMethod,
          'payment_token': paymentToken,
          'payment_details': paymentDetails,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to process payment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  /// Step 7: Buyer confirms receipt of vehicle
  /// 
  /// This releases funds from escrow to the seller
  Future<AuctionTransaction> confirmVehicleReceipt({
    required String transactionId,
    bool vehicleAsDescribed = true,
    String? feedback,
    int? conditionRating, // 1-5 scale
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$transactionId/confirm-receipt'),
        headers: headers,
        body: json.encode({
          'vehicle_as_described': vehicleAsDescribed,
          'feedback': feedback,
          'condition_rating': conditionRating,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to confirm receipt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to confirm receipt: $e');
    }
  }

  /// Request refund (only available under specific conditions)
  Future<AuctionTransaction> requestRefund({
    required String transactionId,
    required String reason,
    String? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$transactionId/refund-request'),
        headers: headers,
        body: json.encode({
          'reason': reason,
          'details': details,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to request refund: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to request refund: $e');
    }
  }

  // ==================== SELLER ACTIONS ====================

  /// Step 6: Seller provides shipping information
  Future<AuctionTransaction> provideShippingInfo({
    required String transactionId,
    required String carrier,
    required String trackingNumber,
    DateTime? estimatedDelivery,
    String? pickupLocation,
    String? deliveryLocation,
    String? specialInstructions,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$transactionId/shipping'),
        headers: headers,
        body: json.encode({
          'carrier': carrier,
          'tracking_number': trackingNumber,
          'estimated_delivery': estimatedDelivery?.toIso8601String(),
          'pickup_location': pickupLocation,
          'delivery_location': deliveryLocation,
          'special_instructions': specialInstructions,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update shipping: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update shipping: $e');
    }
  }

  /// Mark vehicle as shipped (alternative to full shipping info)
  Future<AuctionTransaction> markAsShipped({
    required String transactionId,
    String? carrier,
    String? trackingNumber,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$transactionId/mark-shipped'),
        headers: headers,
        body: json.encode({
          'carrier': carrier,
          'tracking_number': trackingNumber,
          'shipped_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to mark as shipped: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to mark as shipped: $e');
    }
  }

  // ==================== ESCROW MANAGEMENT ====================

  /// Get escrow details for a transaction
  Future<Map<String, dynamic>> getEscrowDetails(String transactionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions/$transactionId/escrow'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load escrow details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load escrow details: $e');
    }
  }

  /// Get trust account balance (admin/seller view)
  Future<Map<String, dynamic>> getTrustAccountBalance() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/escrow/balance'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load balance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load trust account balance: $e');
    }
  }

  // ==================== ADMIN OPERATIONS ====================

  /// Admin: Manually release funds from escrow (emergency/override)
  Future<AuctionTransaction> adminReleaseEscrow({
    required String transactionId,
    required String reason,
    required bool releaseToSeller, // true = seller, false = refund to buyer
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/transactions/$transactionId/release-escrow'),
        headers: headers,
        body: json.encode({
          'reason': reason,
          'release_to_seller': releaseToSeller,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to release escrow: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to release escrow: $e');
    }
  }

  /// Admin: Cancel transaction and refund buyer
  Future<AuctionTransaction> adminCancelTransaction({
    required String transactionId,
    required String reason,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/transactions/$transactionId/cancel'),
        headers: headers,
        body: json.encode({
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuctionTransaction.fromJson(data['transaction']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to cancel transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to cancel transaction: $e');
    }
  }

  // ==================== WEBSOCKET REAL-TIME UPDATES ====================

  /// Subscribe to transaction updates via WebSocket
  /// 
  /// Returns a stream of transaction updates for real-time status changes
  Stream<AuctionTransaction> subscribeToTransactionUpdates(String transactionId) async* {
    // This would integrate with your existing WebSocket service
    // For now, we'll poll every 30 seconds as a fallback
    while (true) {
      try {
        final transaction = await getTransaction(transactionId);
        yield transaction;
        
        // If transaction is complete or cancelled, stop polling
        if (transaction.status.isFinal) {
          break;
        }
      } catch (e) {
        print('Error polling transaction updates: $e');
      }
      
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  // ==================== HELPER METHODS ====================

  /// Check if buyer can pay for this transaction
  Future<bool> canBuyerPay(String transactionId) async {
    try {
      final transaction = await getTransaction(transactionId);
      return transaction.status == TransactionStatus.invoiceGenerated;
    } catch (e) {
      return false;
    }
  }

  /// Check if seller can ship
  Future<bool> canSellerShip(String transactionId) async {
    try {
      final transaction = await getTransaction(transactionId);
      return transaction.status == TransactionStatus.fundsHeldInEscrow;
    } catch (e) {
      return false;
    }
  }

  /// Check if buyer can confirm receipt
  Future<bool> canBuyerConfirm(String transactionId) async {
    try {
      final transaction = await getTransaction(transactionId);
      return transaction.status == TransactionStatus.sellerShipsVehicle ||
             transaction.status == TransactionStatus.buyerConfirmsReceipt;
    } catch (e) {
      return false;
    }
  }

  /// Get transaction timeline/history
  Future<List<Map<String, dynamic>>> getTransactionHistory(String transactionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions/$transactionId/history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['history']);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transaction history: $e');
    }
  }
}
