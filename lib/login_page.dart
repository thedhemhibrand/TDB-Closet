import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tdb_closet/forgot_password.dart';
import 'package:tdb_closet/home_page.dart';
import 'package:tdb_closet/signup_page.dart';
import 'package:tdb_closet/utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email') ?? '';
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember) {
      setState(() {
        _emailController.text = email;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('remember_me');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
              'fcmTokens': FieldValue.arrayUnion([token]),
            });
      }

      await _saveCredentials();

      _showToast('Welcome back!', Colors.green);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }
      _showToast(message, Colors.red);
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                80.h,
                Text(
                  'Welcome back to TDB Closets!',
                  style: DhemiText.headlineMedium,
                ),
                8.h,
                Text(
                  'Start shopping for wears and boost your confidence.',
                  style: DhemiText.tagline.copyWith(
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                40.h,
                _buildEmailField(),
                20.h,
                _buildPasswordField(),
                12.h,
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) {
                        setState(() {
                          _rememberMe = val!;
                        });
                      },
                      activeColor: DhemiColors.royalPurple,
                    ),
                    Text('Remember me', style: DhemiText.bodySmall),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: DhemiText.bodySmall.copyWith(
                          color: DhemiColors.royalPurple,
                        ),
                      ),
                    ),
                  ],
                ),
                30.h,
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : DhemiWidgets.button(
                        label: 'Sign In',
                        onPressed: _login,
                        fontSize: 18,
                      ),
                20.h,
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupPage(),
                        ),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: DhemiText.bodySmall,
                        children: [
                          TextSpan(
                            text: 'Sign Up',
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
          return 'Please enter your password';
        } else if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}
