import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
  // Configuration for different environments
  // Change these values based on your setup
  
  // Auto-detection: Will be set automatically based on device type
  // No need to manually change this anymore!
  static bool? _cachedIsPhysicalDevice;
  
  // Your computer's local IP address (for physical device connection)
  // Find your IP: Windows (ipconfig), Mac/Linux (ifconfig)
  // Make sure phone and computer are on same WiFi network
  // Common IP ranges: 192.168.x.x, 10.0.x.x, 172.16.x.x
  static const String localIP = '192.168.8.241'; // ✅ Updated: Your computer's IP address from ipconfig
  
  // Helper method to test if server is reachable
  static Future<bool> testServerConnection() async {
    try {
      final testUrl = baseUrl.replaceFirst(RegExp(r'/api$'), '/api/test');
      print('🔍 Testing server connection: $testUrl');
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      final request = await client.getUrl(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 5));
      final response = await request.close()
          .timeout(const Duration(seconds: 5));
      
      client.close();
      
      final isReachable = response.statusCode == 200 || response.statusCode == 404;
      print('${isReachable ? "✅" : "❌"} Server ${isReachable ? "reachable" : "not reachable"} (Status: ${response.statusCode})');
      return isReachable;
    } catch (e) {
      print('❌ Server connection test failed: $e');
      return false;
    }
  }
  
  // Laravel server port (default: 8000)
  static const int serverPort = 8000;
  static const int websocketPort = 6001;
  static const bool websocketUseReverseProxy = false;
  
  // Environment: 'development' or 'production'
  // ⚠️ CHANGE THIS to 'production' when deploying to Hostinger
  static const String environment = 'production'; // ✅ Changed to 'production' for hosting
  static const String productionUrlFallback = 'https://carauction.templateforwebsites.com/api';
  static String? _resolvedProductionUrl;

  // Production API URL (Hostinger domain)
  // ✅ Set to website domain if API served under same domain
  static const String productionUrl = 'https://carauction.templateforwebsites.com/api';

  /// Base URL for images/uploads (same server as API, without /api) so save and fetch use same folder
  static String get imageBaseUrl {
    if (environment == 'production') {
       return 'https://carauction.templateforwebsites.com';
    }
    final base = baseUrl;
    return base.replaceFirst(RegExp(r'/api$'), '');
  }

  /// Google OAuth Web Client ID (required on Android for Google Sign In).
  /// Must match the client ID used by the backend to verify id_token (AuthController signInWithGoogle).
  /// iOS uses GIDClientID from Info.plist; this is the serverClientId for Android and backend verification.
  static const String googleWebClientId = '818773745181-1eq90ikmhev8vqf4ltof1a39m16oqgi4.apps.googleusercontent.com';
  
  // Auto-detect if running on physical device or emulator/simulator
  static Future<bool> _detectPhysicalDevice() async {
    // Return cached value if already detected
    if (_cachedIsPhysicalDevice != null) {
      return _cachedIsPhysicalDevice!;
    }
    
    try {
      if (kIsWeb) {
        _cachedIsPhysicalDevice = false;
        return false;
      }
      
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        
        // Primary check: Use isPhysicalDevice property (most reliable)
        bool isPhysical = androidInfo.isPhysicalDevice;
        
        print('📱 ========== DEVICE DETECTION STARTED ==========');
        print('📱 Manufacturer: ${androidInfo.manufacturer}');
        print('📱 Model: ${androidInfo.model}');
        print('📱 Brand: ${androidInfo.brand}');
        print('📱 Device ID: ${androidInfo.id}');
        print('📱 isPhysicalDevice (from API): $isPhysical');
        
        // Additional checks for better accuracy
        final model = androidInfo.model.toLowerCase();
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final brand = androidInfo.brand.toLowerCase();
        
        // Emulator detection patterns
        final isEmulatorPattern = model.contains('sdk') || 
                                 model.contains('emulator') || 
                                 model.contains('google_sdk') ||
                                 brand == 'generic' ||
                                 manufacturer == 'unknown' ||
                                 model.contains('aosp');
        
        // Final decision: Trust API first, then check patterns
        if (isPhysical && isEmulatorPattern) {
          // API says physical but patterns suggest emulator - trust patterns
          print('⚠️  Warning: API says physical but patterns suggest emulator');
          isPhysical = false;
        } else if (!isPhysical && !isEmulatorPattern) {
          // API says emulator but no emulator patterns - might be physical
          print('⚠️  Warning: API says emulator but no emulator patterns found');
          // Trust API in this case
        }
        
        _cachedIsPhysicalDevice = isPhysical;
        print('📱 ========== DETECTION RESULT ==========');
        print('📱 Final Decision: ${isPhysical ? "PHYSICAL DEVICE" : "EMULATOR"}');
        print('📱 API will use: ${isPhysical ? "Local IP ($localIP)" : "Emulator (10.0.2.2)"}');
        print('📱 Base URL: ${isPhysical ? "http://$localIP:$serverPort/api" : "http://10.0.2.2:$serverPort/api"}');
        print('==========================================');
        return isPhysical;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use isPhysicalDevice property directly
        bool isPhysical = iosInfo.isPhysicalDevice;
        
        // Additional check: simulator name pattern
        if (!isPhysical || iosInfo.name.toLowerCase().contains('simulator')) {
          isPhysical = false;
        }
        
        _cachedIsPhysicalDevice = isPhysical;
        print('📱 ========== DEVICE DETECTION ==========');
        print('📱 Device Name: ${iosInfo.name}');
        print('📱 Model: ${iosInfo.model}');
        print('📱 Is Physical Device: $isPhysical');
        print('📱 API will use: ${isPhysical ? "Local IP ($localIP)" : "Simulator (localhost)"}');
        print('==========================================');
        return isPhysical;
      } else {
        // Desktop platforms
        _cachedIsPhysicalDevice = false;
        return false;
      }
    } catch (e) {
      print('⚠️ Error detecting device type: $e');
      // Fallback: assume emulator for Android, physical for iOS
      if (Platform.isAndroid) {
        _cachedIsPhysicalDevice = false;
        return false;
      } else if (Platform.isIOS) {
        _cachedIsPhysicalDevice = true;
        return true;
      }
      _cachedIsPhysicalDevice = false;
      return false;
    }
  }
  
  // Synchronous version for immediate use (uses cached value or defaults)
  static bool get usePhysicalDevice {
    // If not cached yet, return default based on platform
    // This will be updated when _detectPhysicalDevice() is called
    if (_cachedIsPhysicalDevice == null) {
      // Default: assume emulator for Android (safer default)
      // Detection will update this correctly when initialize() is called
      print('⚠️  Device detection not yet completed, using default...');
      if (Platform.isAndroid) {
        print('⚠️  Default: Assuming emulator (will be updated after detection)');
        return false; // Default to emulator until detection completes
      } else if (Platform.isIOS) {
        print('⚠️  Default: Assuming physical device (will be updated after detection)');
        return true; // Default to physical device for iOS
      }
      return false;
    }
    // Return cached detection result
    print('✅ Using cached device detection: ${_cachedIsPhysicalDevice! ? "PHYSICAL DEVICE" : "EMULATOR"}');
    return _cachedIsPhysicalDevice!;
  }
  
  // Initialize device detection (call this at app startup)
  // Note: In production mode, device detection is skipped as it's not needed
  static Future<void> initialize() async {
    if (environment == 'production') {
      await _resolveProductionUrl();
      return;
    }
    // Only detect device in development mode
    await _detectPhysicalDevice();
  }
  
  // Base URL for API calls
  static String get baseUrl {
    // Production environment
    if (environment == 'production') {
      return _cleanUrl(_resolvedProductionUrl ?? productionUrl);
    }
    
    // Development environment
    if (kIsWeb) {
      // Web - use localhost
      return 'http://localhost:$serverPort/api';
    } else if (Platform.isAndroid) {
      final isPhysical = usePhysicalDevice;
      if (isPhysical) {
        // Physical Android Device - use computer's local IP
        print('📱 ========== PHYSICAL ANDROID DEVICE DETECTED ==========');
        print('📱 Using Physical Device Configuration');
        print('🌐 Local IP: $localIP');
        print('🔗 Base URL: http://$localIP:$serverPort/api');
        print('📝 IMPORTANT: Make sure:');
        print('   1. Phone and computer are on SAME WiFi network');
        print('   2. Laravel server is running: php artisan serve');
        print('   3. Firewall allows port $serverPort');
        print('   4. IP address is correct (check with: ipconfig)');
        print('   5. Test in phone browser: http://$localIP:$serverPort/api/test');
        print('==========================================');
        print('⚠️  If connection fails, check:');
        print('   • Run "ipconfig" (Windows) or "ifconfig" (Mac/Linux)');
        print('   • Update localIP in api_config.dart with correct IP');
        print('   • Verify same WiFi network on both devices');
        print('==========================================');
        return _cleanUrl('http://$localIP:$serverPort/api');
      } else {
        // Android Emulator - 10.0.2.2 maps to host machine's localhost
        print('📱 ========== ANDROID EMULATOR DETECTED ==========');
        print('📱 Using Android Emulator Configuration');
        print('🌐 Emulator IP: 10.0.2.2 (maps to host localhost)');
        print('🔗 Base URL: http://10.0.2.2:$serverPort/api');
        print('📝 Make sure Laravel server is running: php artisan serve');
        print('==========================================');
        return _cleanUrl('http://10.0.2.2:$serverPort/api');
      }
    } else if (Platform.isIOS) {
      final isPhysical = usePhysicalDevice;
      if (isPhysical) {
        // Physical iOS Device - use computer's local IP
        print('📱 ========== PHYSICAL iOS DEVICE DETECTED ==========');
        print('📱 Using Physical iOS Device Configuration');
        print('🌐 Local IP: $localIP');
        print('🔗 Base URL: http://$localIP:$serverPort/api');
        print('📝 Make sure phone and computer are on same WiFi network');
        print('==========================================');
        return _cleanUrl('http://$localIP:$serverPort/api');
      } else {
        // iOS Simulator - use localhost
        print('📱 ========== iOS SIMULATOR DETECTED ==========');
        print('📱 Using iOS Simulator Configuration');
        print('🔗 Base URL: http://localhost:$serverPort/api');
        print('==========================================');
        return _cleanUrl('http://localhost:$serverPort/api');
      }
    } else {
      // Desktop or other platforms
      return _cleanUrl('http://localhost:$serverPort/api');
    }
  }
  
  // Convenience method
  static String getBaseUrl() {
    return baseUrl;
  }
  
  // Get current configuration info
  static Map<String, dynamic> getConfigInfo() {
    return {
      'environment': environment,
      'usePhysicalDevice': usePhysicalDevice,
      'isPhysicalDeviceDetected': _cachedIsPhysicalDevice != null,
      'localIP': localIP,
      'serverPort': serverPort,
      'baseUrl': baseUrl,
      'platform': kIsWeb ? 'Web' : (Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Desktop')),
    };
  }
  
  // Print configuration (for debugging)
  static void printConfig() {
    final config = getConfigInfo();
    print('🔧 API Configuration:');
    print('   Environment: ${config['environment']}');
    print('   Platform: ${config['platform']}');
    print('   Use Physical Device: ${config['usePhysicalDevice']}');
    if (config['usePhysicalDevice'] == true) {
      print('   Local IP: ${config['localIP']}');
    }
    print('   Server Port: ${config['serverPort']}');
    print('   Base URL: ${config['baseUrl']}');
    print('   Test URL: ${config['baseUrl']}/test');
  }

  static String _cleanUrl(String url) {
    var u = url.trim();
    u = u.replaceAll(RegExp(r"""^[`'"\s]+"""), '');
    u = u.replaceAll(RegExp(r"""[`'"\s]+$"""), '');
    u = u.replaceAll(RegExp(r"""[,\.;]+$"""), '');
    u = u.replaceAll(RegExp(r"""(?<!:)//+"""), '/');
    return u;
  }

  static Future<void> _resolveProductionUrl() async {
    try {
      final primary = _cleanUrl(productionUrl);
      final secondary = _cleanUrl(productionUrlFallback);
      final primaryTest = primary.replaceFirst(RegExp(r'/api$'), '/api/test');
      final secondaryTest = secondary.replaceFirst(RegExp(r'/api$'), '/api/test');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      // Check primary
      try {
        final req = await client.getUrl(Uri.parse(primaryTest)).timeout(const Duration(seconds: 5));
        final res = await req.close().timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          _resolvedProductionUrl = primary;
          print('✅ Production API resolved (primary): $_resolvedProductionUrl');
          client.close();
          return;
        }
        print('⚠️ Primary API test returned ${res.statusCode}, trying fallback...');
      } catch (e) {
        print('⚠️ Primary API test failed: $e');
      }
      // Check secondary
      try {
        final req2 = await client.getUrl(Uri.parse(secondaryTest)).timeout(const Duration(seconds: 5));
        final res2 = await req2.close().timeout(const Duration(seconds: 5));
        if (res2.statusCode == 200) {
          _resolvedProductionUrl = secondary;
          print('✅ Production API resolved (fallback): $_resolvedProductionUrl');
          client.close();
          return;
        }
        print('⚠️ Fallback API test returned ${res2.statusCode}. Using primary anyway.');
      } catch (e) {
        print('❌ Fallback API test failed: $e');
      }
      client.close();
      _resolvedProductionUrl = primary;
    } catch (e) {
      print('⚠️ _resolveProductionUrl error: $e');
      _resolvedProductionUrl = productionUrl;
    }
  }
}

