import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tdb_closet/login_page.dart';

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
  bool _isLoading = false;
  String? _passwordStrength;

  final _auth = FirebaseAuth.instance;

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

    String strength;
    if (score <= 1) {
      strength = 'Weak';
    } else if (score == 2) {
      strength = 'Fair';
    } else if (score == 3) {
      strength = 'Good';
    } else {
      strength = 'Strong';
    }

    setState(() {
      _passwordStrength = strength;
    });
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordStrength == 'Weak' || _passwordStrength == 'Fair') {
      _showToast('Please use a stronger password.', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final token = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'fcmTokens': token != null ? [token] : [],
          });

      _showToast('Account created successfully!', Colors.green);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Signup failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email.';
      } else if (e.code == 'weak-password') {
        msg = 'Password is too weak. Use at least 6 characters.';
      }
      _showToast(msg, Colors.red);
    } catch (e) {
      _showToast('Something went wrong. Please try again.', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showToast(String msg, Color color) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
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
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your first name';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
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
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your last name';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
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
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      onChanged: _checkPasswordStrength,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: DhemiText.bodySmall,
        prefixIcon: Icon(Icons.lock_outline, color: DhemiColors.royalPurple),
        suffixIcon: const Icon(
          Icons.visibility_off,
          color: DhemiColors.gray500,
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
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        } else if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}
