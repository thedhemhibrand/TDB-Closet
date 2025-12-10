import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tdb_closet/home_page.dart';
import 'package:tdb_closet/utils.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _passwordStrength;
  bool _obscurePassword = true;

  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() => _passwordStrength = null);
      return;
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;

    setState(() {
      _passwordStrength = score <= 1
          ? 'Weak'
          : score == 2
          ? 'Fair'
          : score == 3
          ? 'Good'
          : 'Strong';
    });
  }

  Future<String?> _getFCMToken() async {
    try {
      if (kIsWeb) {
        // Web FCM requires special setup
        String? token = await FirebaseMessaging.instance.getToken(
          vapidKey: null, // Add your VAPID key if you have FCM web configured
        );
        return token;
      } else {
        // Mobile FCM
        String? token = await FirebaseMessaging.instance.getToken();
        return token;
      }
    } catch (e) {
      debugPrint('FCM Token retrieval failed (non-critical): $e');
      return null;
    }
  }

  Future<void> _signup() async {
    // Defensive check: ensure Form is attached
    if (_formKey.currentState == null) {
      debugPrint('⚠️ Form key has no currentState — missing Form widget.');
      _showToast('UI error: Form not initialized. Please restart.', Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text.trim();
    if (_passwordStrength == 'Weak' || _passwordStrength == 'Fair') {
      _showToast(
        'Please use a stronger password (at least 8 chars, upper, number, symbol).',
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed — no user returned.');
      }

      // Get FCM token (non-blocking, won't fail signup)
      String? token = await _getFCMToken();

      final userData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'fcmTokens': token != null ? [token] : [],
        'uid': user.uid,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      await user.reload();

      // Check if widget is still mounted before navigation
      if (!mounted) return;

      _showToast('🎉 Account created! Welcome to TDB Closets!', Colors.green);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg = 'Signup failed. Please try again.';
      switch (e.code) {
        case 'email-already-in-use':
          msg = '📧 This email is already registered. Try logging in.';
          break;
        case 'invalid-email':
          msg = '📧 Please enter a valid email address.';
          break;
        case 'weak-password':
          msg = '🔒 Password too weak. Use min. 6 characters.';
          break;
        case 'operation-not-allowed':
          msg = '🚫 Signup is temporarily disabled. Contact support.';
          break;
        case 'network-request-failed':
          msg = '📶 Network error. Check your connection and try again.';
          break;
        default:
          msg = '❌ Signup failed: ${e.message ?? e.code}';
      }
      _showToast(msg, Colors.red);
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
    } catch (e, stackTrace) {
      if (!mounted) return;

      _showToast(
        '❌ Something unexpected happened. Please try again.',
        Colors.red,
      );
      debugPrint('Signup Error: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String msg, Color color) {
    if (kIsWeb) {
      // Fluttertoast might not work well on web, use ScaffoldMessenger as fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 4,
        backgroundColor: color,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  80.h,
                  Text('Create Account', style: DhemiText.headlineMedium),
                  8.h,
                  Text(
                    'Join us today',
                    style: DhemiText.tagline.copyWith(
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  30.h,
                  _buildFirstNameField(),
                  20.h,
                  _buildLastNameField(),
                  20.h,
                  _buildPhoneField(),
                  20.h,
                  _buildEmailField(),
                  20.h,
                  _buildPasswordField(),
                  if (_passwordStrength != null) ...[
                    8.h,
                    Text(
                      'Password strength: $_passwordStrength',
                      style: TextStyle(
                        color: _passwordStrength == 'Weak'
                            ? Colors.red
                            : _passwordStrength == 'Fair'
                            ? Colors.orange
                            : _passwordStrength == 'Good'
                            ? Colors.blue
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  30.h,
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : DhemiWidgets.button(
                          label: 'Sign Up',
                          onPressed: _signup,
                          fontSize: 18,
                          minHeight: 48,
                        ),
                  20.h,
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          style: DhemiText.bodySmall,
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: DhemiText.bodySmall.copyWith(
                                color: DhemiColors.royalPurple,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildFirstNameField() => TextFormField(
        controller: _firstNameController,
        decoration: InputDecoration(
          labelText: 'First Name',
          labelStyle: DhemiText.bodySmall,
          prefixIcon: Icon(Icons.person_outline, color: DhemiColors.royalPurple),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.royalPurple, width: 2),
          ),
        ),
        validator: (value) =>
            value?.trim().isEmpty == true ? 'Please enter your first name' : null,
      );

  Widget _buildLastNameField() => TextFormField(
        controller: _lastNameController,
        decoration: InputDecoration(
          labelText: 'Last Name',
          labelStyle: DhemiText.bodySmall,
          prefixIcon: Icon(Icons.person_outline, color: DhemiColors.royalPurple),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.royalPurple, width: 2),
          ),
        ),
        validator: (value) =>
            value?.trim().isEmpty == true ? 'Please enter your last name' : null,
      );

  Widget _buildPhoneField() => TextFormField(
        controller: _phoneController,
        decoration: InputDecoration(
          labelText: 'Phone Number',
          labelStyle: DhemiText.bodySmall,
          prefixIcon: Icon(Icons.phone_outlined, color: DhemiColors.royalPurple),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.royalPurple, width: 2),
          ),
        ),
        keyboardType: TextInputType.phone,
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return 'Please enter your phone number';
          final digitsOnly = RegExp(
            r'\d{10,}',
          ).hasMatch(trimmed.replaceAll(RegExp(r'\D'), ''));
          if (!digitsOnly) {
            return 'Please enter a valid phone number (e.g. +2348012345678)';
          }
          return null;
        },
      );

  Widget _buildEmailField() => TextFormField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
          labelStyle: DhemiText.bodySmall,
          prefixIcon: Icon(Icons.email_outlined, color: DhemiColors.royalPurple),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.royalPurple, width: 2),
          ),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          final email = value?.trim();
          if (email == null || email.isEmpty) return 'Please enter your email';
          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
          if (!emailRegex.hasMatch(email)) return 'Please enter a valid email';
          return null;
        },
      );

  Widget _buildPasswordField() => TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        onChanged: _checkPasswordStrength,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: DhemiText.bodySmall,
          prefixIcon: Icon(Icons.lock_outline, color: DhemiColors.royalPurple),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: DhemiColors.gray500,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DhemiColors.royalPurple, width: 2),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter a password';
          if (value.length < 6) return 'Password must be at least 6 characters';
          return null;
        },
      );
}