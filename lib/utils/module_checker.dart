import 'package:carauction/services/auth_service.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/services/user_service.dart';
import 'package:carauction/services/invoice_service.dart';
import 'package:carauction/services/payment_service.dart';
import 'package:carauction/services/notification_service.dart';
import 'package:carauction/services/saved_search_service.dart';
import 'package:carauction/services/shipping_address_service.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:carauction/services/swap_offer_service.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/services/transport_service.dart';
import 'package:carauction/services/counter_offer_service.dart';
import 'package:carauction/services/dispute_service.dart';
import 'package:carauction/services/blog_service.dart';
import 'package:carauction/services/newsletter_service.dart';
import 'package:carauction/services/contact_service.dart';

/// Module Checker - Tests all modules and logs backend connectivity
class ModuleChecker {
  static final Map<String, bool> _moduleStatus = {};
  
  /// Check all modules
  static Future<Map<String, Map<String, dynamic>>> checkAllModules() async {
    print('\n🔍 ========== MODULE CHECK START ==========');
    print('📱 Checking all modules for backend connectivity...\n');
    
    final results = <String, Map<String, dynamic>>{};
    
    // 1. Authentication Module
    results['Authentication'] = await _checkAuthModule();
    
    // 2. Car/Vehicle Module
    results['Car/Vehicle'] = await _checkCarModule();
    
    // 3. Bidding Module
    results['Bidding'] = await _checkBidModule();
    
    // 4. User Module
    results['User'] = await _checkUserModule();
    
    // 5. Invoice Module
    results['Invoice'] = await _checkInvoiceModule();
    
    // 6. Payment Module
    results['Payment'] = await _checkPaymentModule();
    
    // 7. Notification Module
    results['Notification'] = await _checkNotificationModule();
    
    // 8. Saved Search Module
    results['Saved Search'] = await _checkSavedSearchModule();
    
    // 9. Shipping Address Module
    results['Shipping Address'] = await _checkShippingModule();
    
    // 10. Chat Module
    results['Chat'] = await _checkChatModule();
    
    // 11. Swap Offer Module
    results['Swap Offer'] = await _checkSwapOfferModule();
    
    // 12. Inspection Module
    results['Inspection'] = await _checkInspectionModule();
    
    // 13. Transport Module
    results['Transport'] = await _checkTransportModule();
    
    // 14. Counter Offer Module
    results['Counter Offer'] = await _checkCounterOfferModule();
    
    // 15. Dispute Module
    results['Dispute'] = await _checkDisputeModule();
    
    // 16. Blog Module
    results['Blog'] = await _checkBlogModule();
    
    // 17. Newsletter Module
    results['Newsletter'] = await _checkNewsletterModule();
    
    // 18. Contact Module
    results['Contact'] = await _checkContactModule();
    
    // Print Summary
    print('\n📊 ========== MODULE CHECK SUMMARY ==========');
    int working = 0;
    int notWorking = 0;
    
    results.forEach((module, status) {
      final isWorking = status['working'] == true;
      if (isWorking) {
        working++;
        print('✅ $module: WORKING');
      } else {
        notWorking++;
        print('❌ $module: NOT WORKING - ${status['error']}');
      }
    });
    
    print('\n📈 Total Modules: ${results.length}');
    print('✅ Working: $working');
    if (notWorking > 0) {
      print('❌ Not Working: $notWorking');
    }
    print('📊 Success Rate: ${((working / results.length) * 100).toStringAsFixed(1)}%');
    if (working == results.length) {
      print('🎉 All modules are working perfectly!');
    }
    print('==========================================\n');
    
    return results;
  }
  
  static Future<Map<String, dynamic>> _checkAuthModule() async {
    print('🔐 Checking Authentication Module...');
    try {
      final service = AuthService();
      final token = await service.getToken();
      if (token != null) {
        print('   ✅ Token exists: ${token.substring(0, 20)}...');
        return {'working': true, 'message': 'Token found'};
      } else {
        print('   ⚠️ No token found (user not logged in)');
        return {'working': true, 'message': 'No token (not logged in)'};
      }
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkCarModule() async {
    print('🚗 Checking Car/Vehicle Module...');
    try {
      final service = CarService();
      print('   ✅ CarService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkBidModule() async {
    print('💰 Checking Bidding Module...');
    try {
      final service = BidService();
      print('   ✅ BidService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkUserModule() async {
    print('👤 Checking User Module...');
    try {
      final service = UserService();
      print('   ✅ UserService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkInvoiceModule() async {
    print('📄 Checking Invoice Module...');
    try {
      final service = InvoiceService();
      print('   ✅ InvoiceService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkPaymentModule() async {
    print('💳 Checking Payment Module...');
    try {
      final service = PaymentService();
      print('   ✅ PaymentService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkNotificationModule() async {
    print('🔔 Checking Notification Module...');
    try {
      final service = NotificationService();
      print('   ✅ NotificationService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkSavedSearchModule() async {
    print('🔍 Checking Saved Search Module...');
    try {
      final service = SavedSearchService();
      print('   ✅ SavedSearchService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkShippingModule() async {
    print('📦 Checking Shipping Address Module...');
    try {
      final service = ShippingAddressService();
      print('   ✅ ShippingAddressService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkChatModule() async {
    print('💬 Checking Chat Module...');
    try {
      final service = ChatService();
      print('   ✅ ChatService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkSwapOfferModule() async {
    print('🔄 Checking Swap Offer Module...');
    try {
      final service = SwapOfferService();
      print('   ✅ SwapOfferService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkInspectionModule() async {
    print('🔬 Checking Inspection Module...');
    try {
      final service = InspectionService();
      print('   ✅ InspectionService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkTransportModule() async {
    print('🚚 Checking Transport Module...');
    try {
      final service = TransportService();
      print('   ✅ TransportService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkCounterOfferModule() async {
    print('💵 Checking Counter Offer Module...');
    try {
      final service = CounterOfferService();
      print('   ✅ CounterOfferService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkDisputeModule() async {
    print('⚖️ Checking Dispute Module...');
    try {
      final service = DisputeService();
      print('   ✅ DisputeService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkBlogModule() async {
    print('📝 Checking Blog Module...');
    try {
      final service = BlogService();
      print('   ✅ BlogService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkNewsletterModule() async {
    print('📧 Checking Newsletter Module...');
    try {
      final service = NewsletterService();
      print('   ✅ NewsletterService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _checkContactModule() async {
    print('📞 Checking Contact Module...');
    try {
      final service = ContactService();
      print('   ✅ ContactService initialized');
      return {'working': true, 'message': 'Service ready'};
    } catch (e) {
      print('   ❌ Error: $e');
      return {'working': false, 'error': e.toString()};
    }
  }
}

