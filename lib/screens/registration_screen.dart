import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedRole;
  bool _termsAccepted = false;
  bool _isLoading = false;
  String? _errorMessage; // Error message to display on screen
  String? _successMessage; // Success message to display on screen
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _errorKey = GlobalKey(); // Key for error message widget
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _phoneNumberController.dispose();
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRole == null || _selectedRole!.isEmpty) {
      print('❌ ERROR: Please select a user role');
      return;
    }

    if (!_termsAccepted) {
      print('❌ ERROR: Please accept the Terms of Service');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole!,
        _companyNameController.text.trim(),
        _phoneNumberController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['access_token'] != null) {
        // Success case
        String successMessage = result['message'] ?? 'Registration successful!';
        if (mounted) {
          setState(() {
            _successMessage = successMessage;
            _errorMessage = null; // Clear any previous error message
          });
        }
        print('✅ REGISTRATION SUCCESS: $successMessage');

        // Clear fields after successful registration
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _companyNameController.clear();
        _phoneNumberController.clear();
        setState(() {
          _selectedRole = null;
          _termsAccepted = false;
        });

        // Navigate to login page after a short delay to show success message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        });
        return; // Important to return after success
      } else if (result['error'] != null || result['message'] != null) {
        // Error case
        String errorMessage = result['error'] ?? result['message'] ?? 'Registration failed';
        if (result['errors'] != null) {
          // Laravel validation errors
          final errors = result['errors'] as Map<String, dynamic>;
          if (errors.containsKey('email') && errors['email'] is List) {
            errorMessage = errors['email'][0] ?? errorMessage;
          } else if (errors.containsKey('role') && errors['role'] is List) {
            errorMessage = errors['role'][0] ?? errorMessage;
          } else if (errors.isNotEmpty) {
            errorMessage = errors.values.first[0] ?? errorMessage;
          }
        }

        // Check if it's a role mismatch error
        bool isRoleMismatch = errorMessage.toLowerCase().contains('role') &&
                              (errorMessage.toLowerCase().contains('registered') ||
                               errorMessage.toLowerCase().contains('cannot register'));

        if (mounted) {
          setState(() {
            // Show detailed error on screen
            _errorMessage = errorMessage;
            _successMessage = null; // Clear any previous success message
          });
        }
        print('❌ REGISTRATION ERROR: $errorMessage');
        return;
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });

      print('❌ REGISTRATION EXCEPTION: Network error: ${e.toString()}');
      setState(() {
        _errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenSize for dynamic responsive calculations
    ScreenSize.init(context);
    
    return PopScope(
      canPop: true, // Allow normal back navigation
      onPopInvoked: (didPop) {
        if (didPop) {
          print('🔙 RegistrationScreen: Back button pressed - navigating back');
        }
      },
      child: _buildRegistrationContent(context),
    );
  }
  
  Widget _buildRegistrationContent(BuildContext context) {
    
    // Use ScreenSize properties dynamically - automatically adapts to device
    // Mobile UI remains unchanged, tablets get larger sizes automatically
    final headingSize = ScreenSize.headingLarge; // 28.sp (mobile), scales up for tablets
    final subheadingSize = ScreenSize.textLarge; // 16.sp (mobile), scales up for tablets
    final textFieldSize = ScreenSize.textLarge; // 16.sp (mobile), scales up for tablets
    final buttonTextSize = ScreenSize.textExtraLarge; // 18.sp (mobile), scales up for tablets
    final buttonHeight = ScreenSize.buttonHeightMedium; // 48.h (mobile), scales up for tablets
    final borderRadius = ScreenSize.borderRadiusMedium; // 12.r (mobile), scales up for tablets
    final spacing = ScreenSize.spacingMedium; // 15.h (mobile), scales up for tablets
    final linkSize = ScreenSize.textMedium; // 14.sp (mobile), scales up for tablets

    return SafeScaffold(
      backgroundColor: Colors.white,
      enableScroll: true,
      body: SafeContainer(
        padding: EdgeInsets.symmetric(
          horizontal: ScreenSize.paddingLarge, // 24.w (mobile), scales up for tablets
          vertical: ScreenSize.paddingMedium, // 16.w (mobile), scales up for tablets
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ScreenSize.isTablet ? ScreenSize.widthPercent(70) : double.infinity,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: ScreenSize.spacingSmall),
                  // Welcome user - Device Adaptive
                  Center(
                    child: Text(
                      'Welcome user',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: headingSize,
                        fontWeight: FontWeight.w700,
                        color: LoginScreen.accentYellow,
                        height: 1.2,
                        letterSpacing: ScreenSize.isTablet ? 0.8 : 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: ScreenSize.spacingSmall),
                  // Sign up to join text
                  Center(
                    child: Text(
                      'Sign up to join',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subheadingSize,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(height: ScreenSize.spacingLarge),
                  
                  // Success message display
                  if (_successMessage != null)
                    Container(
                      key: _errorKey, // Reusing errorKey for scrolling to message
                      width: double.infinity,
                      padding: EdgeInsets.all(ScreenSize.paddingMedium),
                      margin: EdgeInsets.only(bottom: ScreenSize.spacingMedium),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(color: Colors.green.shade300, width: 1),
                      ),
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          fontSize: ScreenSize.textMedium,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Error message display
                  if (_errorMessage != null)
                    Container(
                      key: _errorKey,
                      width: double.infinity,
                      padding: EdgeInsets.all(ScreenSize.paddingMedium),
                      margin: EdgeInsets.only(bottom: ScreenSize.spacingMedium),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(color: Colors.red.shade300, width: 1),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: ScreenSize.textMedium,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Full Name input
                  TextFormField(
                    controller: _nameController,
                    onChanged: (value) {
                      setState(() {
                        _errorMessage = null; // Clear error when user types
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(context, 'Full Name', textFieldSize, borderRadius),
                    style: TextStyle(
                      fontSize: textFieldSize,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  // Email input
                  TextFormField(
                    controller: _emailController,
                    onChanged: (value) {
                      setState(() {
                        _errorMessage = null; // Clear error when user types
                      });
                    },
                    validator: _validateEmail,
                    decoration: _buildInputDecoration(context, 'Email Address', textFieldSize, borderRadius),
                    style: TextStyle(
                      fontSize: textFieldSize,
                      color: Colors.black,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: spacing),
                  
                  // Password input with visibility toggle
                  TextFormField(
                    controller: _passwordController,
                    validator: _validatePassword,
                    decoration: _buildInputDecoration(context, 'Password', textFieldSize, borderRadius).copyWith(
                      suffixIcon: Tooltip(
                        message: _obscurePassword ? 'Show password' : 'Hide password',
                        child: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade700),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: textFieldSize,
                      color: Colors.black,
                    ),
                    obscureText: _obscurePassword,
                  ),
                  SizedBox(height: spacing),
                  
                  // Confirm Password input with visibility toggle
                  TextFormField(
                    controller: _confirmPasswordController,
                    validator: _validateConfirmPassword,
                    decoration: _buildInputDecoration(context, 'Confirm Password', textFieldSize, borderRadius).copyWith(
                      suffixIcon: Tooltip(
                        message: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                        child: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade700),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: textFieldSize,
                      color: Colors.black,
                    ),
                    obscureText: _obscureConfirmPassword,
                  ),
                  SizedBox(height: ScreenSize.spacingMedium),
                  
                  Text(
                    'How will you use CARXELLO ?',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: subheadingSize,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  // Select Role dropdown
                  Material(
                    color: Colors.transparent, // Make the Material widget transparent
                    child: DropdownSearch<String>(
                      decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(
                          color: Colors.black,
                          fontSize: textFieldSize,
                        ),
                        decoration: _buildInputDecoration(context, '', textFieldSize, borderRadius),
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
                          maxHeight: ScreenSize.isTablet ? 450.h : 350.h,
                        ),
                        menuProps: MenuProps(
                          backgroundColor: Colors.white,
                          elevation: ScreenSize.isTablet ? 10.0 : 8.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
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
                                  borderRadius: BorderRadius.circular(borderRadius * 0.8),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ScreenSize.paddingLarge,
                                  vertical: ScreenSize.paddingMedium,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.toString(),
                                        style: TextStyle(
                                          fontSize: ScreenSize.textExtraLarge,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected ? LoginScreen.accentYellow : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: LoginScreen.accentYellow,
                                        size: ScreenSize.iconLarge,
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
                            selectedItem ?? 'Select the User Role',
                            style: TextStyle(
                              color: selectedItem == null ? Colors.grey.shade500 : Colors.black87,
                              fontSize: textFieldSize,
                              fontWeight: selectedItem != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  // Business/Company name input
                  TextField(
                    controller: _companyNameController,
                    style: TextStyle(
                      fontSize: textFieldSize,
                      color: Colors.black,
                    ),
                    decoration: _buildInputDecoration(context, 'Business/Company name', textFieldSize, borderRadius),
                  ),
                  SizedBox(height: spacing),
                  
                  // Phone Number input
                  TextField(
                    controller: _phoneNumberController,
                    style: TextStyle(
                      fontSize: textFieldSize,
                      color: Colors.black,
                    ),
                    decoration: _buildInputDecoration(context, 'Phone Number', textFieldSize, borderRadius),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: ScreenSize.spacingSmall),
                  
                  // Terms of Service checkbox
                  Row(
                    children: [
                      SizedBox(
                        width: ScreenSize.checkboxSize,
                        height: ScreenSize.checkboxSize,
                        child: Checkbox(
                          value: _termsAccepted,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _termsAccepted = newValue ?? false;
                            });
                          },
                          activeColor: LoginScreen.accentYellow,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          checkColor: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              'I agree to the ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: linkSize,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // TODO: Navigate to Terms of Service
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: linkSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenSize.spacingMedium),
                  
                  // Sign Up button
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LoginScreen.accentYellow,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: ScreenSize.iconMedium,
                              height: ScreenSize.iconMedium,
                              child: CircularProgressIndicator(
                                strokeWidth: ScreenSize.isTablet ? 3.0 : 2.0,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: buttonTextSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: ScreenSize.isTablet ? 1.0 : 0.8,
                                height: 1.2,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: ScreenSize.spacingLarge),
                  
                  // Or separator
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: ScreenSize.dividerThickness,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: ScreenSize.paddingMedium),
                        child: Text(
                          'Or',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: linkSize,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: ScreenSize.dividerThickness,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenSize.spacingLarge),
                  
                  // Social login icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Sign Up Button
                      InkWell(
                        onTap: _isLoading ? null : () async {
                          if (_selectedRole == null) {
                            setState(() {
                              _errorMessage = 'Please select a role before signing up with Google';
                            });
                            _scrollToError(); // Scroll to error message
                            return;
                          }
                          
                          setState(() {
                            _isLoading = true;
                          });
                          
                          try {
                            final result = await _authService.signInWithGoogle(context, _selectedRole!);
                            
                            if (result['error'] != null) {
                              final errorMsg = result['error'] ?? 'Google Sign Up failed';
                              if (mounted) {
                                setState(() {
                                  _errorMessage = errorMsg.toString();
                                });
                                _scrollToError(); // Scroll to error message
                              }
                            } else if (result['access_token'] != null) {
                              // Success - navigation handled by auth_service
                              print('✅ Google Sign Up successful');
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Unable to sign up with Google. Please try again.';
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
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: Container(
                          padding: EdgeInsets.all(ScreenSize.isTablet ? 12 : 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(borderRadius),
                            color: Colors.white,
                          ),
                          child: Image.asset(
                            'assets/google.png',
                            height: ScreenSize.isTablet ? 32 : 28,
                            width: ScreenSize.isTablet ? 32 : 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.login,
                                size: ScreenSize.isTablet ? 28 : 24,
                                color: Colors.grey.shade700,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: ScreenSize.spacingMedium),
                      
                      // Apple Sign Up Button
                      InkWell(
                        onTap: _isLoading ? null : () async {
                          if (_selectedRole == null) {
                            setState(() {
                              _errorMessage = 'Please select a role before signing up with Apple';
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
                              final errorMsg = result['error'] ?? 'Apple Sign Up failed';
                              if (mounted) {
                                setState(() {
                                  _errorMessage = errorMsg.toString();
                                });
                                _scrollToError(); // Scroll to error message
                              }
                            } else if (result['access_token'] != null) {
                              // Success - navigation handled by auth_service
                              print('✅ Apple Sign Up successful');
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Unable to sign up with Apple. Please try again.';
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
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: Container(
                          padding: EdgeInsets.all(ScreenSize.isTablet ? 12 : 10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Icon(
                            Icons.apple,
                            size: ScreenSize.isTablet ? 28 : 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenSize.spacingLarge),
                  
                  // Have an account? Sign In
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Have an account? ',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: linkSize,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: ScreenSize.paddingSmall,
                            vertical: ScreenSize.paddingExtraSmall,
                          ),
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: LoginScreen.accentYellow,
                            fontWeight: FontWeight.bold,
                            fontSize: linkSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenSize.spacingLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, String hint, double fontSize, double borderRadius) {
    // Use ScreenSize for dynamic padding - automatically adapts to device
    final paddingH = ScreenSize.inputPadding;
    final paddingV = ScreenSize.paddingMedium;
    
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
      contentPadding: EdgeInsets.symmetric(
        horizontal: paddingH,
        vertical: paddingV,
      ),
    );
  }
  
  Widget _buildSocialIcon(BuildContext context, String assetPath, IconData fallbackIcon, VoidCallback onTap) {
    final borderRadius = ScreenSize.borderRadiusMedium;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.all(ScreenSize.isTablet ? 12 : 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(borderRadius),
          color: Colors.white,
        ),
        child: Image.asset(
          assetPath,
          height: ScreenSize.isTablet ? 32 : 28,
          width: ScreenSize.isTablet ? 32 : 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              fallbackIcon,
              size: ScreenSize.isTablet ? 28 : 24,
              color: Colors.grey.shade700,
            );
          },
        ),
      ),
    );
  }
}
