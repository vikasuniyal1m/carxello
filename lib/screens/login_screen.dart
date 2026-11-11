import 'package:carauction/screens/home_page.dart';
import 'package:carauction/screens/registration_screen.dart';

import 'package:carauction/services/auth_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';

import 'new_forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  // Consistent yellow accent color
  static const Color accentYellow = Color(0xFFE6B94D);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isLoading = false; // Loading state to prevent multiple clicks
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? _selectedRole; // State variable to hold the selected role, initialized to null
  String? _errorMessage; // Error message to display on screen
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _errorKey = GlobalKey(); // Key for error message widget
  bool _obscurePassword = true; // Password visibility toggle

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll to error message
  void _scrollToError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_errorKey.currentContext != null) {
        Scrollable.ensureVisible(
          _errorKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    final savedPassword = prefs.getString('password');
    final savedRole = prefs.getString('user_role');

    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _selectedRole = savedRole;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    // Prevent multiple simultaneous login attempts
    if (_isLoading) {
      return;
    }

    if (_formKey.currentState!.validate()) {
        if (_selectedRole == null) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Please select a role before signing in';
            });
            _scrollToError(); // Scroll to error message
          }
          print('❌ ERROR: Please select a role');
          return;
        }

      // Set loading state
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _authService.login(
          context,
          _emailController.text,
          _passwordController.text,
          _selectedRole!,
        );

        // Check if login was successful (auth_service already saved token and navigated)
        if (response['access_token'] != null || response.containsKey('access_token')) {
          // Login successful - auth_service already handled navigation and token saving
          print('✅ Login successful, token saved');
          
          // Save remember me if needed
          if (_rememberMe) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('email', _emailController.text);
            await prefs.setString('password', _passwordController.text);
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('email');
            await prefs.remove('password');
          }
          
          // Reset loading state before navigation (if still mounted)
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          
          // Navigation is already handled by auth_service, but ensure data loads
          // Wait a bit for navigation to complete, then trigger data refresh
          Future.delayed(const Duration(milliseconds: 500), () {
            // Data will be loaded by HomePageController.onInit()
            print('🔄 Data should load automatically via HomePageController');
          });
        } else if (response['status_code'] == 422 || response['error'] != null) {
          // Handle validation errors (like role mismatch)
          final errorMessage = response['error'] ?? response['message'] ?? 'Login failed';
          final errors = response['errors'] ?? {};
          
          String displayMessage = errorMessage;
          // Extract role-specific error if available
          if (errors is Map && errors.containsKey('role') && errors['role'] is List) {
            displayMessage = errors['role'][0] ?? errorMessage;
          } else if (errors is Map && errors.containsKey('role')) {
            displayMessage = errors['role'].toString();
          }
          
          // Check if it's a role mismatch error
          bool isRoleMismatch = displayMessage.toLowerCase().contains('role') && 
                                (displayMessage.toLowerCase().contains('registered') || 
                                 displayMessage.toLowerCase().contains('cannot login'));
          
          if (mounted) {
            setState(() {
              // Show detailed error on screen
              _errorMessage = displayMessage;
            });
            _scrollToError(); // Scroll to error message
          }
        } else {
          // Login failed but no specific error message
          final errorMsg = response['message'] ?? 'Login failed. Please check your credentials.';
          if (mounted) {
            setState(() {
              _errorMessage = errorMsg;
            });
            _scrollToError(); // Scroll to error message
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'An error occurred. Please try again.';
          });
          _scrollToError(); // Scroll to error message
        }
      } finally {
        // Reset loading state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Form validation failed - show error for first invalid field
      if (mounted) {
        setState(() {
          _errorMessage = 'Please fill in all required fields correctly';
        });
        _scrollToError(); // Scroll to error message
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: Colors.white,
      enableScroll: true,
      body: SafeContainer(
        padding: ResponsiveHelper.padding(
          context,
          horizontal: 24,
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveHelper.isTablet(context) 
                  ? ResponsiveHelper.widthPercent(context, 70) 
                  : double.infinity,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Welcome back title
                  ResponsiveHelper.sizedBoxHeight(context, 12),
                  
                  Center(
                    child: Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 28, tablet: 32, largeTablet: 36),
                        fontWeight: FontWeight.w700,
                        color: LoginScreen.accentYellow,
                        letterSpacing: ResponsiveHelper.value(context, mobile: 0.5, tablet: 0.8),
                        height: 1.2,
                      ),
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 8),
                  
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, largeTablet: 20),
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 24),
                  
                  // Error message display
                  if (_errorMessage != null)
                    Container(
                      key: _errorKey,
                      width: double.infinity,
                      padding: ResponsiveHelper.padding(context, all: 12),
                      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                        ),
                        border: Border.all(color: Colors.red.shade300, width: 1),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, largeTablet: 16),
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Select Role dropdown
                  Material(
                    color: Colors.transparent, // Make the Material widget transparent
                    child: DropdownSearch<String>(
                      decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(
                          color: Colors.black,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, largeTablet: 18),
                        ),
                        decoration: _buildInputDecoration(context, ''),
                      ),
                      items: (filter, infiniteScrollProps) => const ['Seller/Buyer', 'Dealer', 'Transporter', 'Inspector'],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                          _errorMessage = null; // Clear error when role changes
                        });
                      },
                      selectedItem: _selectedRole,
                      popupProps: PopupProps.menu(
                        constraints: BoxConstraints(
                          maxHeight: ResponsiveHelper.isTablet(context) ? 400 : 350,
                        ),
                        menuProps: MenuProps(
                          backgroundColor: Colors.white,
                          elevation: ResponsiveHelper.elevation(context, mobile: 8, tablet: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                            ),
                          ),
                        ),
                        scrollbarProps: const ScrollbarProps(thumbVisibility: false),
                        itemBuilder: (context, item, isDisabled, isSelected) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isDisabled ? null : () {},
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? LoginScreen.accentYellow.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.borderRadius(context, mobile: 10, tablet: 12, largeTablet: 14),
                                  ),
                                ),
                                padding: ResponsiveHelper.padding(
                                  context,
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.toString(),
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, largeTablet: 18),
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected ? LoginScreen.accentYellow : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: LoginScreen.accentYellow,
                                        size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, largeTablet: 24),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      dropdownBuilder: (context, selectedItem) {
                         return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4), 
                          child: Text(
                            selectedItem ?? 'Select Role',
                            style: TextStyle(
                              color: selectedItem == null ? Colors.grey.shade500 : Colors.black87,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, largeTablet: 18),
                              fontWeight: selectedItem != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 16),
                  
                  // Email TextField
                  Material(
                    color: Colors.transparent,
                    child: TextFormField(
                      controller: _emailController,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, largeTablet: 18),
                        color: Colors.black,
                      ),
                      decoration: _buildInputDecoration(context, 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 16),
                  
                  // Password TextField with visibility toggle
                  Material(
                    color: Colors.transparent,
                    child: TextFormField(
                      controller: _passwordController,
                      onChanged: (value) {
                        setState(() {
                          _errorMessage = null; // Clear error when user types
                        });
                      },
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, largeTablet: 18),
                        color: Colors.black,
                      ),
                      decoration: _buildInputDecoration(context, 'Password').copyWith(
                        suffixIcon: Tooltip(
                          message: _obscurePassword ? 'Show password' : 'Hide password',
                          child: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey.shade700,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 16),
                  
                  // Remember me and Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: ResponsiveHelper.checkboxSize(context),
                            height: ResponsiveHelper.checkboxSize(context),
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value!;
                                });
                              },
                              activeColor: LoginScreen.accentYellow,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              checkColor: Colors.white,
                            ),
                          ),
                          ResponsiveHelper.sizedBoxWidth(context, 8),
                          Text(
                            'Remember me',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, largeTablet: 16),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewForgotPasswordScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: LoginScreen.accentYellow,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, largeTablet: 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 24),
                  
                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(context, mobile: 52, tablet: 56, largeTablet: 60),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LoginScreen.accentYellow,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                          ),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26, largeTablet: 28),
                              height: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26, largeTablet: 28),
                              child: CircularProgressIndicator(
                                strokeWidth: ResponsiveHelper.isTablet(context) ? 3.0 : 2.0,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, largeTablet: 22),
                                fontWeight: FontWeight.bold,
                                letterSpacing: ResponsiveHelper.value(context, mobile: 0.8, tablet: 1.0),
                              ),
                            ),
                    ),
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 24),
                  
                  // Divider with "OR"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: ResponsiveHelper.padding(context, horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, largeTablet: 16),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 24),
                  
                  // Social Sign In Buttons (Google and Apple)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Sign In Button
                      InkWell(
                        onTap: () {
                          if (_isLoading) return;
                          if (_selectedRole == null) {
                            setState(() {
                              _errorMessage = 'Please select a role before signing in with Google';
                            });
                            return;
                          }
                          setState(() { _isLoading = true; });
                          _authService.signInWithGoogle(context, _selectedRole!).then((response) {
                            if (response['error'] != null) {
                              print('❌ Google Sign In Error: ${response['error']}');
                              final errorMsg = response['error'] ?? 'Google Sign In failed';
                              bool isRoleMismatch = errorMsg.toString().toLowerCase().contains('role') && 
                                                    (errorMsg.toString().toLowerCase().contains('registered') || 
                                                     errorMsg.toString().toLowerCase().contains('cannot sign'));
                              
                              if (mounted) {
                                setState(() {
                                  _errorMessage = errorMsg.toString();
                                });
                                _scrollToError(); // Scroll to error message
                              }
                            } else {
                              print('✅ Google Sign In completed');
                            }
                          }).catchError((e) {
                            print('❌ Google Sign In Exception: $e');
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Unable to sign in with Google. Please try again.';
                                _isLoading = false;
                              });
                              _scrollToError(); // Scroll to error message
                            }
                          }).whenComplete(() {
                            if (mounted) {
                              setState(() { _isLoading = false; });
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                        ),
                        child: Container(
                          padding: ResponsiveHelper.padding(
                            context,
                            all: ResponsiveHelper.value(context, mobile: 10, tablet: 12, largeTablet: 14),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                            ),
                            color: Colors.white,
                          ),
                          child: Image.asset(
                            'assets/google.png',
                            height: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, largeTablet: 32),
                            width: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, largeTablet: 32),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.login,
                                size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, largeTablet: 32),
                                color: Colors.grey.shade700,
                              );
                            },
                          ),
                        ),
                      ),
                      ResponsiveHelper.sizedBoxWidth(context, 16),
                      
                      // Apple Sign In Button
                      InkWell(
                        onTap: _isLoading ? null : () async {
                          if (_selectedRole == null) {
                            setState(() {
                              _errorMessage = 'Please select a role first';
                            });
                            _scrollToError(); // Scroll to error message
                            return;
                          }
                          
                          setState(() {
                            _isLoading = true;
                          });
                          
                          try {
                            final result = await _authService.signInWithApple(context, _selectedRole!);
                            
                            if (result['error'] != null) {
                              final errorMsg = result['error'] ?? 'Apple Sign In failed';
                              bool isRoleMismatch = errorMsg.toString().toLowerCase().contains('role') && 
                                                    (errorMsg.toString().toLowerCase().contains('registered') || 
                                                     errorMsg.toString().toLowerCase().contains('cannot sign'));
                              
                              if (mounted) {
                                setState(() {
                                  _errorMessage = errorMsg.toString();
                                });
                                _scrollToError(); // Scroll to error message
                              }
                            } else if (result['access_token'] != null) {
                              // Success - navigation handled by auth_service
                              print('✅ Apple Sign In successful');
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Unable to sign in with Apple. Please try again.';
                              });
                              _scrollToError(); // Scroll to error message
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                        ),
                        child: Container(
                          padding: ResponsiveHelper.padding(
                            context,
                            all: ResponsiveHelper.value(context, mobile: 10, tablet: 12, largeTablet: 14),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16),
                            ),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Icon(
                            Icons.apple,
                            size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, largeTablet: 32),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 24),
                  
                  // Don't have an account? Sign Up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, largeTablet: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: ResponsiveHelper.padding(
                            context,
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: LoginScreen.accentYellow,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, largeTablet: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveHelper.sizedBoxHeight(context, 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, String hint) {
    final borderRadius = ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, largeTablet: 16);
    final fontSize = ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, largeTablet: 18);
    
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: fontSize,
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
      contentPadding: ResponsiveHelper.padding(
        context,
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}
