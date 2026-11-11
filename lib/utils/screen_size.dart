import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Screen Size Utility
/// Professional responsive design utility for device-adaptive UI
/// Calculates responsive sizes based on screen dimensions
/// All text, buttons, tiles, and UI elements use this for consistent sizing
class ScreenSize {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double statusBarHeight;
  static late double bottomBarHeight;
  static late double safeAreaTop;
  static late double safeAreaBottom;
  static late double safeAreaHorizontal;
  static late Orientation orientation;
  static late double devicePixelRatio;
  static late double textScaleFactor;
  
  // Device type detection - initialized with defaults
  static bool isSmallPhone = false;
  static bool isMediumPhone = false;
  static bool isLargePhone = false;
  static bool isTablet = false;
  static bool isSmallTablet = false;
  static bool isLargeTablet = false;
  
  // Responsive scale factors - initialized with defaults
  static double scaleFactor = 1.0;
  static double textScale = 1.0;
  static double spacingScale = 1.0;

  /// Initialize screen size - Call this in main.dart or at the start of each screen
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    statusBarHeight = _mediaQueryData.padding.top;
    bottomBarHeight = _mediaQueryData.padding.bottom;
    safeAreaTop = _mediaQueryData.padding.top;
    safeAreaBottom = _mediaQueryData.padding.bottom;
    safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    orientation = _mediaQueryData.orientation;
    devicePixelRatio = _mediaQueryData.devicePixelRatio;
    textScaleFactor = _mediaQueryData.textScaleFactor;
    
    // Detect device type
    _detectDeviceType();
    
    // Calculate scale factors
    _calculateScaleFactors();
    
    // Initialize ScreenUtil
    ScreenUtil.init(
      context,
      designSize: isTablet ? const Size(375, 812) : const Size(375, 812), // Use same design scale for tablets to ensure large, visible "phone-like" UI
      minTextAdapt: true,
      splitScreenMode: true,
    );
    
