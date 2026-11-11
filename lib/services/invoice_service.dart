import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class InvoiceService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Initialize notifications if not already initialized
  bool _notificationsInitialized = false;
  
  /// Handle notification tap - open PDF file
  void _handleNotificationTap(NotificationResponse response) {
    try {
      print('🔔 InvoiceService: Notification tapped');
      print('   📱 Notification ID: ${response.id}');
      print('   📄 Payload: ${response.payload}');
      
      if (response.payload != null && response.payload!.isNotEmpty) {
        final filePath = response.payload!;
        print('   📁 Opening file: $filePath');
        
        // Open PDF file using open_filex
        OpenFilex.open(filePath).then((result) {
          if (result.type == ResultType.done) {
            print('   ✅ PDF opened successfully');
          } else {
            print('   ⚠️ Failed to open PDF: ${result.message}');
            print('   💡 File path: $filePath');
            print('   💡 Try checking if a PDF viewer is installed.');
          }
        }).catchError((e) {
          print('   ❌ Error opening PDF: $e');
          print('   💡 File path: $filePath');
        });
      } else {
        print('   ⚠️ No file path in notification payload');
      }
    } catch (e) {
      print('   ❌ Error handling notification tap: $e');
    }
  }
  
  Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    
    try {
      // Request notification permission for Android 13+ (API 33+)
      if (Platform.isAndroid) {
        print('   🔔 Checking notification permission...');
        final notificationStatus = await Permission.notification.status;
        if (!notificationStatus.isGranted) {
          print('   🔔 Requesting notification permission...');
          final result = await Permission.notification.request();
          if (result.isGranted) {
            print('   ✅ Notification permission granted');
          } else {
            print('   ⚠️ Notification permission denied: $result');
            print('   ⚠️ Notifications may not appear in notification bar');
          }
        } else {
          print('   ✅ Notification permission already granted');
        }
      }
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      // Initialize with notification tap handler
      // Fixed: Using named parameter 'settings' as required by the package
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationTap(response);
        },
      );
      
      // Create notification channel for Android (required for showing notifications)
      if (Platform.isAndroid) {
        try {
          final androidImplementation = _localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
          if (androidImplementation != null) {
            const androidChannel = AndroidNotificationChannel(
              'invoice_downloads',
              'Invoice Downloads',
              description: 'Notifications when invoices are downloaded',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            );
            
            await androidImplementation.createNotificationChannel(androidChannel);
            print('   ✅ Notification channel created: invoice_downloads');
          } else {
            print('   ⚠️ Android notification implementation not available');
          }
        } catch (e) {
          print('   ⚠️ Error creating notification channel: $e');
        }
      }
      
      _notificationsInitialized = true;
      print('✅ InvoiceService: Local notifications initialized');
    } catch (e) {
      print('⚠️ InvoiceService: Failed to initialize notifications: $e');
      print('   Error details: ${e.toString()}');
    }
  }
  
  /// Show download completion notification
  Future<void> _showDownloadNotification(String fileName, String filePath, double fileSizeKB) async {
    try {
      print('🔔 InvoiceService: Preparing to show notification...');
      
      // Ensure notifications are initialized and permission is granted
      await _ensureNotificationsInitialized();
      
      // Double check permission before showing (Android 13+)
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        print('   🔔 Notification permission status: $notificationStatus');
        if (!notificationStatus.isGranted) {
          print('   🔔 Requesting notification permission...');
          final result = await Permission.notification.request();
          print('   🔔 Permission request result: $result');
          if (!result.isGranted) {
            print('   ❌ Notification permission denied - notification will not show');
            print('   💡 Please enable notifications in app settings: Settings > Apps > Car Auction > Notifications');
            // Still try to show - sometimes it works even without explicit permission
          } else {
            print('   ✅ Notification permission granted');
          }
        } else {
          print('   ✅ Notification permission already granted');
        }
      }
      
      // Create notification with big text style for Android showing FULL PATH
      final androidDetails = AndroidNotificationDetails(
        'invoice_downloads', // Must match channel ID created above
        'Invoice Downloads',
        channelDescription: 'Notifications when invoices are downloaded',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(
          'File: $fileName\n'
          'Size: ${fileSizeKB.toStringAsFixed(2)} KB\n'
          'Full Path: $filePath\n'
          'Tap to open file location',
        ),
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      print('   📱 Showing notification with ID: $notificationId');
      print('   📄 File: $fileName');
      print('   📁 Full Path: $filePath');
      
      // Show notification with full path in body
      // Fixed: id is now a named parameter
      await _localNotifications.show(
        id: notificationId,
        title: '📄 Invoice Downloaded Successfully!',
        body: 'File: $fileName\nFull Path: $filePath',
        notificationDetails: notificationDetails,
        payload: filePath, // Store file path in payload
      );
      
      print('✅ InvoiceService: Download notification shown in notification bar');
      print('   📱 Notification ID: $notificationId');
      print('   📄 File: $fileName');
      print('   📁 Full Path: $filePath');
    } catch (e) {
      print('❌ InvoiceService: Failed to show notification: $e');
      print('   Error details: ${e.toString()}');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

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

  Future<List<Map<String, dynamic>>> getInvoices() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/invoices'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['invoices']);
      } else {
        throw Exception('Failed to load invoices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load invoices: $e');
    }
  }

  /// Get billing history with statistics
  Future<Map<String, dynamic>> getBillingHistory() async {
    try {
      print('🧾 InvoiceService.getBillingHistory: Starting...');
      final headers = await _getHeaders();
      print('📍 URL: $_baseUrl/invoices/billing-history');
      print('🔑 Token: ${headers['Authorization']?.substring(0, 20) ?? 'No token'}...');
      
      // Increase timeout to 30 seconds and add better error handling
      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/billing-history'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Request timeout after 30 seconds');
          throw TimeoutException('Request timeout: The server took too long to respond', const Duration(seconds: 30));
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body length: ${response.body.length} characters');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final billingHistory = data['billing_history'] as List<dynamic>? ?? [];
        final statistics = data['statistics'] as Map<String, dynamic>? ?? {};
        
        print('✅ Successfully loaded billing history:');
        print('   - Invoices: ${billingHistory.length}');
        print('   - Statistics: ${statistics.keys.length} keys');
        
        return Map<String, dynamic>.from(data);
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        final errorMsg = errorBody['error'] ?? 'Failed to load billing history: ${response.statusCode}';
        print('❌ Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } on TimeoutException catch (e) {
      print('⏱️ InvoiceService.getBillingHistory Timeout: $e');
      throw Exception('Request timeout: The server took too long to respond. Please check your internet connection and try again.');
    } on SocketException catch (e) {
      print('🌐 InvoiceService.getBillingHistory Network Error: $e');
      throw Exception('Network error: Unable to connect to server. Please check your internet connection.');
    } catch (e) {
      print('❌ InvoiceService.getBillingHistory Error: $e');
      print('📚 Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load billing history: $e');
    }
  }

  Future<Map<String, dynamic>> getInvoice(String invoiceId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/$invoiceId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load invoice: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load invoice: $e');
    }
  }

  /// Get invoice HTML content for viewing
  Future<Map<String, dynamic>> getInvoiceHTML(String invoiceId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/$invoiceId/html'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load invoice HTML: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load invoice HTML: $e');
    }
  }

  /// Download invoice as PDF
  Future<String> downloadInvoice(String invoiceId, String invoiceNumber) async {
    try {
      // No permission needed - we're using app's own storage directory
      // For Android 10+ (API 29+), scoped storage allows apps to access their own directories
      // For iOS, app's documents directory doesn't require permission

      final headers = await _getHeaders();
      // Remove JSON accept header for PDF download
      headers.remove('Accept');
      headers['Accept'] = 'application/pdf';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/$invoiceId/download'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Check if response is actually a PDF
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/pdf') && !contentType.contains('pdf')) {
          // Response is not PDF, might be JSON error
          try {
            final errorBody = json.decode(response.body);
            throw Exception(errorBody['error'] ?? errorBody['message'] ?? 'Server returned non-PDF response');
          } catch (e) {
            if (e is FormatException) {
              // Response is HTML (error page)
              throw Exception('Server error: Received HTML instead of PDF. PDF library may not be installed on server.');
            }
            rethrow;
          }
        }
        
        // Get appropriate directory based on platform
        Directory? directory;
        String? downloadPath;
        
        print('📥 InvoiceService: Starting download process...');
        print('   📄 Invoice Number: $invoiceNumber');
        print('   🆔 Invoice ID: $invoiceId');
        
        if (Platform.isAndroid) {
          print('📱 Platform: Android');
          // For Android, prioritize public Downloads folder
          try {
            // Check Android version
            final deviceInfo = DeviceInfoPlugin();
            final androidInfo = await deviceInfo.androidInfo;
            final sdkInt = androidInfo.version.sdkInt;
            print('   📱 Android SDK version: $sdkInt');

            if (sdkInt <= 32) {
              // Request storage permission for Android 12 and below
              print('   🔐 Checking storage permission...');
              final status = await Permission.storage.status;
              if (!status.isGranted) {
                print('   🔐 Requesting storage permission...');
                final result = await Permission.storage.request();
                if (!result.isGranted) {
                  print('   ⚠️ Storage permission not granted: $result');
                  print('   ⚠️ Will proceed with write-test verification...');
                } else {
                  print('   ✅ Storage permission granted');
                }
              } else {
                print('   ✅ Storage permission already granted');
              }
            } else {
              print('   ℹ️ Android 13+ (SDK 33+): Using Scoped Storage. No legacy storage permission needed.');
            }
            
            // CRITICAL: Try public Downloads folder paths FIRST ONLY for Android 9 and below (SDK <= 28)
            // For Android 10+ (SDK 29+), we should prioritize app-specific directories or getDownloadsDirectory
            // For Android 11+ (SDK 30+), writing to /storage/emulated/0/Download via File API is strictly forbidden
            final possiblePaths = <String>[];
            if (sdkInt <= 29) {
              possiblePaths.addAll([
                '/storage/emulated/0/Download',
                '/storage/emulated/0/Downloads',
                '/sdcard/Download',
                '/sdcard/Downloads',
              ]);
            }
            
            bool foundPath = false;
            if (possiblePaths.isNotEmpty) {
              for (final path in possiblePaths) {
                print('   🔍 Trying public Downloads path: $path');
                try {
                  final testDir = Directory(path);
                  if (await testDir.exists()) {
                    try {
                      final testFile = File('${testDir.path}/.test_write_${DateTime.now().millisecondsSinceEpoch}');
                      await testFile.writeAsString('test');
                      await testFile.delete();
                      
                      directory = testDir;
                      downloadPath = path;
                      foundPath = true;
                      print('   ✅ SUCCESS: Using public Downloads folder: $downloadPath');
                      break;
                    } catch (e) {
                      print('   ⚠️ Path exists but is not writable: $path');
                    }
                  }
                } catch (e) {
                  print('   ⚠️ Error checking $path: $e');
                }
              }
            }
            
            // For Android 10+, or if public paths failed, use proper API-provided directories
            if (!foundPath) {
              print('   🔍 Searching for reliable app storage...');
              
              // 1. Try getExternalStorageDirectory (Accessible, and visible to some file managers)
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                // Use a 'Downloads' subfolder in the app's external directory
                final appDownloadDir = Directory('${externalDir.path}/Downloads');
                if (!await appDownloadDir.exists()) {
                  await appDownloadDir.create(recursive: true);
                }
                
                // Verify writability
                try {
                  final testFile = File('${appDownloadDir.path}/.test_write_${DateTime.now().millisecondsSinceEpoch}');
                  await testFile.writeAsString('test');
                  await testFile.delete();
                  
                  directory = appDownloadDir;
                  downloadPath = directory.path;
                  foundPath = true;
                  print('   ✅ SUCCESS: Using app external storage: $downloadPath');
                  print('   folder is usually: Android/data/com.carauction.androidios/files/Downloads');
                } catch (e) {
                  print('   ⚠️ App external storage not writable: $e');
                }
              }
            }
            
            if (!foundPath) {
              // 2. Try getDownloadsDirectory (might return null on some devices)
              final downloadsDir = await getDownloadsDirectory();
              if (downloadsDir != null) {
                directory = downloadsDir;
                downloadPath = directory.path;
                foundPath = true;
                print('   ✅ SUCCESS: Using getDownloadsDirectory(): $downloadPath');
              }
            }
            
            // Final fallback: app's external storage (not recommended but better than nothing)
            if (!foundPath) {
              print('   ⚠️ WARNING: Could not access public Downloads folder');
              print('   📁 Using app external storage as last resort...');
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                directory = Directory('${externalDir.path}/Downloads');
                downloadPath = directory.path;
                if (!await directory.exists()) {
                  await directory.create(recursive: true);
                }
                print('   📁 Using app Downloads folder: $downloadPath');
                print('   ⚠️ NOTE: This is app private folder, not device Downloads');
              } else {
                throw Exception('Could not access any storage directory');
              }
            }
          } catch (e) {
            print('   ❌ ERROR: Failed to access Downloads folder: $e');
            print('   📁 Fallback to app documents directory...');
            // Fallback to app documents directory
            directory = await getApplicationDocumentsDirectory();
            downloadPath = directory.path;
            print('   📁 Using app documents: $downloadPath');
            print('   ⚠️ NOTE: This is app private folder, not device Downloads');
          }
        } else if (Platform.isIOS) {
          print('📱 Platform: iOS');
          // iOS: Use app's documents directory
          directory = await getApplicationDocumentsDirectory();
          downloadPath = directory.path;
          print('   📁 iOS Documents path: $downloadPath');
        } else {
          print('📱 Platform: Desktop/Web');
          // Desktop/Web: Try downloads directory
          directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          downloadPath = directory?.path;
          print('   📁 Downloads path: $downloadPath');
        }

        if (directory == null || downloadPath == null) {
          print('   ❌ ERROR: Could not access storage directory');
          throw Exception('Could not access storage directory');
        }

        // Create file with sanitized filename
        final sanitizedInvoiceNumber = invoiceNumber.replaceAll(RegExp(r'[^\w\s-]'), '_');
        final fileName = 'Invoice_$sanitizedInvoiceNumber.pdf';
        final file = File('$downloadPath/$fileName');
        
        print('   📝 File name: $fileName');
        print('   📂 Full file path: ${file.path}');
        
        // Write file
        print('   💾 Writing file to disk: ${file.path}...');
        await file.writeAsBytes(response.bodyBytes);
        print('   ✅ File written successfully to disk');
        
        final fileSizeKB = (await file.length()) / 1024;
        final fileSizeMB = fileSizeKB / 1024;
        
        print('');
        print('═══════════════════════════════════════════════════════════');
        print('✅ INVOICE DOWNLOADED SUCCESSFULLY!');
        print('═══════════════════════════════════════════════════════════');
        print('📄 File Name: $fileName');
        print('📁 Full Path: ${file.path}');
        print('💾 File Size: ${fileSizeKB.toStringAsFixed(2)} KB (${fileSizeMB.toStringAsFixed(2)} MB)');
        print('📂 Directory: $downloadPath');
        print('🕐 Downloaded at: ${DateTime.now().toString()}');
        print('═══════════════════════════════════════════════════════════');
        print('');

        // Show notification in notification bar
        await _showDownloadNotification(fileName, file.path, fileSizeKB);

        // For Android, try to scan the file so it appears in Downloads app
        if (Platform.isAndroid) {
          try {
            // The file is already saved, Android should detect it automatically
            // For better visibility, you might want to use MediaStore API
            // but that requires additional permissions and setup
            print('📱 Android: File saved to Downloads folder');
          } catch (e) {
            print('⚠️ Android file scan error (file still saved): $e');
          }
        }

        return file.path;
      } else if (response.statusCode == 501) {
        // PDF generation not implemented yet
        throw Exception('PDF generation not yet implemented on server');
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Unknown error'};
        throw Exception(errorBody['error'] ?? 'Failed to download invoice: ${response.statusCode}');
      }
    } catch (e) {
      // Provide more user-friendly error messages
      if (e.toString().contains('permission')) {
        throw Exception('Storage permission is required to download invoices. Please grant permission in app settings.');
      } else if (e.toString().contains('501')) {
        throw Exception('PDF download is not yet available. Please contact support.');
      } else {
        throw Exception('Failed to download invoice: ${e.toString()}');
      }
    }
  }

  Future<Map<String, dynamic>> markAsPaid(String invoiceId, String paymentMethod, {String? paymentReference}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/invoices/$invoiceId/mark-paid'),
        headers: headers,
        body: json.encode({
          'payment_method': paymentMethod,
          'payment_reference': paymentReference,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to mark invoice as paid: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to mark invoice as paid: $e');
    }
  }
}
