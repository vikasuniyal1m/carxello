import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/newsletter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsletterSubscriptionScreen extends StatefulWidget {
  const NewsletterSubscriptionScreen({super.key});

  @override
  State<NewsletterSubscriptionScreen> createState() => _NewsletterSubscriptionScreenState();
}

class _NewsletterSubscriptionScreenState extends State<NewsletterSubscriptionScreen> {
  final NewsletterService _service = NewsletterService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubscribed = false;
  bool _isLoading = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');

    if (userEmail != null && userEmail.isNotEmpty) {
      _emailController.text = userEmail;
      setState(() {
        _isChecking = true;
      });

      try {
        final status = await _service.checkStatus(userEmail);
        setState(() {
          _isSubscribed = status['subscribed'] as bool;
          _isChecking = false;
        });
      } catch (e) {
        setState(() {
          _isChecking = false;
        });
      }
    } else {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _subscribe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _service.subscribe(_emailController.text.trim());
      setState(() {
        _isSubscribed = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully subscribed to newsletter!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to subscribe: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unsubscribe() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _service.unsubscribe(_emailController.text.trim());
      setState(() {
        _isSubscribed = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully unsubscribed from newsletter'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unsubscribe: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: const Text('Newsletter Subscription'),
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kAccentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.email,
                            size: 48,
                            color: kAccentColor,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Stay Updated!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Subscribe to our newsletter to receive updates on new listings, promotions, and industry news.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Email Input
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
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
                    const SizedBox(height: 32),
                    // Status Display
                    if (_isSubscribed)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'You are currently subscribed to our newsletter',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _isSubscribed
                                ? _unsubscribe
                                : _subscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSubscribed ? Colors.red : kAccentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isSubscribed ? 'Unsubscribe' : 'Subscribe',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