    // Debug: Log device detection (only in debug mode)
    if (kDebugMode) {
      print('[ScreenSize] Device Detected: ${deviceCategory}');
      print('[ScreenSize] Screen Width: ${screenWidth.toStringAsFixed(1)}px, Height: ${screenHeight.toStringAsFixed(1)}px');
      print('[ScreenSize] Text Scale: ${textScale.toStringAsFixed(2)}, Spacing Scale: ${spacingScale.toStringAsFixed(2)}');
      print('[ScreenSize] Orientation: ${orientation == Orientation.portrait ? 'Portrait' : 'Landscape'}');
    }
  }
  
  /// Detect device type based on screen width
  static void _detectDeviceType() {
    final width = screenWidth;
    
    // Small phones (iPhone SE, small Android phones) - < 360px
    isSmallPhone = width < 360;
    
    // Medium phones (standard phones like iPhone 12, most Android phones) - 360-414px
    isMediumPhone = width >= 360 && width < 414;
    
    // Large phones (iPhone Pro Max, Samsung Galaxy S25, large Android phones) - 414-600px
    isLargePhone = width >= 414 && width < 600;
    
    // Small tablets (iPad Mini, small Android tablets) - 600-768px
    isSmallTablet = width >= 600 && width < 768;
    
    // Large tablets (iPad Pro, large Android tablets) - >= 768px
    isLargeTablet = width >= 768;
    
    // General tablet check
    isTablet = width >= 600;
  }
  
  /// Calculate responsive scale factors
  static void _calculateScaleFactors() {
    // Base scale on screen width (375 is reference - iPhone X standard)
    final baseWidth = 375.0;
    scaleFactor = screenWidth / baseWidth;
    
    // Text scale - bigger for tablets/iPad for better visibility
    if (isSmallPhone) {
      textScale = 0.85; // Smaller text on small phones to prevent overflow
    } else if (isMediumPhone) {
      textScale = 0.95; // Slightly smaller on medium phones
    } else if (isLargePhone) {
      textScale = 1.0; // Standard text size on large phones (Samsung Galaxy S25, etc.)
    } else if (isSmallTablet) {
      textScale = 1.3; // Bigger text on small tablets (600-768px)
    } else if (isLargeTablet) {
      textScale = 1.5; // Even bigger text on large tablets (>= 768px)
    } else if (isTablet) {
      textScale = 1.4; // Bigger text on tablets
    } else {
      textScale = 1.0;
    }
    
    // Spacing scale - consistent for iPhone/mobile, scaled for tablets/iPad
    // iPhone spacing stays same (1.0) regardless of iPhone model
    if (isSmallPhone || isMediumPhone || isLargePhone) {
      spacingScale = 1.0; // Consistent spacing for all mobile phones (iPhone baseline)
    } else if (isSmallTablet) {
      spacingScale = 1.4; // More spacing on small tablets (based on iPhone baseline)
    } else if (isLargeTablet) {
      spacingScale = 1.6; // Even more spacing on large tablets (based on iPhone baseline)
    } else if (isTablet) {
      spacingScale = 1.5; // More spacing on tablets (based on iPhone baseline)
    } else {
      spacingScale = 1.0; // Default to iPhone baseline
    }
  }

  /// Get responsive width percentage
  static double widthPercent(double percent) {
    return screenWidth * (percent / 100);
  }

  /// Get responsive height percentage
  static double heightPercent(double percent) {
    return screenHeight * (percent / 100);
  }
  
  /// Get responsive font size based on device type
  static double responsiveFontSize(double baseSize) {
    return baseSize * textScale * scaleFactor;
  }
  
  /// Get responsive spacing based on device type
  static double responsiveSpacing(double baseSpacing) {
    return baseSpacing * spacingScale;
  }

  /// Text Sizes - Responsive and device-adaptive (bigger base sizes for tablets)
  static double get textExtraSmall => isTablet ? (12 * textScale).sp : (10 * textScale).sp;
  static double get textSmall => isTablet ? (14 * textScale).sp : (12 * textScale).sp;
  static double get textMedium => isTablet ? (16 * textScale).sp : (14 * textScale).sp;
  static double get textLarge => isTablet ? (18 * textScale).sp : (16 * textScale).sp;
  static double get textExtraLarge => isTablet ? (20 * textScale).sp : (18 * textScale).sp;
  
  /// Heading Sizes - Professional and responsive (bigger for tablets)
  static double get headingSmall => isTablet ? (24 * textScale).sp : (20 * textScale).sp;
  static double get headingMedium => isTablet ? (28 * textScale).sp : (24 * textScale).sp;
  static double get headingLarge => isTablet ? (32 * textScale).sp : (28 * textScale).sp;
  static double get headingExtraLarge => isTablet ? (36 * textScale).sp : (32 * textScale).sp;
  static double get headingHuge => isTablet ? (40 * textScale).sp : (36 * textScale).sp;
  
  /// Button Sizes - Touch-friendly and adaptive (bigger for tablets)
  static double get buttonHeightSmall => isTablet ? (50 * spacingScale).h : (40 * spacingScale).h;
  static double get buttonHeightMedium => isTablet ? (60 * spacingScale).h : (48 * spacingScale).h;
  static double get buttonHeightLarge => isTablet ? (70 * spacingScale).h : (56 * spacingScale).h;
  static double get buttonHeightExtraLarge => isTablet ? (80 * spacingScale).h : (64 * spacingScale).h;
  static double get buttonPaddingHorizontal => (24 * spacingScale).w;
  static double get buttonPaddingVertical => (12 * spacingScale).h;
  static double get buttonBorderRadius => 8.r;
  static double get buttonBorderRadiusLarge => 12.r;
  
  /// Tile/Card Sizes - Responsive card dimensions
  static double get tilePadding => (16 * spacingScale).w;
  static double get tileBorderRadius => 12.r;
  static double get tileBorderRadiusLarge => 16.r;
  static double get tileElevation => 2.0;
  static double get tileMargin => (8 * spacingScale).h;
  
  /// Icon Sizes - Adaptive icon sizing (bigger for tablets)
  static double get iconSmall => isTablet ? (20 * scaleFactor).w : (16 * scaleFactor).w;
  static double get iconMedium => isTablet ? (30 * scaleFactor).w : (24 * scaleFactor).w;
  static double get iconLarge => isTablet ? (40 * scaleFactor).w : (32 * scaleFactor).w;
  static double get iconExtraLarge => isTablet ? (56 * scaleFactor).w : (48 * scaleFactor).w;
  
  /// Spacing - Professional spacing system
  static double get spacingExtraSmall => (4 * spacingScale).h;
  static double get spacingXSmall => (4 * spacingScale).h; // Alias for spacingExtraSmall
  static double get spacingSmall => (8 * spacingScale).h;
  static double get spacingMedium => (15 * spacingScale).h;
  static double get spacingLarge => (24 * spacingScale).h;
  static double get spacingExtraLarge => (32 * spacingScale).h;
  static double get spacingXLarge => (32 * spacingScale).h; // Alias for spacingExtraLarge
  static double get spacingHuge => (48 * spacingScale).h;
  
  /// App Bar - Responsive app bar height
  static double get appBarHeight => (56 * spacingScale).h;
  static double get appBarElevation => 0.0;
  
  /// Bottom Navigation - Adaptive bottom nav
  static double get bottomNavHeight => (60 * spacingScale).h;
  static double get bottomNavIconSize => (24 * scaleFactor).w;
  
  /// Input Fields - Touch-friendly input sizes (bigger for tablets)
  static double get inputHeight => isTablet ? (60 * spacingScale).h : (48 * spacingScale).h;
  static double get inputBorderRadius => 8.r;
  static double get inputPadding => isTablet ? (20 * spacingScale).w : (16 * spacingScale).w;
  
  /// Checkbox Size - Adaptive checkbox sizing (bigger for tablets)
  static double get checkboxSize => isTablet ? (32 * scaleFactor).w : (24 * scaleFactor).w;
  
  /// Border Radius - General purpose border radius values
  static double get borderRadiusSmall => 6.r;
  static double get borderRadiusMedium => 12.r;
  static double get borderRadiusLarge => 16.r;
  
  /// Dividers
  static double get dividerHeight => 1.h;
  static double get dividerThickness => 0.5;
  
  /// Banner/Carousel Heights - Responsive banner sizes
  static double get bannerHeight => isTablet ? 220.h : 180.h;
  static double get bannerHeightLarge => isTablet ? 280.h : 220.h;
  
  /// Category Item Sizes - Adaptive category icons
  static double get categoryIconSize => isTablet ? 80.w : 70.w;
  static double get categoryItemWidth => isTablet ? 100.w : 80.w;
  static double get categorySectionHeight => isTablet ? 120.h : 100.h;
  
  /// Recommended Category Card Sizes - Larger for tablets
  static double get recommendedCardWidth => isLargeTablet ? 280.w : (isSmallTablet ? 240.w : 160.w);
  static double get recommendedCardHeight => isLargeTablet ? 320.h : (isSmallTablet ? 280.h : 180.h);
  static double get recommendedCardImageHeight => isLargeTablet ? 200.h : (isSmallTablet ? 180.h : 110.h);
  
  /// Product Card Sizes - Responsive product grid
  static double get productCardImageHeight => isTablet ? 180.h : 140.h;
  static double get productCardAspectRatio => isTablet ? 0.72 : 0.68;
  static double get productCardHorizontalWidth => isTablet ? 220.w : 200.w;
  static double get productCardHorizontalHeight => isTablet ? 300.h : 280.h;
  
  /// Car Card Image Heights - Responsive car listing image sizes (reduced height for buyer dashboard)
  static double get carCardImageHeight => isLargeTablet ? 220.h : (isSmallTablet ? 200.h : 130.h);
  
  /// Grid Configuration - Adaptive grid layouts
  static int get gridCrossAxisCount => isTablet ? 3 : 2; // 3 columns for tablet now that items are scaled up
  static double get gridSpacing => isTablet ? 16.w : 16.w;
  
  /// Padding/Margin - Responsive padding system
  static double get paddingExtraSmall => (4 * spacingScale).w;
  static double get paddingSmall => (8 * spacingScale).w;
  static double get paddingMedium => (16 * spacingScale).w;
  static double get paddingLarge => (24 * spacingScale).w;
  static double get paddingExtraLarge => (32 * spacingScale).w;
  
  /// Section Spacing - Professional section gaps
  static double get sectionSpacing => isTablet ? 32.h : 24.h;
  static double get sectionSpacingLarge => isTablet ? 48.h : 32.h;
  
  /// Badge Sizes - Responsive badge dimensions
  static double get badgeHeight => (20 * spacingScale).h;
  static double get badgePadding => (6 * spacingScale).w;
  static double get badgeFontSize => (10 * textScale).sp;
  
  /// Check if device is tablet
  static bool get isTabletDevice => isTablet;
  
  /// Check if device is phone
  static bool get isPhoneDevice => !isTablet;
  
  /// Check if landscape
  static bool get isLandscape => orientation == Orientation.landscape;
  
  /// Check if portrait
  static bool get isPortrait => orientation == Orientation.portrait;
  
  /// Get device category name (for debugging)
  static String get deviceCategory {
    if (isSmallPhone) return 'Small Phone';
    if (isMediumPhone) return 'Medium Phone';
    if (isLargePhone) return 'Large Phone';
    if (isSmallTablet) return 'Small Tablet';
    if (isLargeTablet) return 'Large Tablet';
    return 'Unknown';
  }
}

