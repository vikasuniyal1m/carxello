import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  final String? email;

  const ResetPasswordScreen({super.key, this.token, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _tokenController.text = widget.token!;
    }
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final String apiUrl = '${ApiConfig.baseUrl}/reset-password';

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'token': _tokenController.text,
            'email': _emailController.text,
            'password': _passwordController.text,
            'password_confirmation': _confirmPasswordController.text,
          }),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (!mounted) return; // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'])),
          );
          // Optionally navigate to login screen
          if (!mounted) return; // Check if the widget is still mounted
          Navigator.pop(context);
        } else {
          final errorData = json.decode(response.body);
          if (!mounted) return; // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? 'Password reset failed.')),
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
    final isTabletOrIPad = ResponsiveHelper.isTabletOrIPad(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return SafeScaffold(
      backgroundColor: Colors.white,
      enableScroll: true,
      appBar: AppBar(
        title: Text(
          'Reset Password',
          style: TextStyle(
            fontSize: isTabletOrIPad
                ? ResponsiveHelper.tabletHeadingSize(context)
                : ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTabletOrIPad
                  ? ResponsiveHelper.tabletMaxContentWidth(context)
                  : (isMobile ? double.infinity : 600),
            ),
            child: Padding(
              padding: isTabletOrIPad
                  ? ResponsiveHelper.tabletPadding(context, horizontal: 48.0, vertical: 32.0)
                  : ResponsiveHelper.safePadding(
                      context,
                      horizontal: isMobile ? 24.0 : 48.0,
                      vertical: 32.0,
                    ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Email TextField
                    TextFormField(
                      controller: _emailController,
                      style: TextStyle(
                        fontSize: isTabletOrIPad
                            ? ResponsiveHelper.tabletBodySize(context)
                            : ResponsiveHelper.fontSize(
                                context,
                                mobile: 16,
                                tablet: 17,
                                desktop: 18,
                              ),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(
                          fontSize: isTabletOrIPad
                              ? ResponsiveHelper.tabletBodySize(context)
                              : ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 17,
                                  desktop: 18,
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: ResponsiveHelper.dividerThickness(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: const Color(0xFFD4AF37),
                            width: ResponsiveHelper.dividerThickness(context) * 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: isTabletOrIPad
                            ? ResponsiveHelper.tabletPadding(context, horizontal: 20.0, vertical: 18.0)
                            : ResponsiveHelper.padding(
                                context,
                                horizontal: isMobile ? 16 : 20,
                                vertical: ResponsiveHelper.textFieldHeight(context) * 0.28,
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
                    isTabletOrIPad
                        ? ResponsiveHelper.tabletSizedBoxHeight(context, 16.0)
                        : ResponsiveHelper.sizedBoxHeight(context, 16.0),
                    // Token TextField
                    TextFormField(
                      controller: _tokenController,
                      style: TextStyle(
                        fontSize: isTabletOrIPad
                            ? ResponsiveHelper.tabletBodySize(context)
                            : ResponsiveHelper.fontSize(
                                context,
                                mobile: 16,
                                tablet: 17,
                                desktop: 18,
                              ),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Reset Token',
                        labelStyle: TextStyle(
                          fontSize: isTabletOrIPad
                              ? ResponsiveHelper.tabletBodySize(context)
                              : ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 17,
                                  desktop: 18,
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: ResponsiveHelper.dividerThickness(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: const Color(0xFFD4AF37),
                            width: ResponsiveHelper.dividerThickness(context) * 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: isTabletOrIPad
                            ? ResponsiveHelper.tabletPadding(context, horizontal: 20.0, vertical: 18.0)
                            : ResponsiveHelper.padding(
                                context,
                                horizontal: isMobile ? 16 : 20,
                                vertical: ResponsiveHelper.textFieldHeight(context) * 0.28,
                              ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the reset token';
                        }
                        return null;
                      },
                    ),
                    isTabletOrIPad
                        ? ResponsiveHelper.tabletSizedBoxHeight(context, 16.0)
                        : ResponsiveHelper.sizedBoxHeight(context, 16.0),
                    // New Password TextField
                    TextFormField(
                      controller: _passwordController,
                      style: TextStyle(
                        fontSize: isTabletOrIPad
                            ? ResponsiveHelper.tabletBodySize(context)
                            : ResponsiveHelper.fontSize(
                                context,
                                mobile: 16,
                                tablet: 17,
                                desktop: 18,
                              ),
                      ),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(
                          fontSize: isTabletOrIPad
                              ? ResponsiveHelper.tabletBodySize(context)
                              : ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 17,
                                  desktop: 18,
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: ResponsiveHelper.dividerThickness(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: const Color(0xFFD4AF37),
                            width: ResponsiveHelper.dividerThickness(context) * 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: isTabletOrIPad
                            ? ResponsiveHelper.tabletPadding(context, horizontal: 20.0, vertical: 18.0)
                            : ResponsiveHelper.padding(
                                context,
                                horizontal: isMobile ? 16 : 20,
                                vertical: ResponsiveHelper.textFieldHeight(context) * 0.28,
                              ),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your new password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters long';
                        }
                        return null;
                      },
                    ),
                    isTabletOrIPad
                        ? ResponsiveHelper.tabletSizedBoxHeight(context, 16.0)
                        : ResponsiveHelper.sizedBoxHeight(context, 16.0),
                    // Confirm Password TextField
                    TextFormField(
                      controller: _confirmPasswordController,
                      style: TextStyle(
                        fontSize: isTabletOrIPad
                            ? ResponsiveHelper.tabletBodySize(context)
                            : ResponsiveHelper.fontSize(
                                context,
                                mobile: 16,
                                tablet: 17,
                                desktop: 18,
                              ),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: TextStyle(
                          fontSize: isTabletOrIPad
                              ? ResponsiveHelper.tabletBodySize(context)
                              : ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 17,
                                  desktop: 18,
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: ResponsiveHelper.dividerThickness(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTabletOrIPad
                                ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                : ResponsiveHelper.borderRadius(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                          ),
                          borderSide: BorderSide(
                            color: const Color(0xFFD4AF37),
                            width: ResponsiveHelper.dividerThickness(context) * 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: isTabletOrIPad
                            ? ResponsiveHelper.tabletPadding(context, horizontal: 20.0, vertical: 18.0)
                            : ResponsiveHelper.padding(
                                context,
                                horizontal: isMobile ? 16 : 20,
                                vertical: ResponsiveHelper.textFieldHeight(context) * 0.28,
                              ),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    isTabletOrIPad
                        ? ResponsiveHelper.tabletSizedBoxHeight(context, 32.0)
                        : ResponsiveHelper.sizedBoxHeight(context, 32.0),
                    // Reset Password Button
                    _isLoading
                        ? Center(
                            child: SizedBox(
                              width: ResponsiveHelper.progressIndicatorSize(context),
                              height: ResponsiveHelper.progressIndicatorSize(context),
                              child: CircularProgressIndicator(
                                strokeWidth: ResponsiveHelper.dividerThickness(context) * 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.white,
                                padding: isTabletOrIPad
                                    ? ResponsiveHelper.tabletButtonPadding(context)
                                    : ResponsiveHelper.padding(
                                        context,
                                        horizontal: isMobile ? 24 : 32,
                                        vertical: isMobile ? 16 : 20,
                                      ),
                                minimumSize: Size(
                                  double.infinity,
                                  isTabletOrIPad
                                      ? ResponsiveHelper.tabletButtonHeight(context)
                                      : ResponsiveHelper.buttonHeight(
                                          context,
                                          mobile: 50,
                                          tablet: 56,
                                          desktop: 60,
                                        ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    isTabletOrIPad
                                        ? ResponsiveHelper.tabletBorderRadius(context, baseRadius: 12.0)
                                        : ResponsiveHelper.borderRadius(
                                            context,
                                            mobile: 12,
                                            tablet: 14,
                                            desktop: 16,
                                          ),
                                  ),
                                ),
                                elevation: ResponsiveHelper.elevation(
                                  context,
                                  mobile: 4,
                                  tablet: 6,
                                  desktop: 8,
                                ),
                              ),
                              child: Text(
                                'Reset Password',
                                style: TextStyle(
                                  fontSize: isTabletOrIPad
                                      ? ResponsiveHelper.tabletButtonTextSize(context)
                                      : ResponsiveHelper.fontSize(
                                          context,
                                          mobile: 18,
                                          tablet: 20,
                                          desktop: 22,
                                        ),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}