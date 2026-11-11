import 'package:flutter/material.dart';
import 'responsive_helper.dart';

// Colors
const Color kPrimaryColor = kWhiteColor; // Changed to white to ensure the drawer background is white
const Color kAccentColor = Color(0xFFDCA93E);
const Color kWhiteColor = Colors.white;
const Color kBlackColor = Colors.black;
const Color kLightGreyColor = Color(0xFFD3D3D3); // A common light grey color

// Theme Colors (matching CSS theme)
const Color kThemeColor = Color(0xFFF02801); // Primary theme color (red)
const Color kThemeColor2 = Color(0xFFFE8900); // Secondary theme color (orange)
const Color kThemeColor3 = Color(0xFFFFC000); // Tertiary theme color (yellow)
const Color kThemeColorBlue = Color(0xFF013677); // Alternative theme color (blue)

// Base Font Sizes (Mobile - will be scaled responsively)
const double kHeadingFontSize = 24.0;
const double kSubHeadingFontSize = 18.0;
const double kBodyFontSize = 16.0;
const double kSmallFontSize = 14.0;

// Base Spacing (Mobile - will be scaled responsively)
const double kPadding = 16.0;
const double kMargin = 16.0;
const double kSizedBoxHeight = 20.0;
const double kBorderRadius = 8.0;

// Image Heights
const double kLogoHeight = 150.0;

// Responsive Font Size Helper (using ResponsiveHelper)
double getResponsiveFontSize(BuildContext context, {required double baseFontSize}) {
  return ResponsiveHelper.fontSize(context, mobile: baseFontSize);
}

// Responsive Height Helper (using ResponsiveHelper)
double getResponsiveHeight(BuildContext context, {required double baseHeight}) {
  return ResponsiveHelper.heightMultiplier(context) * baseHeight;
}

// Responsive Width Helper (using ResponsiveHelper)
double getResponsiveWidth(BuildContext context, {required double baseWidth}) {
  return ResponsiveHelper.widthMultiplier(context) * baseWidth;
}

// Responsive Padding Helper
EdgeInsets getResponsivePadding(BuildContext context, {
  double? all,
  double? horizontal,
  double? vertical,
}) {
  return ResponsiveHelper.padding(context, all: all, horizontal: horizontal, vertical: vertical);
}

// Responsive Spacing Helper
double getResponsiveSpacing(BuildContext context, double baseSpacing) {
  return ResponsiveHelper.spacing(context, baseSpacing);
}

// Base URL for API and images
const String kBaseUrl = 'https://carauction.templateforwebsites.com/';

// Device Type Enum for responsiveness
enum DeviceType { mobile, tablet, desktop }

// Breakpoints for responsive design
const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1000.0; // Adjust as needed
