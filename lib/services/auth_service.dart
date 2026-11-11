import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Import for BuildContext and Navigator
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/notification_controller.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'websocket_service.dart';
import 'push_notification_service.dart';

class AuthService {
  String get _baseUrl => ApiConfig.baseUrl;

  /// Reload notification inbox after token + user id are saved (login / social auth).
  void _scheduleNotificationsSyncAfterAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (Get.isRegistered<NotificationController>()) {
          await Get.find<NotificationController>().refreshAfterAuth();
        }
      } catch (e) {
        print('⚠️ AuthService: notifications sync after auth: $e');
      }
    });
  }

  /// Call right after [token] and user prefs are written — before navigation. Avoids a race where polling runs before post-frame [refreshAfterAuth].
  Future<void> _syncNotificationsInboxAfterTokenSave() async {
    try {
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().refreshAfterAuth();
      }
      if (!Get.isRegistered<BidController>()) {
        Get.put(BidController(), permanent: true);
      }
      await Get.find<BidController>().fetchMyBids();
    } catch (e) {
      print('⚠️ AuthService: notifications sync after token save: $e');
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String role, String companyName, String phoneNumber) async {
    try {
      // Map role to database enum values
      // Database enum: 'seller/buyer', 'dealer', 'transporter', 'inspector'
      String normalizedRole = role.toLowerCase();
      
      // Map frontend role values to database enum values
      if (normalizedRole == 'seller' || normalizedRole == 'buyer' || normalizedRole == 'seller/buyer') {
        normalizedRole = 'seller/buyer'; // Database enum value
      } else if (normalizedRole == 'dealer') {
        normalizedRole = 'dealer';
      } else if (normalizedRole == 'transporter') {
        normalizedRole = 'transporter';
      } else if (normalizedRole == 'inspector') {
        normalizedRole = 'inspector';
      }
      
      print('🔑 Registration Role: $role → Normalized: $normalizedRole');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': normalizedRole,
          'company_name': companyName.isEmpty ? null : companyName,
          'phone_number': phoneNumber.isEmpty ? null : phoneNumber,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check:\n1. Laravel server is running (php artisan serve)\n2. Server is accessible from emulator');
        },
      );

      print('📡 Registration Response Status: ${response.statusCode}');
      print('📡 Registration Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - save token and user data
        if (responseData['access_token'] != null) {
          try {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', responseData['access_token']);
            
            // Save user role
            if (role.isNotEmpty) {
              await PreferencesHelper.saveUserRole(role);
            }
            
            // Save user ID and role-based IDs
            if (responseData['user'] != null) {
              final user = responseData['user'];
              final userId = user['id']?.toString() ?? user['user_id']?.toString();
              if (userId != null) {
                await PreferencesHelper.saveUserId(userId);
                
                // Save role-based IDs
                final serverRole =
                    (user['role'] ?? role).toString().toLowerCase().trim();
                if (serverRole == 'seller/buyer') {
                  await PreferencesHelper.saveBuyerId(userId);
                  await PreferencesHelper.saveSellerId(userId);
                  await PreferencesHelper.saveBuyerSellerMode('buyer');
                } else if (role.toLowerCase() == 'buyer') {
                  await PreferencesHelper.saveBuyerId(userId);
                } else if (role.toLowerCase() == 'seller') {
                  await PreferencesHelper.saveSellerId(userId);
                }
              }
            }
            
            // Save user metadata
            await prefs.setString('user_name', name);
            await prefs.setString('user_email', email);
            if (companyName.isNotEmpty) {
              await prefs.setString('user_company_name', companyName);
            }
            if (phoneNumber.isNotEmpty) {
              await prefs.setString('user_phone_number', phoneNumber);
            }
          } catch (e) {
            print('⚠️ AuthService.login: SharedPreferences error saving data: $e');
            // Continue even if SharedPreferences fails - try to save role separately
            try {
              if (role.isNotEmpty) {
                await PreferencesHelper.saveUserRole(role);
              }
              
              // Try to save user ID and role-based IDs
              if (responseData['user'] != null) {
                final user = responseData['user'];
                final userId = user['id']?.toString() ?? user['user_id']?.toString();
                if (userId != null) {
                  await PreferencesHelper.saveUserId(userId);
                  
                  final serverRole =
                      (user['role'] ?? role).toString().toLowerCase().trim();
                  if (serverRole == 'seller/buyer') {
                    await PreferencesHelper.saveBuyerId(userId);
                    await PreferencesHelper.saveSellerId(userId);
                    await PreferencesHelper.saveBuyerSellerMode('buyer');
                  } else if (role.toLowerCase() == 'buyer') {
                    await PreferencesHelper.saveBuyerId(userId);
                  } else if (role.toLowerCase() == 'seller') {
                    await PreferencesHelper.saveSellerId(userId);
                  }
                }
              }
            } catch (e2) {
              print('⚠️ AuthService.login: Error saving role/user data: $e2');
            }
          }
          await _syncNotificationsInboxAfterTokenSave();
        }
        return responseData;
      } else {
        // Error response - log full details
        print('❌ Registration Error: Status ${response.statusCode}');
        print('❌ Error Response: ${response.body}');
        
        String errorMessage = responseData['message'] ?? 'Registration failed';
        
        // Check for detailed error message
        if (responseData['error_message'] != null) {
          errorMessage = responseData['error_message'];
          print('📋 Detailed Error: $errorMessage');
        }
        
        // Check for error details
        if (responseData['details'] != null) {
          final details = responseData['details'];
          if (details is Map && details['message'] != null) {
            errorMessage = details['message'];
            print('📋 Error Details: ${details.toString()}');
          }
        }
        
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          final errorList = <String>[];
          errors.forEach((key, value) {
            if (value is List) {
              errorList.addAll(value.map((e) => e.toString()));
            } else {
              errorList.add(value.toString());
            }
          });
          if (errorList.isNotEmpty) {
            errorMessage = errorList.join('\n');
          }
        }
        
        return {
          'error': errorMessage,
          'errors': responseData['errors'],
          'status_code': response.statusCode,
          'error_message': responseData['error_message'],
          'details': responseData['details'],
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please check:\n1. Laravel server is running: php artisan serve\n2. Server is accessible from emulator';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please check:\n1. Laravel server is running\n2. Server is accessible from emulator';
      }
      return {
        'error': errorMessage,
      };
    }
  }

  Future<Map<String, dynamic>> login(BuildContext context, String email, String password, String role) async {
    try {
      final loginUrl = '$_baseUrl/login'.replaceAll(RegExp(r'/+'), '/').replaceAll(':/', '://');
      print('🔗 Attempting login to: $loginUrl');
      final configInfo = ApiConfig.getConfigInfo();
      print('📱 API Config: $configInfo');
      print('📱 Base URL from configInfo: ${configInfo['baseUrl']}');
      
      // Test connection first (non-blocking, just for debugging)
      try {
        final testResponse = await http.get(
          Uri.parse('$_baseUrl/test'.replaceAll(RegExp(r'/+'), '/').replaceAll(':/', '://')),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        print('✅ Server connection test: ${testResponse.statusCode}');
        print('✅ Server is reachable! Connection successful!');
      } catch (e) {
        print('⚠️ ========== SERVER CONNECTION TEST FAILED ==========');
        print('⚠️ Error: $e');
        print('⚠️ This indicates network connectivity issues');
        print('⚠️');
        print('⚠️ QUICK FIX STEPS:');
        print('⚠️ 1. Check your IP address:');
        print('⚠️    • Windows: Run "ipconfig" in CMD');
        print('⚠️    • Mac/Linux: Run "ifconfig"');
        print('⚠️    • Look for IPv4 Address (e.g., 192.168.x.x)');
        print('⚠️');
        print('⚠️ 2. Update api_config.dart:');
        print('⚠️    • Open: carauction/lib/utils/api_config.dart');
        print('⚠️    • Line 17: Update localIP = "YOUR_ACTUAL_IP"');
        print('⚠️');
        print('⚠️ 3. Verify same WiFi:');
        print('⚠️    • Phone और computer same WiFi पर होने चाहिए');
        print('⚠️    • Mobile data बंद करें');
        print('⚠️');
        print('⚠️ 4. Test from phone browser:');
        print('⚠️    • Open: http://${ApiConfig.getConfigInfo()['localIP']}:8000/test');
        print('⚠️    • अगर browser में काम करता hai, तो IP सही hai');
        print('⚠️');
        print('⚠️ 5. Check Laravel server:');
        print('⚠️    • Run: cd laravel_backend && php artisan serve');
        print('⚠️');
        print('⚠️ 6. Check firewall:');
        print('⚠️    • Windows Firewall में port 8000 allow करें');
        print('⚠️ ==========================================');
        // Continue anyway - might be that /test endpoint doesn't exist
      }
      
      // Convert role to lowercase for backend compatibility
      final normalizedRole = role.toLowerCase();
      print('🔑 Login Role: $role → Normalized: $normalizedRole');
      
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'role': normalizedRole}),
      ).timeout(
        const Duration(seconds: 30), // Increased from 10 to 30 seconds
        onTimeout: () {
          throw Exception('Connection timeout after 30 seconds. Please check:\n1. Laravel server is running: php artisan serve\n2. Server is accessible from emulator/device\n3. Check API config: ${ApiConfig.getConfigInfo()['baseUrl']}');
        },
      );

      print('📡 Login API Response Status Code: ${response.statusCode}');
      final responseData = jsonDecode(response.body);
      print('📦 Login API Response Data: ${responseData.toString().substring(0, responseData.toString().length > 200 ? 200 : responseData.toString().length)}');

      // Handle 422 validation errors (like role mismatch)
      if (response.statusCode == 422) {
        final errorMessage = responseData['message'] ?? 'Validation error';
        final errors = responseData['errors'] ?? {};
        print('❌ Login validation error (422): $errorMessage');
        print('❌ Errors: $errors');
        
        // Return error with details
        return {
          'error': errorMessage,
          'errors': errors,
          'status_code': 422,
        };
      }

      if (response.statusCode == 200 && responseData['access_token'] != null) {
        try {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', responseData['access_token']);
        } catch (e) {
          print('⚠️ AuthService.loginWithEmail: SharedPreferences error saving token: $e');
          // Continue even if SharedPreferences fails
        }
        String? userRole = role.toLowerCase();
        if (responseData['user'] != null && responseData['user']['role'] != null) {
          userRole = responseData['user']['role'].toString().toLowerCase();
        }
        await PreferencesHelper.saveUserRole(userRole);
        
        // Save user ID and role-based IDs
        if (responseData['user'] != null) {
          final user = responseData['user'];
          final userId = user['id']?.toString() ?? user['user_id']?.toString();
          if (userId != null) {
            await PreferencesHelper.saveUserId(userId);
            
            // Save role-based IDs
            // Backend enum: 'seller/buyer', 'dealer', 'transporter', 'inspector'
            if (userRole == 'seller/buyer') {
              // Seller/Buyer can be both, save as buyer by default
              await PreferencesHelper.saveBuyerId(userId);
              await PreferencesHelper.saveSellerId(userId);
            } else if (userRole == 'dealer') {
              // Dealer is similar to seller
              await PreferencesHelper.saveSellerId(userId);
            } else if (userRole == 'buyer') {
              await PreferencesHelper.saveBuyerId(userId);
            } else if (userRole == 'seller') {
              await PreferencesHelper.saveSellerId(userId);
            }
          }
        }
        await _syncNotificationsInboxAfterTokenSave();
        // Navigate based on role - use postFrameCallback to ensure navigation happens after current frame
        if (!context.mounted) {
          print('⚠️ Context not mounted, cannot navigate');
          return {};
        }
        
        // Connect WebSocket after successful login (non-blocking)
        // Note: If backend WebSocket endpoint doesn't exist, app will use polling instead
        WebSocketService.instance.connect().catchError((e) {
          print('⚠️ WebSocket: Connection failed (app will use polling): $e');
        });
        

        
        print('🚀 Navigating to home page for role: $userRole');
        // Use postFrameCallback to ensure safe navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          try {
            if (userRole == 'inspector') {
              Navigator.pushReplacementNamed(context, '/inspector-home');
            } else if (userRole == 'transporter') {
              Navigator.pushReplacementNamed(context, '/transporter-home');
            } else {
              print('🏠 Navigating to /home route');
              Navigator.pushReplacementNamed(context, '/home');
              print('✅ Navigation to /home completed');
            }
            _scheduleNotificationsSyncAfterAuth();
          } catch (e) {
            print('❌ Navigation error: $e');
          }
        });
      } else {
        print('❌ Login failed: ${responseData['message'] ?? responseData['error'] ?? 'Unknown error'}');
      }
      return responseData;
    } catch (e) {
      print('❌ Error during login API call: $e');
      print('🔧 Current API Config: ${ApiConfig.getConfigInfo()}');
      
      String errorMessage = 'Network error: ${e.toString()}';
      final configInfo = ApiConfig.getConfigInfo();
      
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('No route to host') ||
          e.toString().contains('Network is unreachable')) {
        final isPhysical = configInfo['usePhysicalDevice'] == true;
        final deviceType = isPhysical ? 'Physical Device' : 'Emulator';
        final currentIP = isPhysical ? configInfo['localIP'] : '10.0.2.2';
        
        // Detect specific error type
        String errorType = 'Connection Error';
        if (e.toString().contains('No route to host')) {
          errorType = 'No Route to Host - Network connectivity issue';
        } else if (e.toString().contains('Network is unreachable')) {
          errorType = 'Network Unreachable';
        } else if (e.toString().contains('Failed host lookup')) {
          errorType = 'Host Not Found - IP address may be wrong';
        }
        
        errorMessage = '❌ $errorType\n\n'
            '📱 Device Type: $deviceType\n'
            '🌐 Server URL: ${configInfo['baseUrl']}\n'
            '🔢 IP Address: $currentIP\n'
            '🔌 Port: ${configInfo['serverPort']}\n\n'
            '🔧 Troubleshooting Steps:\n\n'
            '1️⃣ Check IP Address:\n'
            '   • Windows: Run "ipconfig" in CMD\n'
            '   • Mac/Linux: Run "ifconfig"\n'
            '   • Look for IPv4 Address (e.g., 192.168.x.x)\n'
            '   • Update in api_config.dart: localIP = "YOUR_IP"\n\n'
            '2️⃣ Verify Same WiFi:\n'
            '   • Phone और computer same WiFi पर होने चाहिए\n'
            '   • Mobile data बंद करें\n'
            '   • WiFi network name same check करें\n\n'
            '3️⃣ Test from Phone Browser:\n'
            '   • Phone browser में open करें:\n'
            '   • http://$currentIP:${configInfo['serverPort']}/test\n'
            '   • अगर browser में काम करता hai, तो IP सही hai\n\n'
            '4️⃣ Check Laravel Server:\n'
            '   • Terminal में: cd laravel_backend\n'
            '   • Run: php artisan serve\n'
            '   • Server running होना चाहिए\n\n'
            '5️⃣ Check Firewall:\n'
            '   • Windows Firewall में port ${configInfo['serverPort']} allow करें\n'
            '   • Antivirus firewall check करें\n\n'
            '6️⃣ Restart Everything:\n'
            '   • Laravel server restart करें\n'
            '   • App restart करें\n'
            '   • Phone WiFi reconnect करें';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout.\n\n'
            'Server URL: ${configInfo['baseUrl']}\n\n'
            'Please check:\n'
            '1. Laravel server is running: php artisan serve\n'
            '2. Check firewall settings\n'
            '3. Try restarting Laravel server\n'
            '4. Verify server is accessible from device\n'
            '5. Check network connection';
      }
      return {'error': errorMessage};
    }
  }

  Future<String?> getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('⚠️ AuthService.getToken: SharedPreferences error: $e');
      // Return null if SharedPreferences fails - app can continue without token
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Revoke token on server
      try {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          final resp = await http.post(
            Uri.parse('$_baseUrl/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 12), onTimeout: () => http.Response('', 408));
          print('📡 Server logout status: ${resp.statusCode}');
        }
      } catch (e) {
        print('⚠️ Server logout call failed (continuing local cleanup): $e');
      }

      // Disconnect WebSocket
      try {
        WebSocketService.instance.disconnect();
        print('✅ WebSocket disconnected on logout');
      } catch (e) {
        print('⚠️ WebSocket disconnect error: $e');
      }

      // Clear all session data from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Get saved credentials before clearing everything (to keep them as requested)
      String? savedEmail = prefs.getString('email');
      String? savedPassword = prefs.getString('password');

      // Clear all local data thoroughly
      await prefs.clear();

      // Restore only the username (email) and password as requested
      if (savedEmail != null) {
        await prefs.setString('email', savedEmail);
      }
      if (savedPassword != null) {
        await prefs.setString('password', savedPassword);
      }

      print('✅ Logout: All local data cleared (except username and password)');

      try {
        if (Get.isRegistered<BidController>()) {
          Get.find<BidController>().clearSession();
        }
      } catch (e) {
        print('⚠️ Logout: BidController cleanup: $e');
      }
    } catch (e) {
      print('⚠️ Logout error: $e');
      // Still try to clear token if nothing else was possible
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
      } catch (e2) {
        print('❌ Failed to clear token: $e2');
      }
    }
  }

  Future<void> deleteAccount() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/user/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Account deleted successfully
        return;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete account');
      }
    } catch (e) {
      print('❌ Error deleting account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  /// Sign in with Apple
  Future<Map<String, dynamic>> signInWithApple(BuildContext context, String role) async {
    try {
      print('🍎 Starting Apple Sign In...');
      
      // Check if Apple Sign In is available (iOS 13+ or macOS 10.15+)
      if (!Platform.isIOS && !Platform.isMacOS) {
        return {
          'error': 'Apple Sign In is only available on iOS and macOS devices',
        };
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      print('🍎 Apple Sign In successful!');
      print('🍎 User ID: ${appleCredential.userIdentifier}');
      print('🍎 Email: ${appleCredential.email ?? 'Not provided'}');
      print('🍎 Given Name: ${appleCredential.givenName ?? 'Not provided'}');
      print('🍎 Family Name: ${appleCredential.familyName ?? 'Not provided'}');

      // Extract user information
      final email = appleCredential.email;
      final firstName = appleCredential.givenName ?? '';
      final lastName = appleCredential.familyName ?? '';
      final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
      final displayName = fullName.isNotEmpty ? fullName : (email?.split('@')[0] ?? 'Apple User');
      final identityToken = appleCredential.identityToken;
      final authorizationCode = appleCredential.authorizationCode;

      // If email is not provided (first time sign in), we'll need to handle it
      if (email == null || email.isEmpty) {
        // Check if user already exists in our system
        // For now, we'll use the user identifier as a fallback
        print('⚠️ Email not provided by Apple. Using user identifier.');
      }

      // Normalize role
      String normalizedRole = role.toLowerCase();
      if (normalizedRole == 'seller' || normalizedRole == 'buyer' || normalizedRole == 'seller/buyer') {
        normalizedRole = 'seller/buyer';
      } else if (normalizedRole == 'dealer') {
        normalizedRole = 'dealer';
      } else if (normalizedRole == 'transporter') {
        normalizedRole = 'transporter';
      } else if (normalizedRole == 'inspector') {
        normalizedRole = 'inspector';
      }

      print('🔑 Apple Sign In Role: $role → Normalized: $normalizedRole');

      // Send Apple credentials to backend for authentication/registration
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/apple'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'apple_user_id': appleCredential.userIdentifier,
          'email': email,
          'name': displayName,
          'first_name': firstName,
          'last_name': lastName,
          'identity_token': identityToken,
          'authorization_code': authorizationCode,
          'role': normalizedRole,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      print('📡 Apple Sign In Response Status: ${response.statusCode}');
      final responseData = jsonDecode(response.body);
      print('📦 Apple Sign In Response: ${responseData.toString().substring(0, responseData.toString().length > 200 ? 200 : responseData.toString().length)}');

      // Handle successful authentication
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['access_token'] != null) {
          // Save token and user data
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', responseData['access_token']);
          
          // Save user role
          if (normalizedRole.isNotEmpty) {
            await PreferencesHelper.saveUserRole(normalizedRole);
          }
          
          // Save user ID and role-based IDs
          if (responseData['user'] != null) {
            final user = responseData['user'];
            final userId = user['id']?.toString() ?? user['user_id']?.toString();
            if (userId != null) {
              await PreferencesHelper.saveUserId(userId);
              
              // Save role-based IDs
              if (normalizedRole == 'seller/buyer') {
                await PreferencesHelper.saveBuyerId(userId);
                await PreferencesHelper.saveSellerId(userId);
              } else if (normalizedRole == 'dealer') {
                await PreferencesHelper.saveSellerId(userId);
              } else if (normalizedRole == 'buyer') {
                await PreferencesHelper.saveBuyerId(userId);
              } else if (normalizedRole == 'seller') {
                await PreferencesHelper.saveSellerId(userId);
              }
            }
          }
          
          // Save user metadata
          if (displayName.isNotEmpty) {
            await prefs.setString('user_name', displayName);
          }
          if (email != null && email.isNotEmpty) {
            await prefs.setString('user_email', email);
          }
          
          await _syncNotificationsInboxAfterTokenSave();
          // Connect WebSocket after successful login
          WebSocketService.instance.connect().catchError((e) {
            print('⚠️ WebSocket: Connection failed (app will use polling): $e');
          });
          

          
          // Navigate based on role
          if (!context.mounted) {
            print('⚠️ Context not mounted, cannot navigate');
            return responseData;
          }
          
          final userRole = normalizedRole;
          print('🚀 Navigating to home page for role: $userRole');
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            try {
              if (userRole == 'inspector') {
                Navigator.pushReplacementNamed(context, '/inspector-home');
              } else if (userRole == 'transporter') {
                Navigator.pushReplacementNamed(context, '/transporter-home');
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
              _scheduleNotificationsSyncAfterAuth();
            } catch (e) {
              print('❌ Navigation error: $e');
            }
          });
        }
        return responseData;
      } else {
        // Handle error response
        String errorMessage = responseData['message'] ?? 'Apple Sign In failed';
        if (responseData['error'] != null) {
          errorMessage = responseData['error'];
        }
        print('❌ Apple Sign In Error: $errorMessage');
        return {
          'error': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      print('❌ Apple Sign In Authorization Exception: ${e.code}');
      String errorMessage = 'Apple Sign In cancelled';
      if (e.code == AuthorizationErrorCode.invalidResponse) {
        errorMessage = 'Invalid response from Apple. Please try again.';
      } else if (e.code == AuthorizationErrorCode.notHandled) {
        errorMessage = 'Apple Sign In not handled. Please check your device settings.';
      } else if (e.code == AuthorizationErrorCode.unknown) {
        errorMessage = 'Unknown error occurred. Please try again.';
      }
      return {'error': errorMessage};
    } catch (e) {
      print('❌ Apple Sign In Exception: $e');
      String errorMessage = 'Network error: ${e.toString()}';
      if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
        errorMessage = 'Unable to reach our servers. Please check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      }
      return {'error': errorMessage};
    }
  }

  /// Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle(BuildContext context, String role) async {
    try {
      print('🔵 Starting Google Sign In...');

      // Normalize role to backend enum values
      String normalizedRole = role.toLowerCase();
      if (normalizedRole == 'seller' || normalizedRole == 'buyer' || normalizedRole == 'seller/buyer') {
        normalizedRole = 'seller/buyer';
      } else if (normalizedRole == 'dealer') {
        normalizedRole = 'dealer';
      } else if (normalizedRole == 'transporter') {
        normalizedRole = 'transporter';
      } else if (normalizedRole == 'inspector') {
        normalizedRole = 'inspector';
      }

      // Android requires serverClientId (Web client ID); iOS uses GIDClientID from Info.plist.
      // Use singleton instance
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      
      // Initialize with serverClientId (only if not already initialized)
      try {
        await googleSignIn.initialize(
          serverClientId: ApiConfig.googleWebClientId,
        );
      } catch (e) {
        // Ignore if already initialized
        print('🔵 Initialize (may already be initialized): $e');
      }
      
      // Use authenticate() method with email scope
      // Note: authenticate() will handle sign-in flow, no need to sign out first
      final GoogleSignInAccount? account = await googleSignIn.authenticate(
        scopeHint: ['email'],
      );
      if (account == null) {
        // Handle cancellation or error
        return {'error': 'Google Sign-In cancelled or failed'};
      }

      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      print('🔵 Google Sign In successful');
      print('🔵 Email: ${account.email}');
      print('🔵 Name: ${account.displayName}');
      print('🔵 idToken: ${idToken != null ? 'received' : 'null'}');

      if (idToken == null) {
        return {'error': 'Unable to retrieve Google ID token'};
      }

      // Parse name and last name from displayName
      String firstName = '';
      String lastName = '';
      String fullName = account.displayName ?? account.email.split('@')[0];
      
      if (fullName.isNotEmpty) {
        final nameParts = fullName.trim().split(' ');
        if (nameParts.length > 1) {
          firstName = nameParts[0];
          lastName = nameParts.sublist(1).join(' ');
        } else {
          firstName = nameParts[0];
          lastName = '';
        }
      }
      
      print('🔵 Parsed Name - First: $firstName, Last: $lastName, Full: $fullName');
      
      final url = '$_baseUrl/auth/google'.replaceAll(RegExp(r'/+'), '/').replaceAll(':/', '://');
      print('🔵 Google Sign In URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
          'email': account.email,
          'name': fullName,
          'first_name': firstName,
          'last_name': lastName,
          'role': normalizedRole,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 Google Sign In Response Status: ${response.statusCode}');
      print('📡 Google Sign In Response Headers: ${response.headers}');
      print('📡 Google Sign In Response Body (first 200 chars): ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'] ?? response.headers['Location'];
        if (location != null) {
          print('🔄 Redirect detected (${response.statusCode}) to: $location');
          Uri redirectUri;
          try {
            redirectUri = Uri.parse(location);
            if (!redirectUri.isAbsolute) {
              final baseUri = Uri.parse(url);
              redirectUri = baseUri.resolve(location);
            }
            final originalUri = Uri.parse(url);
            final originalPath = originalUri.path.replaceAll(RegExp(r'/+$'), '');
            final redirectPath = redirectUri.path.replaceAll(RegExp(r'/+$'), '');
            if (redirectUri.toString() == originalUri.toString() || redirectPath == originalPath || (redirectUri.scheme == originalUri.scheme && redirectUri.host == originalUri.host && redirectPath == originalPath)) {
              print('⚠️ Redirect loop detected: Redirect URL same as original URL');
              print('⚠️ Original: $originalUri');
              print('⚠️ Redirect: $redirectUri');
              return {'error': 'This email is already registered with another role. Please select the correct role or use a different email address.'};
            }
            print('🔄 Following redirect to: $redirectUri');
          } catch (e) {
            print('❌ Invalid redirect URL: $location, error: $e');
            return {'error': 'Server redirect error. Invalid redirect URL.'};
          }
          try {
            final redirectResponse = await http.post(
              redirectUri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'id_token': idToken,
                'email': account.email,
                'name': fullName,
                'first_name': firstName,
                'last_name': lastName,
                'role': normalizedRole,
              }),
            ).timeout(const Duration(seconds: 30));
            print('📡 Redirect Response Status: ${redirectResponse.statusCode}');
            if (redirectResponse.statusCode >= 300 && redirectResponse.statusCode < 400) {
              print('⚠️ Redirect response is also a redirect - preventing loop');
              return {'error': 'This email is already registered with another role. Please select the correct role or use a different email address.'};
            }
            return await _handleGoogleSignInResponse(redirectResponse, normalizedRole, context);
          } catch (e) {
            print('❌ Error following redirect: $e');
            return {'error': 'Connection issue. Please try again.'};
          }
        } else {
          print('❌ Redirect detected but no Location header found');
          return {'error': 'Connection issue. Please try again.'};
        }
      }

      return await _handleGoogleSignInResponse(response, normalizedRole, context);
    } catch (e) {
      print('❌ Google Sign In Exception: $e');
      return {'error': 'Unable to sign in with Google. Please try again or use email/password to sign in.'};
    }
  }

  // Helper method to handle Google Sign In response
  Future<Map<String, dynamic>> _handleGoogleSignInResponse(http.Response response, String normalizedRole, BuildContext context) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      print('❌ Response is not JSON: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      if (response.statusCode == 404) {
        return {'error': 'Service temporarily unavailable. Please try again in a moment.'};
      } else if (response.statusCode == 500) {
        return {'error': 'We\'re experiencing technical difficulties. Please try again shortly.'};
      } else if (response.statusCode >= 300 && response.statusCode < 400) {
        return {'error': 'Connection issue detected. Please try again.'};
      } else {
        return {'error': 'Unable to reach our servers. Please check your connection and try again.'};
      }
    }
    if (response.statusCode != 200 || data['status'] == 'error') {
      final errorMsg = data['message'] ?? 'Google Sign In failed';
      print('❌ Backend error: $errorMsg');
      if (errorMsg.toString().toLowerCase().contains('already registered') || errorMsg.toString().toLowerCase().contains('role')) {
        return {'error': errorMsg};
      }
      if (response.statusCode == 422 && data.containsKey('errors')) {
        return {'error': errorMsg};
      }
      return {'error': errorMsg};
    }
    if (response.statusCode == 200 && data['access_token'] != null) {
      final isNewUser = data['message']?.toString().contains('created') ?? false;
      if (isNewUser) {
        print('✅ New user account created via Google Sign In - redirecting to home');
      } else {
        print('✅ Existing user logged in via Google Sign In - redirecting to home');
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['access_token']);
      final user = data['user'];
      if (user != null) {
        final userId = user['id']?.toString();
        if (userId != null) {
          await PreferencesHelper.saveUserId(userId);
        }
        final userRole = (user['role'] ?? normalizedRole).toString().toLowerCase();
        await PreferencesHelper.saveUserRole(userRole);
        print('🔵 User Role: $userRole (from ${isNewUser ? "new account" : "existing account"})');
        if (userRole == 'seller/buyer') {
          if (userId != null) {
            await PreferencesHelper.saveBuyerId(userId);
            await PreferencesHelper.saveSellerId(userId);
          }
        } else if (userRole == 'buyer') {
          if (userId != null) await PreferencesHelper.saveBuyerId(userId);
        } else if (userRole == 'seller' || userRole == 'dealer') {
          if (userId != null) await PreferencesHelper.saveSellerId(userId);
        }
      }
      await _syncNotificationsInboxAfterTokenSave();
      if (!context.mounted) {
        return data;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        try {
          final userRole = (data['user']?['role'] ?? normalizedRole).toString().toLowerCase();
          print('🔵 Navigating to home page for role: $userRole');
          if (userRole == 'inspector') {
            Navigator.pushReplacementNamed(context, '/inspector-home');
          } else if (userRole == 'transporter') {
            Navigator.pushReplacementNamed(context, '/transporter-home');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
          print('✅ Navigation successful');
          _scheduleNotificationsSyncAfterAuth();
        } catch (e) {
          print('❌ Navigation error after Google Sign In: $e');
          try {
            Navigator.pushReplacementNamed(context, '/home');
            _scheduleNotificationsSyncAfterAuth();
          } catch (fallbackError) {
            print('❌ Fallback navigation also failed: $fallbackError');
          }
        }
      });
      return data;
    } else {
      return {'error': 'Invalid response from server'};
    }
  }
}
