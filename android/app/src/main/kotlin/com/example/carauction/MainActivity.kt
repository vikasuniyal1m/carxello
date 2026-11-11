package com.carauction.androidios

import android.os.Build
import android.os.Bundle
import android.view.WindowInsetsController
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configure window using modern APIs for edge-to-edge display (Android 15+ compatibility)
        // Note: FlutterActivity doesn't support enableEdgeToEdge(), so we use WindowCompat directly
        configureModernWindowInsets()
    }
    
    override fun onResume() {
        super.onResume()
        // Re-apply modern configuration after Flutter's internal calls
        configureModernWindowInsets()
    }
    
    /**
     * Configure window insets using modern, non-deprecated APIs.
     * This helps minimize the impact of Flutter's internal deprecated API calls.
     * Note: Flutter framework still uses deprecated APIs internally, but this
     * ensures we're using modern APIs where possible.
     */
    private fun configureModernWindowInsets() {
        val window = window ?: return
        
        // Ensure edge-to-edge is properly configured
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Get the window insets controller using modern API
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        
        // Configure system bars appearance using modern APIs
        // This replaces deprecated setStatusBarColor/setNavigationBarColor calls
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+): Use WindowInsetsController directly
            val insetsController = window.insetsController
            insetsController?.let {
                // Configure status bar and navigation bar appearance
                // Use APPEARANCE_LIGHT_STATUS_BARS for light icons on dark background
                // Use 0 for dark icons on light background
                val appearanceFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+ supports separate control
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                } else {
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                }
                
                it.setSystemBarsAppearance(
                    appearanceFlags,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                )
            }
        } else {
            // Android 10 and below: Use WindowInsetsControllerCompat
            windowInsetsController?.apply {
                isAppearanceLightStatusBars = true
                isAppearanceLightNavigationBars = true
            }
        }
    }
}
