// lib/pages/forgot_password_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:tdb_closet/utils.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  final _auth = FirebaseAuth.instance;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showToast(
        'Password reset link sent!\nCheck your inbox (and spam folder).',
        Colors.green,
      );
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.of(context).pop();
      });
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to send reset email.';
      if (e.code == 'user-not-found') {
        msg = 'No account found with this email.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email.';
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
      timeInSecForIosWeb: 5,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reset Password',
          style: DhemiText.subtitle.copyWith(color: DhemiColors.black),
        ),
        backgroundColor: DhemiColors.white,
        foregroundColor: DhemiColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DhemiColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: DhemiColors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your email and we’ll send you a link to reset your password.',
                style: DhemiText.bodySmall.copyWith(
                  color: DhemiColors.gray600,
                  height: 1.5,
                ),
              ),
              30.h,
              _buildEmailField(),
              30.h,
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DhemiWidgets.button(
                      label: 'Send Reset Link',
                      onPressed: _sendResetLink,
                      fontSize: 18,
                    ),
              20.h,
              Text.rich(
                TextSpan(
                  text: '💡 Didn’t receive the email?\n',
                  style: DhemiText.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: 'Check your spam or promotions folder.',
                      style: DhemiText.bodySmall.copyWith(
                        fontWeight: FontWeight.normal,
                        color: DhemiColors.gray600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
}
