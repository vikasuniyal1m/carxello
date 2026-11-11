import 'package:carauction/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NewForgotPasswordScreen extends StatefulWidget {
  const NewForgotPasswordScreen({super.key});

  @override
  State<NewForgotPasswordScreen> createState() => _NewForgotPasswordScreenState();
}

class _NewForgotPasswordScreenState extends State<NewForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final String apiUrl = '${ApiConfig.baseUrl}/forgot-password';

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _emailController.text,
          }),
        );

        print('API Response Status Code: ${response.statusCode}');
        print('API Response Body: ${response.body}');

        if (response.statusCode == 200) {
          // Show custom success dialog - Fully Responsive
          if (!mounted) return; // Check if the widget is still mounted
          showDialog(
            context: context,
            barrierDismissible: false, // User must tap button to close
            builder: (BuildContext dialogContext) {
              // Initialize ScreenSize in dialog context
              ScreenSize.init(context);
              
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ScreenSize.borderRadiusLarge),
                ),
                contentPadding: EdgeInsets.all(ScreenSize.paddingLarge),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: ScreenSize.iconLarge,
                      backgroundColor: Colors.green,
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: ScreenSize.iconExtraLarge,
                      ),
                    ),
                    SizedBox(height: ScreenSize.spacingLarge),
                    Text(
                      'Password Reset Link Sent !',
                      style: TextStyle(
                        fontSize: ScreenSize.headingMedium,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ScreenSize.spacingSmall),
                    Text(
                      'Instructions to reset your password have been sent to your email. Please check your inbox (and spam folder)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ScreenSize.textMedium,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: ScreenSize.spacingLarge),
                    SizedBox(
                      width: double.infinity,
                      height: ScreenSize.buttonHeightMedium,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); // Close the dialog
                          if (!mounted) return; // Check if the widget is still mounted
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37), // Gold color
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ScreenSize.borderRadiusMedium),
                          ),
                        ),
                        child: Text(
                          'Go to Login',
                          style: TextStyle(
                            fontSize: ScreenSize.textExtraLarge,
                            fontWeight: FontWeight.bold,
                            letterSpacing: ScreenSize.isTablet ? 1.0 : 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          final errorData = json.decode(response.body);
          if (!mounted) return; // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? 'Failed to send reset link.')),
          );
        }
      } catch (e) {
        if (!mounted) return; // Check if the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenSize for dynamic responsive calculations
    ScreenSize.init(context);
    
    // Use ScreenSize properties dynamically - automatically adapts to device
    final headingSize = ScreenSize.headingLarge;
    final subheadingSize = ScreenSize.textLarge;
    final textFieldSize = ScreenSize.textLarge;
    final buttonTextSize = ScreenSize.textExtraLarge;
    final buttonHeight = ScreenSize.buttonHeightMedium;
    final borderRadius = ScreenSize.borderRadiusMedium;
    
    return SafeScaffold(
      backgroundColor: Colors.white,
      enableScroll: true,
      appBar: AppBar(
        toolbarHeight: ScreenSize.appBarHeight,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: ScreenSize.iconMedium,
            color: Colors.black,
          ),
          padding: EdgeInsets.all(ScreenSize.paddingSmall*1.2),
          onPressed: () => Navigator.of(context).pop(),
        ),
        leadingWidth: ScreenSize.iconMedium + (ScreenSize.paddingSmall * 2.4) + ScreenSize.spacingSmall,
        title: Text(
          'Forgot Password',
          style: TextStyle(
            fontSize: headingSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: ScreenSize.appBarElevation,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ScreenSize.isTablet ? ScreenSize.widthPercent(70) : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenSize.paddingLarge,
                  vertical: ScreenSize.paddingLarge,
                ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: ScreenSize.spacingLarge),
                        // Heading text - Better size and centered
                        Text(
                          'Enter your email and will send you instruction on how to reset it',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: subheadingSize,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: ScreenSize.spacingLarge),
                    // Email TextField - Fully Responsive with full width
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: _emailController,
                        style: TextStyle(
                          fontSize: textFieldSize,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            fontSize: textFieldSize,
                          ),
                          hintText: 'Enter your email address',
                          hintStyle: TextStyle(
                            fontSize: textFieldSize,
                            color: Colors.grey.shade500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                            borderSide: BorderSide(color: LoginScreen.accentYellow, width: 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                            borderSide: BorderSide(color: LoginScreen.accentYellow, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                            borderSide: BorderSide(color: LoginScreen.accentYellow, width: 2.0),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ScreenSize.inputPadding,
                            vertical: ScreenSize.paddingMedium,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: ScreenSize.spacingLarge),
                    // Send Button - Fully Responsive
                    _isLoading
                        ? Center(
                            child: SizedBox(
                              width: ScreenSize.iconMedium,
                              height: ScreenSize.iconMedium,
                              child: CircularProgressIndicator(
                                strokeWidth: ScreenSize.isTablet ? 3.0 : 2.0,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _sendResetLink,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(borderRadius),
                                ),
                              ),
                              child: Text(
                                'Send',
                                style: TextStyle(
                                  fontSize: buttonTextSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: ScreenSize.isTablet ? 1.0 : 0.8,
                                ),
                              ),
                            ),
                          ),
                    SizedBox(height: ScreenSize.spacingLarge),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
        )
      
    );
  }
}