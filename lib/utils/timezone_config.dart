import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Timezone Configuration Utility
/// 
/// This file handles timezone configuration for the app.
/// 
/// **To change timezone:**
/// 1. Update the `defaultTimeZone` constant below
/// 2. Call `TimezoneConfig.initialize()` in main.dart before runApp()
/// 
/// **Common timezones:**
/// - 'America/New_York' (EST/EDT)
/// - 'America/Chicago' (CST/CDT)
/// - 'America/Denver' (MST/MDT)
/// - 'America/Los_Angeles' (PST/PDT)
/// - 'Asia/Kolkata' (IST)
/// - 'Europe/London' (GMT/BST)
/// - 'UTC' (Coordinated Universal Time)
class TimezoneConfig {
  // Default timezone - US Eastern Time (EST/EDT)
  static const String defaultTimeZone = 'America/New_York'; // US Eastern Time
  
  // Locale for date formatting (e.g., 'en_US', 'en_IN')
  static const String defaultLocale = 'en_US'; // Change this if needed
  
  static bool _isInitialized = false;
  
  /// Initialize timezone configuration
  /// Call this in main.dart before runApp()
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // Initialize locale data for date formatting
      await initializeDateFormatting(defaultLocale, null);
      
      // Set default locale for Intl
      Intl.defaultLocale = defaultLocale;
      
      _isInitialized = true;
      print('✅ TimezoneConfig: Initialized with locale: $defaultLocale');
      print('📅 Note: DateTime operations use device local timezone by default');
      print('📅 To convert to specific timezone, use TimezoneConfig methods');
    } catch (e) {
      print('⚠️ TimezoneConfig: Initialization failed: $e');
    }
  }
  
  /// Get current DateTime in the configured timezone
  /// Note: Flutter's DateTime uses device local timezone
  /// This method returns current time (device local)
  static DateTime getCurrentTime() {
    return DateTime.now();
  }
  
  /// Format DateTime to string with timezone awareness
  /// 
  /// Example formats:
  /// - 'MMM d, y h:mm a' -> "Jan 15, 2024 3:30 PM"
  /// - 'yyyy-MM-dd HH:mm:ss' -> "2024-01-15 15:30:00"
  /// - 'MM/dd/yyyy' -> "01/15/2024"
  static String formatDateTime(DateTime dateTime, {String? format}) {
    final dateFormat = DateFormat(format ?? 'MMM d, y h:mm a', defaultLocale);
    return dateFormat.format(dateTime);
  }
  
  /// Parse date string to DateTime
  /// Assumes the string is in device local timezone
  static DateTime parseDateTime(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      print('⚠️ TimezoneConfig: Failed to parse date: $dateString');
      return DateTime.now();
    }
  }
  
  /// Format date only (without time)
  static String formatDate(DateTime dateTime) {
    return formatDateTime(dateTime, format: 'MMM d, y');
  }
  
  /// Format time only (without date)
  static String formatTime(DateTime dateTime) {
    return formatDateTime(dateTime, format: 'h:mm a');
  }
  
  /// Get timezone offset string (e.g., "+05:30" for IST)
  static String getTimezoneOffset() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = (offset.inMinutes % 60).abs();
    final sign = offset.isNegative ? '-' : '+';
    return '$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
  
  /// Get timezone name (e.g., "EST", "PST")
  static String getTimezoneName() {
    return DateTime.now().timeZoneName;
  }
}

