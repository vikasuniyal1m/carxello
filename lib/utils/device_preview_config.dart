import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Device Preview Configuration
/// 
/// This file configures device preview for testing the app on different devices.
/// Device preview is automatically enabled in debug mode.
/// 
/// Usage:
/// - Press 'd' key in debug mode to open device preview
/// - Or use DevicePreview.appBuilder in main.dart
class DevicePreviewConfig {
  /// Enable/Disable device preview
  /// Set to true to enable device preview in debug mode
  static const bool enableDevicePreview = true; // Enabled for debug mode
}

