import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:carauction/utils/api_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
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

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (!mounted) return; // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'])),
          );
          // Optionally navigate to a confirmation screen or back to login
          if (!mounted) return; // Check if the widget is still mounted
          Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
          title: const Text(
            'Forgot Password',
          ),
        ),
      body: Center( // Center the entire content block
        child: ConstrainedBox( // Constrain the width of the content
          constraints: const BoxConstraints(maxWidth: 400), // Example max width
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0), // Adjust padding as needed
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email and will send you instruction on how to reset it',
                    style: TextStyle(fontSize: 14.0),
                  ),
                  const SizedBox(height: 30.0),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30.0),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _sendResetLink,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50), // Make button full width
                            backgroundColor: const Color(0xFFD4AF37), // Gold color
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Send'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}