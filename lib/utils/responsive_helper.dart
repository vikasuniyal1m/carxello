import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// Responsive helper class for adaptive UI design
/// Based on Flutter's adaptive design principles: https://docs.flutter.dev/ui/adaptive-responsive
class ResponsiveHelper {
  // Breakpoints based on screen width
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Base screen dimensions (iPhone 12 Pro / Common Android device)
  static const double baseWidth = 390.0;
  static const double baseHeight = 844.0;

  /// Check if device is Large Tablet (high resolution like 1200x1800)
  static bool isLargeTablet(BuildContext context) {
    final width = screenWidth(context);
    final height = screenHeight(context);
    return width >= 1200 && height >= 1400; // Adjusted height threshold to cover more large tablets
  }

  /// Get actual screen width at runtime
  static double screenWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // print('📱 Screen Width: $width'); // Commented out to reduce console spam
    return width;
  }

  /// Get actual screen height at runtime
  static double screenHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // print('📱 Screen Height: $height'); // Commented out to reduce console spam
    return height;
  }

  /// Get actual screen dimensions and calculate scale factors
  static Map<String, double> getScreenInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final scaleWidth = width / baseWidth;
    final scaleHeight = height / baseHeight;
    final scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight; // Use smaller scale to prevent overflow
    
    // Commented out to reduce console spam
    // print('📱 Screen Info:');
    // print('   Width: $width');
    // print('   Height: $height');
    // print('   Scale Width: $scaleWidth');
    // print('   Scale Height: $scaleHeight');
    // print('   Using Scale: $scale');
    
    return {
      'width': width,
      'height': height,
      'scaleWidth': scaleWidth,
      'scaleHeight': scaleHeight,
      'scale': scale,
    };
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= desktopBreakpoint;
  }

  // ============================================
  // IPAD AND TABLET SPECIFIC BOOLEAN METHODS
  // Based on exact breakpoints (mobile unaffected)
  // 
  // iPad: width >= 810 (typically 810-1032+)
  // Tablet: width >= 800, up to 1280+ (excludes iPad range)
  // Mobile: < 600 (completely unaffected)
  // ============================================
  
  /// iPad breakpoints: min width 810, max width 1032 (or above)
  static const double iPadMinWidth = 810.0;
  static const double iPadMaxWidth = 1032.0;
  
  /// Tablet breakpoints: min width 800, max width 1280 (or above)
  static const double tabletMinWidth = 800.0;
  static const double tabletMaxWidth = 1280.0;

  /// Check if device is iPad (width >= 810, typically up to 1032+)
  /// This does NOT affect mobile configuration
  static bool isIPadDevice(BuildContext context) {
    final width = screenWidth(context);
    // iPad: 810 to ~1100 (covers 1032 and slightly above)
    return width >= iPadMinWidth && width <= 1100.0;
  }

  /// Check if device is Tablet (width >= 800, up to 1280 or above)
  /// This does NOT affect mobile configuration
  /// Note: iPad takes priority in overlap range (810-1100)
  static bool isTabletDevice(BuildContext context) {
    final width = screenWidth(context);
    // Exclude iPad range first (iPad takes priority)
    if (isIPadDevice(context)) return false;
    // Tablet: 800-809 OR 1101-1280+
    return (width >= tabletMinWidth && width < iPadMinWidth) || 
           (width > 1100.0 && width <= 1400.0); // Up to 1280+ but cap at reasonable max
  }

  /// Check if device is iPad or Tablet (for combined checks)
  /// This does NOT affect mobile configuration
  static bool isIPadOrTabletDevice(BuildContext context) {
    return isIPadDevice(context) || isTabletDevice(context);
  }

  // ============================================
  // SCREENSIZE UTILITY COMPATIBLE METHODS
  // Based on ScreenSize breakpoints (mobile unaffected)
  // Small tablets: 600-768px
  // Large tablets: >= 768px
  // General tablet: >= 600px
  // Mobile: < 600px (completely unaffected)
  // ============================================
  
  /// Check if device is Small Tablet (600-768px) - ScreenSize compatible
  /// This does NOT affect mobile configuration
  static bool isSmallTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= 600 && width < 768;
  }

  /// Check if device is Large Tablet (>= 768px) - ScreenSize compatible
  /// Note: This is different from isLargeTablet which checks 1200+ width
  /// This does NOT affect mobile configuration
  static bool isLargeTabletScreenSize(BuildContext context) {
    final width = screenWidth(context);
    return width >= 768;
  }

  /// Check if device is Tablet (>= 600px) - ScreenSize compatible
  /// This does NOT affect mobile configuration
  static bool isTabletScreenSize(BuildContext context) {
    final width = screenWidth(context);
    return width >= 600;
  }

  /// Get device type
  static DeviceType getDeviceType(BuildContext context) {
    if (isLargeTablet(context)) return DeviceType.largeTablet;
    if (isDesktop(context)) return DeviceType.desktop;
    if (isTablet(context)) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  /// Generic helper for responsive values
  /// Supports iPad and Tablet specific values without affecting mobile
  /// Uses ScreenSize breakpoints: Small Tablet (600-768px), Large Tablet (>= 768px)
  static T value<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    T? iPad,
    T? largeTablet,
    T? desktop,
  }) {
    // Check Large Tablet ScreenSize first (>= 768px)
    if (isLargeTabletScreenSize(context)) {
      return largeTablet ?? desktop ?? tablet ?? iPad ?? mobile;
    }
    // Check Small Tablet ScreenSize (600-768px)
    if (isSmallTablet(context)) {
      return tablet ?? iPad ?? largeTablet ?? desktop ?? mobile;
    }
    // Check iPad (810-1032)
    if (isIPadDevice(context)) {
      return iPad ?? tablet ?? largeTablet ?? desktop ?? mobile;
    }
    // Check Tablet (800-1280)
    if (isTabletDevice(context)) {
      return tablet ?? iPad ?? largeTablet ?? desktop ?? mobile;
    }
    // Check Large Tablet (existing - 1200+ width, 1400+ height)
    if (isLargeTablet(context)) {
      return largeTablet ?? desktop ?? tablet ?? iPad ?? mobile;
    }
    // Check Desktop (existing)
    if (isDesktop(context)) {
      return desktop ?? tablet ?? iPad ?? largeTablet ?? mobile;
    }
    // Check old tablet method (for backward compatibility)
    if (isTablet(context)) {
      return tablet ?? iPad ?? mobile;
    }
    // Mobile (default - unaffected - < 600px)
    return mobile;
  }

  /// Get responsive font size based on actual screen size
  /// Supports iPad and Tablet without affecting mobile
  static double fontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? iPad,
    double? largeTablet,
    double? desktop,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final width = screenInfo['width']!;
    
    // Base font size based on device type
    double baseSize;
    // Check Large Tablet ScreenSize first (>= 768px)
    if (isLargeTabletScreenSize(context)) {
      baseSize = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.35;
    }
    // Check Small Tablet ScreenSize (600-768px)
    else if (isSmallTablet(context)) {
      baseSize = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check iPad (810-1100)
    else if (isIPadDevice(context)) {
      baseSize = iPad ?? tablet ?? largeTablet ?? desktop ?? mobile * 1.25;
    }
    // Check Tablet (800-809 or 1101-1400)
    else if (isTabletDevice(context)) {
      baseSize = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check Large Tablet (existing - 1200+ width, 1400+ height)
    else if (isLargeTablet(context)) {
      baseSize = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.3;
    }
    // Check Desktop (existing)
    else if (isDesktop(context)) {
      baseSize = desktop ?? tablet ?? iPad ?? largeTablet ?? mobile * 1.2;
    }
    // Check old tablet method (for backward compatibility)
    else if (isTablet(context)) {
      baseSize = tablet ?? iPad ?? mobile * 1.1;
    }
    // Mobile (unaffected - < 600px)
    else {
      baseSize = mobile;
    }
    
    // Scale based on actual screen size
    final scaledSize = baseSize * scale;
    
    // Ensure minimum readable size
    if (scaledSize < 10) return 10;
    
    // Ensure maximum size (not more than 5% of screen width)
    final maxSize = width * 0.05;
    if (scaledSize > maxSize) return maxSize;
    
    return scaledSize;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets padding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
    double? largeTabletScale, // Optional scale factor for large tablets
  }) {
    double scale = 1.0;
    if (largeTabletScale != null && isLargeTablet(context)) {
      scale = largeTabletScale;
    }
    if (all != null) {
      final responsiveAll = _getResponsiveValue(context, all);
      return EdgeInsets.all(responsiveAll);
    }
    
    final h = horizontal != null ? _getResponsiveValue(context, horizontal) : (left ?? right ?? 0.0);
    final v = vertical != null ? _getResponsiveValue(context, vertical) : (top ?? bottom ?? 0.0);
    
    return EdgeInsets.only(
      left: left != null ? _getResponsiveValue(context, left) : (horizontal ?? 0.0),
      right: right != null ? _getResponsiveValue(context, right) : (horizontal ?? 0.0),
      top: top != null ? _getResponsiveValue(context, top) : (vertical ?? 0.0),
      bottom: bottom != null ? _getResponsiveValue(context, bottom) : (vertical ?? 0.0),
    );
  }

  /// Get responsive width multiplier based on actual screen
  static double widthMultiplier(BuildContext context) {
    final screenInfo = getScreenInfo(context);
    return screenInfo['scaleWidth']!;
  }

  /// Get responsive height multiplier based on actual screen
  static double heightMultiplier(BuildContext context) {
    final screenInfo = getScreenInfo(context);
    return screenInfo['scaleHeight']!;
  }

  /// Get unified scale factor (prevents overflow)
  static double scaleFactor(BuildContext context) {
    final screenInfo = getScreenInfo(context);
    return screenInfo['scale']!;
  }

  /// Get responsive value based on actual screen size (prevents overflow)
  static double _getResponsiveValue(BuildContext context, double value) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Use scale factor to make everything proportional to actual screen
    final scaledValue = value * scale;
    
    // Ensure minimum value to prevent too small elements
    if (scaledValue < value * 0.7) {
      return value * 0.7;
    }
    
    // Ensure maximum value to prevent overflow
    final maxWidth = screenInfo['width']!;
    if (scaledValue > maxWidth * 0.9) {
      return maxWidth * 0.9;
    }
    
    return scaledValue;
  }

  /// Get responsive icon size
  /// Supports iPad and Tablet without affecting mobile
  static double iconSize(BuildContext context, {
    double mobile = 24.0,
    double? tablet,
    double? iPad,
    double? largeTablet,
    double? desktop,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Base icon size based on device type
    double baseSize;
    // Check Large Tablet ScreenSize first (>= 768px)
    if (isLargeTabletScreenSize(context)) {
      baseSize = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.35;
    }
    // Check Small Tablet ScreenSize (600-768px)
    else if (isSmallTablet(context)) {
      baseSize = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check iPad (810-1100)
    else if (isIPadDevice(context)) {
      baseSize = iPad ?? tablet ?? largeTablet ?? desktop ?? mobile * 1.25;
    }
    // Check Tablet (800-809 or 1101-1400)
    else if (isTabletDevice(context)) {
      baseSize = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check Large Tablet (existing - 1200+ width, 1400+ height)
    else if (isLargeTablet(context)) {
      baseSize = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.3;
    }
    // Check Desktop (existing)
    else if (isDesktop(context)) {
      baseSize = desktop ?? tablet ?? iPad ?? largeTablet ?? mobile * 1.2;
    }
    // Check old tablet method (for backward compatibility)
    else if (isTablet(context)) {
      baseSize = tablet ?? iPad ?? mobile * 1.1;
    }
    // Mobile (unaffected - < 600px)
    else {
      baseSize = mobile;
    }
    
    // Scale based on actual screen size
    final scaledSize = baseSize * scale;
    
    // Ensure minimum size
    if (scaledSize < 12) return 12;
    
    // Ensure maximum size (not more than 5% of screen width)
    final maxSize = screenInfo['width']! * 0.05;
    if (scaledSize > maxSize) return maxSize;
    
    return scaledSize;
  }

  /// Get responsive button height
  /// Supports iPad and Tablet without affecting mobile
  static double buttonHeight(BuildContext context, {
    double mobile = 48.0,
    double? tablet,
    double? iPad,
    double? largeTablet,
    double? desktop,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Base button height based on device type
    double baseHeight;
    // Check Large Tablet ScreenSize first (>= 768px)
    if (isLargeTabletScreenSize(context)) {
      baseHeight = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.35;
    }
    // Check Small Tablet ScreenSize (600-768px)
    else if (isSmallTablet(context)) {
      baseHeight = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check iPad (810-1100)
    else if (isIPadDevice(context)) {
      baseHeight = iPad ?? tablet ?? largeTablet ?? desktop ?? mobile * 1.25;
    }
    // Check Tablet (800-809 or 1101-1400)
    else if (isTabletDevice(context)) {
      baseHeight = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check Large Tablet (existing - 1200+ width, 1400+ height)
    else if (isLargeTablet(context)) {
      baseHeight = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.3;
    }
    // Check Desktop (existing)
    else if (isDesktop(context)) {
      baseHeight = desktop ?? tablet ?? iPad ?? largeTablet ?? mobile * 1.2;
    }
    // Check old tablet method (for backward compatibility)
    else if (isTablet(context)) {
      baseHeight = tablet ?? iPad ?? mobile * 1.1;
    }
    // Mobile (unaffected - < 600px)
    else {
      baseHeight = mobile;
    }
    
    // Scale based on actual screen size
    final scaledHeight = baseHeight * scale;
    
    // Ensure minimum touch target (44px for accessibility)
    if (scaledHeight < 44) return 44;
    
    // Ensure maximum size (not more than 15% of screen height)
    final maxHeight = screenInfo['height']! * 0.15;
    if (scaledHeight > maxHeight) return maxHeight;
    
    return scaledHeight;
  }

  /// Get responsive border radius
  /// Supports iPad and Tablet without affecting mobile
  static double borderRadius(BuildContext context, {
    double mobile = 8.0,
    double? tablet,
    double? iPad,
    double? largeTablet,
    double? desktop,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Base border radius based on device type
    double baseRadius;
    // Check Large Tablet ScreenSize first (>= 768px)
    if (isLargeTabletScreenSize(context)) {
      baseRadius = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.35;
    }
    // Check Small Tablet ScreenSize (600-768px)
    else if (isSmallTablet(context)) {
      baseRadius = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check iPad (810-1100)
    else if (isIPadDevice(context)) {
      baseRadius = iPad ?? tablet ?? largeTablet ?? desktop ?? mobile * 1.25;
    }
    // Check Tablet (800-809 or 1101-1400)
    else if (isTabletDevice(context)) {
      baseRadius = tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check Large Tablet (existing - 1200+ width, 1400+ height)
    else if (isLargeTablet(context)) {
      baseRadius = largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.3;
    }
    // Check Desktop (existing)
    else if (isDesktop(context)) {
      baseRadius = desktop ?? tablet ?? iPad ?? largeTablet ?? mobile * 1.2;
    }
    // Check old tablet method (for backward compatibility)
    else if (isTablet(context)) {
      baseRadius = tablet ?? iPad ?? mobile * 1.1;
    }
    // Mobile (unaffected - < 600px)
    else {
      baseRadius = mobile;
    }
    
    // Scale based on actual screen size
    final scaledRadius = baseRadius * scale;
    
    // Ensure minimum radius
    if (scaledRadius < 4) return 4;
    
    // Ensure maximum radius (not more than 10% of screen width)
    final maxRadius = screenInfo['width']! * 0.1;
    if (scaledRadius > maxRadius) return maxRadius;
    
    return scaledRadius;
  }

  /// Get number of columns for grid based on screen size
  static int gridColumns(BuildContext context, {
    int mobile = 2,
    int? tablet,
    int? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? (mobile * 2);
    } else if (isTablet(context)) {
      return tablet ?? (mobile * 1.5).round();
    }
    return mobile;
  }

  /// Get responsive spacing based on actual screen size (prevents overflow)
  static double spacing(BuildContext context, double baseSpacing) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final scaledValue = baseSpacing * scale;
    
    // Ensure spacing doesn't cause overflow
    final maxWidth = screenInfo['width']!;
    if (scaledValue > maxWidth * 0.3) {
      return maxWidth * 0.3;
    }
    
    // Ensure minimum spacing
    if (scaledValue < 4) return 4;
    
    return scaledValue;
  }

  /// Get responsive card width
  static double cardWidth(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = screenWidth(context);
    if (isDesktop(context)) {
      return desktop ?? (width * 0.3);
    } else if (isTablet(context)) {
      return tablet ?? (width * 0.45);
    }
    return mobile ?? (width * 0.9);
  }

  /// Get responsive card height
  static double cardHeight(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final height = screenHeight(context);
    if (isDesktop(context)) {
      return desktop ?? (height * 0.4);
    } else if (isTablet(context)) {
      return tablet ?? (height * 0.35);
    }
    return mobile ?? (height * 0.3);
  }

  /// Get responsive image width
  static double imageWidth(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final width = screenInfo['width']!;
    
    // Base width based on device type
    double baseWidth;
    if (isDesktop(context)) {
      baseWidth = desktop ?? (width * 0.4);
    } else if (isTablet(context)) {
      baseWidth = tablet ?? (width * 0.5);
    } else {
      baseWidth = mobile ?? (width * 0.9);
    }
    
    // Scale based on actual screen size
    final scaledWidth = baseWidth * scale;
    
    // Ensure minimum width
    if (scaledWidth < 50) return 50;
    
    // Ensure maximum width (not more than 95% of screen width)
    final maxWidth = width * 0.95;
    if (scaledWidth > maxWidth) return maxWidth;
    
    return scaledWidth;
  }

  /// Get responsive image height
  static double imageHeight(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final height = screenInfo['height']!;
    
    // Base height based on device type
    double baseHeight;
    if (isDesktop(context)) {
      baseHeight = desktop ?? (height * 0.5);
    } else if (isTablet(context)) {
      baseHeight = tablet ?? (height * 0.4);
    } else {
      baseHeight = mobile ?? (height * 0.25);
    }
    
    // Scale based on actual screen size
    final scaledHeight = baseHeight * scale;
    
    // Ensure minimum height
    if (scaledHeight < 50) return 50;
    
    // Ensure maximum height (not more than 90% of screen height)
    final maxHeight = height * 0.9;
    if (scaledHeight > maxHeight) return maxHeight;
    
    return scaledHeight;
  }

  /// Get responsive horizontal padding for content
  static double contentPadding(BuildContext context) {
    if (isDesktop(context)) {
      return 48.0;
    } else if (isTablet(context)) {
      return 32.0;
    }
    return 16.0;
  }

  /// Get responsive vertical padding for content
  static double contentVerticalPadding(BuildContext context) {
    if (isDesktop(context)) {
      return 32.0;
    } else if (isTablet(context)) {
      return 24.0;
    }
    return 16.0;
  }

  /// Get responsive padding value based on device type
  /// Supports iPad and Tablet without affecting mobile
  static double paddingValue(BuildContext context, {
    required double mobile,
    double? tablet,
    double? iPad,
    double? largeTablet,
    double? desktop,
  }) {
    // Check iPad first (810-1100)
    if (isIPadDevice(context)) {
      return iPad ?? tablet ?? largeTablet ?? desktop ?? mobile;
    }
    // Check Tablet (800-809 or 1101-1400)
    if (isTabletDevice(context)) {
      return tablet ?? iPad ?? largeTablet ?? desktop ?? mobile;
    }
    // Check Large Tablet (existing)
    if (isLargeTablet(context)) {
      return largeTablet ?? desktop ?? tablet ?? iPad ?? mobile;
    }
    // Check Desktop (existing)
    if (isDesktop(context)) {
      return desktop ?? tablet ?? iPad ?? largeTablet ?? mobile;
    }
    // Check old tablet method (for backward compatibility)
    if (isTablet(context)) {
      return tablet ?? iPad ?? mobile;
    }
    // Mobile (unaffected)
    return mobile;
  }

  /// Get responsive app bar height
  static double appBarHeight(BuildContext context) {
    if (isDesktop(context)) {
      return 80.0;
    } else if (isTablet(context)) {
      return 70.0;
    }
    return 56.0;
  }

  /// Get responsive bottom navigation bar height
  static double bottomNavBarHeight(BuildContext context) {
    if (isDesktop(context)) {
      return 70.0;
    } else if (isTablet(context)) {
      return 65.0;
    }
    return 60.0;
  }

  /// Check if platform is iOS
  static bool isIOS(BuildContext context) {
    return Platform.isIOS;
  }

  /// Check if platform is Android
  static bool isAndroid(BuildContext context) {
    return Platform.isAndroid;
  }

  /// Check if device is iPad (iOS + Tablet)
  static bool isIPad(BuildContext context) {
    return Platform.isIOS && isTablet(context);
  }

  /// Check if device is iPhone (iOS + Mobile)
  static bool isIPhone(BuildContext context) {
    return Platform.isIOS && isMobile(context);
  }

  /// Get device-specific font size multiplier
  static double getDeviceFontMultiplier(BuildContext context) {
    if (isIPad(context)) return 1.15; // iPad - slightly larger
    if (isIPhone(context)) return 1.0; // iPhone - normal
    if (isAndroid(context) && isTablet(context)) return 1.1; // Android Tablet
    if (isAndroid(context) && isMobile(context)) return 0.95; // Android Mobile - slightly smaller
    return 1.0; // Default
  }

  /// Get iOS-specific safe area padding
  static EdgeInsets iosSafeAreaPadding(BuildContext context) {
    if (!Platform.isIOS) {
      return EdgeInsets.zero;
    }
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Get iOS-specific button style
  /// Note: CupertinoButton doesn't have styleFrom, use CupertinoButton.filled instead
  static ButtonStyle iosButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    // For iOS, return a ButtonStyle that works with CupertinoButton
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }

  /// Get platform-adaptive text style (iOS uses SF Pro, Android uses Roboto)
  static TextStyle adaptiveTextStyle(BuildContext context, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    if (Platform.isIOS) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: '.SF Pro Text', // iOS default font
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'Roboto', // Android default font
    );
  }

  /// Get iOS-specific spacing (iOS uses 8pt grid system)
  static double iosSpacing(BuildContext context, double value) {
    if (!Platform.isIOS) {
      return spacing(context, value);
    }
    // iOS uses 8pt grid system, round to nearest 8
    return (value / 8).round() * 8.0;
  }

  /// Get iOS-specific border radius
  static double iosBorderRadius(BuildContext context, {double? mobile}) {
    if (!Platform.isIOS) {
      return borderRadius(context, mobile: mobile ?? 12.0);
    }
    // iOS typically uses 8, 12, 16, 20 for border radius
    return mobile ?? 12.0;
  }

  /// Get platform-adaptive button style
  static ButtonStyle adaptiveButtonStyle(BuildContext context, {
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
  }) {
    final isIOSDevice = isIOS(context);
    final isMobileDevice = isMobile(context);
    
    if (isIOSDevice) {
      return ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding(context, vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius(context)),
        ),
        elevation: elevation ?? 0,
      );
    }
    
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: padding(context, vertical: isMobileDevice ? 14 : 16, horizontal: isMobileDevice ? 20 : 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius(context)),
      ),
      elevation: elevation ?? 2,
    );
  }

  /// Get responsive text style
  static TextStyle textStyle(BuildContext context, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: ResponsiveHelper.fontSize(context, mobile: fontSize),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Get responsive heading text style
  static TextStyle headingStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 24, tablet: 28, desktop: 32),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color,
    );
  }

  /// Get responsive subheading text style
  static TextStyle subheadingStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 17, tablet: 20, desktop: 24),
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  /// Get responsive body text style
  static TextStyle bodyStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 16, tablet: 17, desktop: 18),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// Get responsive caption text style
  static TextStyle captionStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 12, tablet: 13, desktop: 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// Get responsive safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding;
  }

  /// Get responsive list item spacing
  static double listItemSpacing(BuildContext context) {
    return spacing(context, 12.0);
  }

  /// Get responsive grid spacing
  static double gridSpacing(BuildContext context) {
    return spacing(context, 16.0);
  }

  /// Get safe screen height (excluding status bar, app bar, etc.)
  static double safeScreenHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height - 
           mediaQuery.padding.top - 
           mediaQuery.padding.bottom;
  }

  /// Get safe screen width
  static double safeScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get responsive height that prevents overflow
  static double safeHeight(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? maxHeight,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Base height based on device type
    double baseHeight;
    if (isDesktop(context)) {
      baseHeight = desktop ?? tablet ?? mobile * 1.5;
    } else if (isTablet(context)) {
      baseHeight = tablet ?? mobile * 1.2;
    } else {
      baseHeight = mobile;
    }
    
    // Scale based on actual screen size
    final scaledHeight = baseHeight * scale;
    
    final maxAvailable = safeScreenHeight(context);
    final max = maxHeight ?? maxAvailable * 0.9;
    
    // Return the smaller of scaled height or max available
    return scaledHeight > max ? max : scaledHeight;
  }

  /// Get responsive width that prevents overflow
  static double safeWidth(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? maxWidth,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Base width based on device type
    double baseWidth;
    if (isDesktop(context)) {
      baseWidth = desktop ?? tablet ?? mobile * 1.5;
    } else if (isTablet(context)) {
      baseWidth = tablet ?? mobile * 1.2;
    } else {
      baseWidth = mobile;
    }
    
    // Scale based on actual screen size
    final scaledWidth = baseWidth * scale;
    
    final maxAvailable = safeScreenWidth(context);
    final max = maxWidth ?? maxAvailable * 0.95;
    
    // Return the smaller of scaled width or max available
    return scaledWidth > max ? max : scaledWidth;
  }

  /// Get responsive padding that adapts to actual screen size (prevents overflow)
  static EdgeInsets safePadding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final screenWidth = screenInfo['width']!;
    final screenHeight = screenInfo['height']!;
    
    // Calculate safe padding based on actual screen size
    double getSafeValue(double value) {
      final scaledValue = value * scale;
      
      // Ensure padding doesn't exceed 10% of screen width/height
      final maxHorizontal = screenWidth * 0.1;
      final maxVertical = screenHeight * 0.1;
      
      if (scaledValue > maxHorizontal) return maxHorizontal;
      if (scaledValue > maxVertical) return maxVertical;
      
      // Ensure minimum padding
      if (scaledValue < 4) return 4;
      
      return scaledValue;
    }
    
    if (all != null) {
      final safeAll = getSafeValue(all);
      return EdgeInsets.all(safeAll);
    }
    
    return EdgeInsets.only(
      left: left != null ? getSafeValue(left) : (horizontal != null ? getSafeValue(horizontal) : 0.0),
      right: right != null ? getSafeValue(right) : (horizontal != null ? getSafeValue(horizontal) : 0.0),
      top: top != null ? getSafeValue(top) : (vertical != null ? getSafeValue(vertical) : 0.0),
      bottom: bottom != null ? getSafeValue(bottom) : (vertical != null ? getSafeValue(vertical) : 0.0),
    );
  }

  /// Get responsive margin
  static EdgeInsets safeMargin(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final baseMargin = isDesktop(context) ? 16.0 : isTablet(context) ? 12.0 : 8.0;
    
    return EdgeInsets.only(
      top: top ?? vertical ?? all ?? baseMargin,
      bottom: bottom ?? vertical ?? all ?? baseMargin,
      left: left ?? horizontal ?? all ?? baseMargin,
      right: right ?? horizontal ?? all ?? baseMargin,
    );
  }

  /// Create a safe scrollable container
  static Widget safeScrollable({
    required BuildContext context,
    required Widget child,
    bool enableScroll = true,
    ScrollPhysics? physics,
  }) {
    if (!enableScroll) {
      return child;
    }
    
    return SingleChildScrollView(
      physics: physics ?? const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: safeScreenHeight(context),
        ),
        child: child,
      ),
    );
  }

  /// Get responsive SizedBox height
  static SizedBox sizedBoxHeight(BuildContext context, double height) {
    return SizedBox(height: spacing(context, height));
  }

  /// Get responsive SizedBox width
  static SizedBox sizedBoxWidth(BuildContext context, double width) {
    return SizedBox(width: spacing(context, width));
  }

  /// Get responsive container width (percentage based)
  static double widthPercent(BuildContext context, double percent) {
    return screenWidth(context) * (percent / 100);
  }

  /// Get responsive container height (percentage based)
  static double heightPercent(BuildContext context, double percent) {
    return screenHeight(context) * (percent / 100);
  }

  /// Get responsive dialog width
  static double dialogWidth(BuildContext context) {
    if (isDesktop(context)) {
      return screenWidth(context) * 0.4;
    } else if (isTablet(context)) {
      return screenWidth(context) * 0.6;
    }
    return screenWidth(context) * 0.9;
  }

  /// Get responsive dialog height
  static double dialogHeight(BuildContext context, {double? maxHeight}) {
    final height = isDesktop(context)
        ? screenHeight(context) * 0.6
        : isTablet(context)
            ? screenHeight(context) * 0.7
            : screenHeight(context) * 0.8;
    
    if (maxHeight != null && height > maxHeight) {
      return maxHeight;
    }
    return height;
  }

  /// Get responsive bottom sheet height
  static double bottomSheetHeight(BuildContext context, {double? maxHeight}) {
    final height = isDesktop(context)
        ? screenHeight(context) * 0.5
        : isTablet(context)
            ? screenHeight(context) * 0.6
            : screenHeight(context) * 0.7;
    
    if (maxHeight != null && height > maxHeight) {
      return maxHeight;
    }
    return height;
  }

  /// Get responsive drawer width - Device Adaptive (Mobile: 80%, Tablet: 40%, Desktop: 40%)
  static double drawerWidth(BuildContext context) {
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final screenHeight = ResponsiveHelper.screenHeight(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return screenWidth * 0.40; // 40% for large tablet
    }
    
    if (isMobile(context)) {
      // Mobile: 80% of screen width for better content visibility
      return screenWidth * 0.80;
    } else if (isTablet(context)) {
      // Tablet: 40% of screen width
      return screenWidth * 0.40;
    } else {
      // Desktop: 40% of screen width
      return screenWidth * 0.40;
    }
  }

  /// Get responsive FAB size
  static double fabSize(BuildContext context) {
    if (isDesktop(context)) {
      return 64;
    } else if (isTablet(context)) {
      return 56;
    }
    return 56;
  }

  /// Get responsive minimum touch target (44x44 for accessibility)
  static double minTouchTarget(BuildContext context) {
    return 44.0; // Always 44 for accessibility
  }

  /// Get responsive text field height
  /// Supports large tablet with larger sizes
  static double textFieldHeight(BuildContext context) {
    return buttonHeight(context, mobile: 48, tablet: 52, iPad: 56, largeTablet: 64, desktop: 56);
  }

  /// Get responsive divider thickness
  static double dividerThickness(BuildContext context) {
    return isDesktop(context) ? 1.5 : 1.0;
  }

  /// Get responsive elevation
  /// Supports iPad, Tablet, and Large Tablet without affecting mobile
  static double elevation(BuildContext context, {
    double mobile = 2.0,
    double? tablet,
    double? iPad,
    double? largeTablet,
    double? desktop,
  }) {
    // Check Large Tablet first (1200+ width, 1400+ height)
    if (isLargeTablet(context)) {
      return largeTablet ?? desktop ?? tablet ?? iPad ?? mobile * 1.5;
    }
    // Check iPad (810-1100)
    if (isIPadDevice(context)) {
      return iPad ?? tablet ?? largeTablet ?? desktop ?? mobile * 1.3;
    }
    // Check Tablet (800-809 or 1101-1400)
    if (isTabletDevice(context)) {
      return tablet ?? iPad ?? largeTablet ?? desktop ?? mobile * 1.2;
    }
    // Check Desktop (existing)
    if (isDesktop(context)) {
      return desktop ?? tablet ?? iPad ?? largeTablet ?? mobile * 1.5;
    }
    // Check old tablet method (for backward compatibility)
    if (isTablet(context)) {
      return tablet ?? iPad ?? largeTablet ?? mobile * 1.2;
    }
    // Mobile (unaffected)
    return mobile;
  }

  /// Get responsive max width for content (prevents content from being too wide on large screens)
  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 1200; // Max width for desktop
    } else if (isTablet(context)) {
      return 900; // Max width for tablet
    }
    return screenWidth(context); // Full width on mobile
  }

  /// Get responsive aspect ratio for images
  static double aspectRatio(BuildContext context, {
    double mobile = 16 / 9,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  /// Get responsive chip height
  /// Supports large tablet with larger sizes
  static double chipHeight(BuildContext context) {
    return buttonHeight(context, mobile: 32, tablet: 36, iPad: 38, largeTablet: 44, desktop: 40);
  }

  /// Get responsive switch size
  /// Supports large tablet with larger sizes
  static double switchSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return 1.4; // Larger scale for large tablets
    }
    if (isDesktop(context)) {
      return 1.2;
    } else if (isTablet(context)) {
      return 1.1;
    }
    return 1.0;
  }

  /// Get responsive checkbox size
  /// Supports large tablet with larger sizes
  static double checkboxSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return 36; // Large size for large tablets
    }
    if (isDesktop(context)) {
      return 28;
    } else if (isTablet(context)) {
      return 24;
    }
    return 24;
  }

  /// Get responsive radio size
  static double radioSize(BuildContext context) {
    return checkboxSize(context);
  }

  /// Get responsive slider track height
  /// Supports large tablet with larger sizes
  static double sliderTrackHeight(BuildContext context) {
    if (isLargeTablet(context)) {
      return 8; // Larger track for large tablets
    }
    if (isDesktop(context)) {
      return 6;
    } else if (isTablet(context)) {
      return 5;
    }
    return 4;
  }

  /// Get responsive progress indicator size
  /// Supports large tablet with larger sizes
  static double progressIndicatorSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return 56; // Larger size for large tablets
    }
    if (isDesktop(context)) {
      return 48;
    } else if (isTablet(context)) {
      return 40;
    }
    return 36;
  }

  /// Get responsive badge size
  /// Supports large tablet with larger sizes
  static double badgeSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return 24; // Larger size for large tablets
    }
    if (isDesktop(context)) {
      return 20;
    } else if (isTablet(context)) {
      return 18;
    }
    return 16;
  }

  /// Get responsive tooltip padding
  static EdgeInsets tooltipPadding(BuildContext context) {
    return padding(context, all: 8);
  }

  /// Get responsive snackbar margin
  static EdgeInsets snackbarMargin(BuildContext context) {
    return EdgeInsets.only(
      left: contentPadding(context),
      right: contentPadding(context),
      bottom: spacing(context, 16),
    );
  }

  /// Get responsive bottom navigation item size
  /// Supports large tablet with larger sizes
  static double bottomNavItemSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return 32; // Larger size for large tablets
    }
    if (isDesktop(context)) {
      return 28;
    } else if (isTablet(context)) {
      return 26;
    }
    return 24;
  }

  /// Get responsive tab bar height
  /// Supports large tablet with larger sizes
  static double tabBarHeight(BuildContext context) {
    if (isLargeTablet(context)) {
      return 64; // Larger height for large tablets
    }
    if (isDesktop(context)) {
      return 56;
    } else if (isTablet(context)) {
      return 52;
    }
    return 48;
  }

  /// Get responsive tab indicator size
  /// Supports large tablet with larger sizes
  static double tabIndicatorSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return 5; // Larger indicator for large tablets
    }
    if (isDesktop(context)) {
      return 4;
    } else if (isTablet(context)) {
      return 3;
    }
    return 3;
  }

  /// Check if device is an Android tablet
  static bool isAndroidTablet(BuildContext context) {
    return Platform.isAndroid && isTablet(context);
  }

  /// Check if device is an Android mobile
  static bool isAndroidMobile(BuildContext context) {
    return Platform.isAndroid && isMobile(context);
  }

  /// Get device-adaptive title size - PERFECT for TAB and IPAD
  static double adaptiveTitleSize(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return 32.0;
    }
    
    if (isIPad(context)) {
      return h >= 1400 ? 28.0 : 30.0;
    }
    if (isIPhone(context)) {
      return h > 850 ? 18.0 : 20.0;
    }
    if (isAndroidTablet(context)) {
      return h >= 1400 ? 28.0 : 30.0;
    }
    return h > 850 ? 18.0 : 20.0; // Android Mobile
  }

  /// Get device-adaptive subtitle size - PERFECT for TAB and IPAD
  static double adaptiveSubtitleSize(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return 24.0;
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return h >= 1400 ? 22.0 : 23.0;
    }
    return h > 850 ? 14.0 : 16.0; // Mobile
  }

  /// Get device-adaptive body text size - PERFECT for TAB and IPAD
  static double adaptiveBodySize(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return 22.0;
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return h >= 1400 ? 20.0 : 21.0;
    }
    return h > 850 ? 13.0 : 14.0; // Mobile
  }

  /// Get device-adaptive button text size - PERFECT for TAB and IPAD
  static double adaptiveButtonTextSize(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return 24.0;
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return h >= 1400 ? 22.0 : 23.0;
    }
    return h > 850 ? 14.0 : 15.0; // Mobile
  }

  /// Get device-adaptive button padding - PERFECT for TAB and IPAD
  static EdgeInsets adaptiveButtonPadding(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0);
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return EdgeInsets.symmetric(
        vertical: h >= 1400 ? 18.0 : 20.0,
        horizontal: 20.0,
      );
    }
    return EdgeInsets.symmetric(
      vertical: h > 850 ? 10.0 : 12.0,
      horizontal: 12.0,
    ); // Mobile
  }

  /// Get device-adaptive icon size - PERFECT for TAB and IPAD
  static double adaptiveIconSize(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return 28.0;
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return h >= 1400 ? 26.0 : 27.0;
    }
    return h > 850 ? 16.0 : 18.0; // Mobile
  }

  /// Get device-adaptive small icon size - PERFECT for TAB and IPAD
  static double adaptiveSmallIconSize(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return 24.0;
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return h >= 1400 ? 22.0 : 23.0;
    }
    return h > 850 ? 14.0 : 16.0; // Mobile
  }

  /// Get device-adaptive card padding - PERFECT for TAB and IPAD
  static EdgeInsets adaptiveCardPadding(BuildContext context) {
    final h = screenHeight(context);
    final w = screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0
    if (w >= 1200 && h >= 1800) {
      return EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0);
    }
    
    if (isIPad(context) || isAndroidTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0);
    }
    return EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0); // Mobile
  }

  // ============================================
  // TABLET/IPAD SPECIFIC METHODS (800px-1024px)
  // Based on common size: 800px × 1080px
  // ============================================

  /// Common tablet dimensions constants (for old tablet methods)
  static const double tabletCommonWidth = 800.0;
  static const double tabletCommonHeight = 1080.0;
  static const double oldTabletMinWidth = 800.0; // Renamed to avoid conflict
  static const double oldTabletMaxWidth = 1024.0; // Renamed to avoid conflict

  /// Check if device is tablet/iPad (800px - 1024px range)
  static bool isTabletOrIPad(BuildContext context) {
    final width = screenWidth(context);
    return width >= oldTabletMinWidth && width <= oldTabletMaxWidth;
  }

  /// Check if device is iPhone 12 size (device preview size - typically 1024px width)
  /// Used for device preview testing
  static bool isIPhone12Size(BuildContext context) {
    final width = screenWidth(context);
    // iPhone 12 device preview size is typically around 1024px width
    return width >= 1000 && width <= 1050;
  }

  /// Get tablet scale factor based on width (800px-1024px)
  /// Returns scale from 1.0 (800px) to 1.28 (1024px)
  static double getTabletScaleFactor(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return 1.0; // Not a tablet, return default
    }
    
    final width = screenWidth(context);
    // Scale from 800px (1.0) to 1024px (1.28)
    // Formula: (width - 800) / (1024 - 800) * 0.28 + 1.0
    final scale = ((width - oldTabletMinWidth) / (oldTabletMaxWidth - oldTabletMinWidth) * 0.28) + 1.0;
    return scale.clamp(1.0, 1.28);
  }

  /// Get tablet-adaptive text size (800px-1024px responsive)
  /// Only applies to tablets/iPads, phones remain unchanged
  static double tabletTextSize(BuildContext context, {
    required double baseSize, // Base size for 800px width
  }) {
    if (!isTabletOrIPad(context)) {
      return baseSize; // Return base size for phones
    }
    
    final scale = getTabletScaleFactor(context);
    final scaledSize = baseSize * scale;
    
    // Ensure readable minimum
    if (scaledSize < 12) return 12.0;
    
    return scaledSize;
  }

  /// Get tablet-adaptive heading size
  static double tabletHeadingSize(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return 24.0; // Default for phones
    }
    
    final width = screenWidth(context);
    // Scale from 28px (800px) to 36px (1024px)
    if (width <= 800) return 28.0;
    if (width >= 1024) return 36.0;
    return 28.0 + ((width - 800) / (1024 - 800) * 8.0);
  }

  /// Get tablet-adaptive subheading size
  static double tabletSubheadingSize(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return 18.0; // Default for phones
    }
    
    final width = screenWidth(context);
    // Scale from 22px (800px) to 28px (1024px)
    if (width <= 800) return 22.0;
    if (width >= 1024) return 28.0;
    return 22.0 + ((width - 800) / (1024 - 800) * 6.0);
  }

  /// Get tablet-adaptive body text size
  static double tabletBodySize(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return 16.0; // Default for phones
    }
    
    final width = screenWidth(context);
    // Scale from 18px (800px) to 22px (1024px)
    if (width <= 800) return 18.0;
    if (width >= 1024) return 22.0;
    return 18.0 + ((width - 800) / (1024 - 800) * 4.0);
  }

  /// Get tablet-adaptive button text size
  static double tabletButtonTextSize(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return 16.0; // Default for phones
    }
    
    final width = screenWidth(context);
    // Scale from 20px (800px) to 26px (1024px)
    if (width <= 800) return 20.0;
    if (width >= 1024) return 26.0;
    return 20.0 + ((width - 800) / (1024 - 800) * 6.0);
  }

  /// Get tablet-adaptive button height
  static double tabletButtonHeight(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return 48.0; // Default for phones
    }
    
    final width = screenWidth(context);
    // Scale from 56px (800px) to 64px (1024px)
    if (width <= 800) return 56.0;
    if (width >= 1024) return 64.0;
    return 56.0 + ((width - 800) / (1024 - 800) * 8.0);
  }

  /// Get tablet-adaptive button padding
  static EdgeInsets tabletButtonPadding(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0); // Default for phones
    }
    
    final width = screenWidth(context);
    final scale = getTabletScaleFactor(context);
    
    // Scale padding from 800px to 1024px
    final horizontal = (16.0 * scale).clamp(16.0, 24.0);
    final vertical = (14.0 * scale).clamp(14.0, 20.0);
    
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  /// Get tablet-adaptive icon size
  static double tabletIconSize(BuildContext context, {double? baseSize}) {
    final base = baseSize ?? 24.0;
    
    if (!isTabletOrIPad(context)) {
      return base; // Return base size for phones
    }
    
    final scale = getTabletScaleFactor(context);
    final scaledSize = base * scale;
    
    return scaledSize.clamp(base, base * 1.28);
  }

  /// Get tablet-adaptive image width
  static double tabletImageWidth(BuildContext context, {
    double? baseWidth,
    double? maxWidthPercent,
  }) {
    if (!isTabletOrIPad(context)) {
      final width = screenWidth(context);
      return baseWidth ?? (width * 0.9); // Default for phones
    }
    
    final width = screenWidth(context);
    final maxPercent = maxWidthPercent ?? 0.7;
    final maxW = width * maxPercent;
    
    // Scale from 70% (800px) to 75% (1024px) of screen width
    final scale = getTabletScaleFactor(context);
    final imageWidth = (width * 0.7 * scale).clamp(width * 0.5, maxW);
    
    return imageWidth;
  }

  /// Get tablet-adaptive image height
  static double tabletImageHeight(BuildContext context, {
    double? baseHeight,
    double? maxHeightPercent,
  }) {
    if (!isTabletOrIPad(context)) {
      final height = screenHeight(context);
      return baseHeight ?? (height * 0.3); // Default for phones
    }
    
    final height = screenHeight(context);
    final maxPercent = maxHeightPercent ?? 0.5;
    final maxH = height * maxPercent;
    
    // Scale from 40% (800px) to 45% (1024px) of screen height
    final scale = getTabletScaleFactor(context);
    final imageHeight = (height * 0.4 * scale).clamp(height * 0.3, maxH);
    
    return imageHeight;
  }

  /// Get tablet-adaptive padding
  static EdgeInsets tabletPadding(BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    if (!isTabletOrIPad(context)) {
      // Default padding for phones
      if (all != null) return EdgeInsets.all(all);
      return EdgeInsets.symmetric(
        horizontal: horizontal ?? 16.0,
        vertical: vertical ?? 12.0,
      );
    }
    
    final scale = getTabletScaleFactor(context);
    
    if (all != null) {
      final scaledAll = (all * scale).clamp(20.0, 28.0);
      return EdgeInsets.all(scaledAll);
    }
    
    final h = horizontal != null 
        ? (horizontal * scale).clamp(20.0, 28.0)
        : 24.0;
    final v = vertical != null
        ? (vertical * scale).clamp(16.0, 22.0)
        : 18.0;
    
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Get tablet-adaptive spacing
  static double tabletSpacing(BuildContext context, {double? baseSpacing}) {
    final base = baseSpacing ?? 16.0;
    
    if (!isTabletOrIPad(context)) {
      return base; // Return base spacing for phones
    }
    
    final scale = getTabletScaleFactor(context);
    return (base * scale).clamp(base, base * 1.28);
  }

  /// Get tablet-adaptive border radius
  static double tabletBorderRadius(BuildContext context, {double? baseRadius}) {
    final base = baseRadius ?? 12.0;
    
    if (!isTabletOrIPad(context)) {
      return base; // Return base radius for phones
    }
    
    final scale = getTabletScaleFactor(context);
    return (base * scale).clamp(base, base * 1.28);
  }

  /// Get tablet-adaptive SizedBox height
  static SizedBox tabletSizedBoxHeight(BuildContext context, double height) {
    if (!isTabletOrIPad(context)) {
      return SizedBox(height: height); // Return base height for phones
    }
    
    final scale = getTabletScaleFactor(context);
    return SizedBox(height: height * scale);
  }

  /// Get tablet-adaptive SizedBox width
  static SizedBox tabletSizedBoxWidth(BuildContext context, double width) {
    if (!isTabletOrIPad(context)) {
      return SizedBox(width: width); // Return base width for phones
    }
    
    final scale = getTabletScaleFactor(context);
    return SizedBox(width: width * scale);
  }

  /// Get tablet content max width (centered layout)
  static double tabletMaxContentWidth(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return screenWidth(context); // Full width for phones
    }
    
    final width = screenWidth(context);
    // Max content width: 90% of screen for tablets
    return width * 0.9;
  }

  /// Get tablet-adaptive card width
  static double tabletCardWidth(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return screenWidth(context) * 0.9; // Default for phones
    }
    
    final width = screenWidth(context);
    // Card width: 45% to 50% of screen based on tablet size
    final scale = getTabletScaleFactor(context);
    return width * (0.45 + (scale - 1.0) * 0.05);
  }

  /// Get tablet-adaptive card height
  static double tabletCardHeight(BuildContext context) {
    if (!isTabletOrIPad(context)) {
      return screenHeight(context) * 0.3; // Default for phones
    }
    
    final height = screenHeight(context);
    // Card height: 35% to 40% of screen based on tablet size
    final scale = getTabletScaleFactor(context);
    return height * (0.35 + (scale - 1.0) * 0.05);
  }
}

enum DeviceType {
  mobile,
  tablet,
  largeTablet,
  desktop,
}

