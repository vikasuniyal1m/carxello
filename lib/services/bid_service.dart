import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class BidService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    print('🔑 BidService: Getting headers...');
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      print('   ✅ Token found: ${token.substring(0, 20)}...');
    } else {
      print('   ⚠️ No token found');
    }
    
    return headers;
  }

  /// Helper method to get auction ID from vehicle ID
  Future<int?> _getAuctionIdFromVehicleId(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/auctions?vehicle_id=$vehicleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        if (data is List && data.isNotEmpty) {
          return data[0]['id'] as int?;
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          final auctions = data['data'] as List;
          if (auctions.isNotEmpty) {
            return auctions[0]['id'] as int?;
          }
        } else if (data is Map && data.containsKey('id')) {
          return data['id'] as int?;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error fetching auction ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> placeBid(String vehicleId, double bidAmount, {double? maxBid}) async {
    try {
      print('💰 BidService.placeBid: Starting...');
      print('   📍 URL: $_baseUrl/bids');
      print('   🚗 Vehicle ID: $vehicleId');
      print('   💵 Bid Amount: $bidAmount');
      
      final headers = await _getHeaders();
      
      // Try to get auction ID first (for new database structure)
      int? auctionId = await _getAuctionIdFromVehicleId(vehicleId);
      
      // Prepare request body - support both old and new structure
      final requestBody = <String, dynamic>{
        'bid_amount': bidAmount,
        'max_bid': maxBid,
      };
      
      if (auctionId != null) {
        // New structure: use auction_id
        print('   🎯 Using auction_id: $auctionId');
        requestBody['auction_id'] = auctionId;
        requestBody['amount'] = bidAmount; // New field name
      } else {
        // Fallback to old structure: use vehicle_id
        print('   ⚠️ Auction not found, using vehicle_id (old structure)');
        requestBody['vehicle_id'] = vehicleId;
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/bids'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('📡 BidService: Response Status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        print('   ✅ BidService: Bid placed successfully');
        return json.decode(response.body);
      } else {
        print('   ❌ BidService: Failed with status ${response.statusCode}');
        print('   📦 BidService: Error body: ${response.body}');
        Map<String, dynamic>? errorBody;
        try {
          if (response.body.isNotEmpty) {
            final decoded = json.decode(response.body);
            if (decoded is Map<String, dynamic>) {
              errorBody = decoded;
            }
          }
        } catch (e) {
          print('   ⚠️ BidService: Failed to decode error body as JSON: $e');
        }
        final message = errorBody?['error'] ??
            errorBody?['message'] ??
            (response.body.isNotEmpty ? response.body : 'Failed to place bid: ${response.statusCode}');
        throw Exception(message);
      }
    } catch (e) {
      print('   ❌ BidService: Exception occurred: $e');
      // Rethrow so server error message (e.g. minimum bid) is shown as-is; wrap only unexpected errors
      final msg = e.toString();
      if (e is Exception && !msg.contains('Failed to place bid:')) {
        rethrow;
      }
      throw Exception('Failed to place bid: $e');
    }
  }

  Future<Map<String, dynamic>> buyNow(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      
      // Backend validator requires vehicle_id (not auction_id)
      // Always send vehicle_id as required by backend
      final requestBody = <String, dynamic>{
        'vehicle_id': vehicleId, // REQUIRED by backend validator
      };
      
      print('🎯 Buy Now: Using vehicle_id: $vehicleId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/bids/buy-now'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Buy Now bid created successfully');
        print('   📄 Bid ID: ${result['bid']?['id'] ?? 'N/A'}');
        print('   💰 Amount: \$${result['bid']?['amount'] ?? 'N/A'}');
        return result;
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? errorBody['message'] ?? 'Failed to process buy now: ${response.statusCode}';
        print('❌ Buy Now failed: $errorMessage');
        if (errorBody['errors'] != null) {
          print('   Validation errors: ${errorBody['errors']}');
        }
        throw Exception('Failed to process buy now: $errorMessage');
      }
    } catch (e) {
      print('❌ Buy Now error: $e');
      if (e.toString().contains('Failed to process buy now')) {
        rethrow;
      }
      throw Exception('Failed to process buy now: $e');
    }
  }

  Future<List<dynamic>> getVehicleBids(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      
      // Try to get auction ID first (for new database structure)
      int? auctionId = await _getAuctionIdFromVehicleId(vehicleId);
      
      Uri bidUrl;
      if (auctionId != null) {
        // New structure: use auction_id
        print('🎯 Get Bids: Using auction_id: $auctionId');
        bidUrl = Uri.parse('$_baseUrl/bids/auction/$auctionId');
      } else {
        // Fallback to old structure: use vehicle_id
        print('⚠️ Get Bids: Auction not found, using vehicle_id (old structure)');
        bidUrl = Uri.parse('$_baseUrl/bids/vehicle/$vehicleId');
      }
      
      final response = await http.get(
        bidUrl,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['bids'] as List<dynamic>;
      } else {
        throw Exception('Failed to load bids: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load bids: $e');
    }
  }

  Future<List<dynamic>> getMyBids({String? filter}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/bids/my-bids');
      final uriWithFilter = filter != null 
          ? uri.replace(queryParameters: {'filter': filter})
          : uri;
      
      final response = await http.get(
        uriWithFilter,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          print('⚠️ getMyBids: empty or invalid response');
          return [];
        }
        final rawBids = data['bids'] ?? data['data']?['bids'];
        final bids = rawBids is List ? List<dynamic>.from(rawBids) : <dynamic>[];
        print('📦 getMyBids API returned ${bids.length} bids');
        // Debug: Print Buy Now bids
        final buyNowBids = bids.where((bid) => (bid['is_buy_now'] as bool? ?? false)).toList();
        print('🛒 Buy Now bids found: ${buyNowBids.length}');
        if (buyNowBids.isNotEmpty) {
          print('🛒 Buy Now bid details: ${buyNowBids[0]}');
        }
        return bids;
      } else {
        print('❌ getMyBids API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load my bids: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ getMyBids error: $e');
      throw Exception('Failed to load my bids: $e');
    }
  }

  Future<Map<String, dynamic>> finalizeAuction(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bids/finalize-auction/$vehicleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to finalize auction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to finalize auction: $e');
    }
  }

  Future<void> withdrawBid(String bidId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/bids/$bidId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to withdraw bid: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to withdraw bid: $e');
    }
  }

  Future<Map<String, dynamic>> getBuyerBidAnalytics() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/bids/analytics/buyer'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load bid analytics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load bid analytics: $e');
    }
  }

  /// Place-bid info for any authenticated user: minimum_bid, my_bid_amount (for pre-fill when updating).
  Future<Map<String, dynamic>> getPlaceBidInfo(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/bids/place-bid-info/vehicle/$vehicleId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      final errorBody = response.body.isNotEmpty ? json.decode(response.body) : <String, dynamic>{};
      throw Exception(errorBody['error'] ?? 'Failed to load place-bid info');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to load place-bid info: $e');
    }
  }

  Future<Map<String, dynamic>> getVehicleBidAnalytics(String vehicleId) async {
    try {
      print('📊 BidService: Getting vehicle bid analytics for vehicle: $vehicleId');
      final headers = await _getHeaders();
      final url = '$_baseUrl/bids/analytics/vehicle/$vehicleId';
      print('   📍 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('   📡 Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('   ✅ Analytics fetched successfully');
        return data;
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? 'Failed to load vehicle bid analytics: ${response.statusCode}';
        print('   ❌ Analytics API Error (${response.statusCode}): $errorMessage');
        if (errorBody['file'] != null) {
          print('   📄 Error File: ${errorBody['file']}');
          print('   📄 Error Line: ${errorBody['line']}');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('   ❌ Analytics Service Error: $e');
      if (e.toString().contains('Failed to load vehicle bid analytics')) {
        rethrow;
      }
      throw Exception('Failed to load vehicle bid analytics: $e');
    }
  }

  Future<Map<String, dynamic>> getBidderInfo(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/bids/bidder/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load bidder info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load bidder info: $e');
    }
  }

  /// Check if user has a buy now bid for a vehicle
  Future<bool> hasBuyNowBid(String vehicleId) async {
    try {
      final bids = await getMyBids();
      return bids.any((bid) {
        final vehicle = bid['vehicle'] as Map<String, dynamic>?;
        final isBuyNow = bid['is_buy_now'] as bool? ?? false;
        return vehicle != null && 
               vehicle['id'].toString() == vehicleId && 
               isBuyNow;
      });
    } catch (e) {
      print('⚠️ Error checking buy now bid: $e');
      return false;
    }
  }

  /// Check if user has any bid (regular or buy now) for a vehicle
  Future<bool> hasAnyBid(String vehicleId) async {
    try {
      final bids = await getMyBids();
      return bids.any((bid) {
        final vehicle = bid['vehicle'] as Map<String, dynamic>?;
        return vehicle != null && vehicle['id'].toString() == vehicleId;
      });
    } catch (e) {
      print('⚠️ Error checking any bid: $e');
      return false;
    }
  }

  /// Get user's current bid for a specific vehicle (regular bid only)
  Future<Map<String, dynamic>?> getCurrentBid(String vehicleId) async {
    try {
      final bids = await getMyBids();
      final vid = vehicleId.toString();
      for (var bid in bids) {
        final vehicle = bid['vehicle'] as Map<String, dynamic>?;
        if (vehicle == null) continue;
        final bidVehicleId = vehicle['id']?.toString();
        if (bidVehicleId == null || bidVehicleId != vid) continue;
        final isBuyNow = bid['is_buy_now'] as bool? ?? false;
        if (!isBuyNow) return bid as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting current bid: $e');
      return null;
    }
  }

  /// Get user's pending Buy Now bid for a specific vehicle
  Future<Map<String, dynamic>?> getPendingBuyNowBid(String vehicleId) async {
    try {
      final bids = await getMyBids();
      for (var bid in bids) {
        final vehicle = bid['vehicle'] as Map<String, dynamic>?;
        if (vehicle != null && vehicle['id'].toString() == vehicleId) {
          final isBuyNow = bid['is_buy_now'] as bool? ?? false;
          final isWinning = bid['is_winning_bid'] as bool? ?? false;
          // Return only pending Buy Now bids (not yet accepted)
          if (isBuyNow && !isWinning) {
            return bid;
          }
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting pending buy now bid: $e');
      return null;
    }
  }

  /// Accept a bid (Seller only)
  Future<Map<String, dynamic>> acceptBid(String bidId) async {
    try {
      print('✅ BidService: Accepting bid ID: $bidId');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bids/$bidId/accept'),
        headers: headers,
      );

      print('📡 Accept Bid Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Bid accepted successfully');
        print('   📄 Bid ID: ${result['bid']?['id'] ?? 'N/A'}');
        print('   💰 Amount: \$${result['bid']?['amount'] ?? 'N/A'}');
        print('   🚗 Vehicle Status: ${result['vehicle']?['status'] ?? 'N/A'}');
        return result;
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? 'Failed to accept bid: ${response.statusCode}';
        print('❌ Accept Bid failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Accept Bid error: $e');
      if (e.toString().contains('Failed to accept bid')) {
        rethrow;
      }
      throw Exception('Failed to accept bid: $e');
    }
  }

  /// Reject a bid (Seller only)
  Future<Map<String, dynamic>> rejectBid(String bidId) async {
    try {
      print('❌ BidService: Rejecting bid ID: $bidId');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bids/$bidId/reject'),
        headers: headers,
      );

      print('📡 Reject Bid Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Bid rejected successfully');
        print('   📄 Bid ID: ${result['bid']?['id'] ?? 'N/A'}');
        print('   📊 Status: ${result['bid']?['status'] ?? 'N/A'}');
        return result;
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMessage = errorBody['error'] ?? 'Failed to reject bid: ${response.statusCode}';
        print('❌ Reject Bid failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Reject Bid error: $e');
      if (e.toString().contains('Failed to reject bid')) {
        rethrow;
      }
      throw Exception('Failed to reject bid: $e');
    }
  }

  /// Accept a buy now bid (Seller only)
  Future<Map<String, dynamic>> acceptBuyNow(String bidId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bids/$bidId/accept-buy-now'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to accept buy now bid: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to accept buy now bid: $e');
    }
  }

  /// Reject a buy now bid (Seller only)
  Future<void> rejectBuyNow(String bidId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bids/$bidId/reject-buy-now'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to reject buy now bid: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to reject buy now bid: $e');
    }
  }
}

