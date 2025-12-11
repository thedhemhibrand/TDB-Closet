// lib/screens/payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';
import 'package:tdb_closet/utils.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const PaymentPage({super.key, required this.orderData});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _flutterwavePublicKey;
  bool _isProcessing = false;
  bool _isLoadingKey = true;
  final String _paymentMethod = 'flutterwave';

  // Cache user data to avoid multiple fetches
  Map<String, dynamic>? _cachedUserData;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  /// Initialize payment by fetching API key and user data in parallel
  Future<void> _initializePayment() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showError('Please log in to complete your order.');
        return;
      }

      // Fetch API key and user data in parallel for faster loading
      final results = await Future.wait([
        _fetchFlutterwaveApiKey(),
        _getUserData(user.uid),
      ]);

      _flutterwavePublicKey = results[0] as String?;
      _cachedUserData = results[1] as Map<String, dynamic>?;

      if (_flutterwavePublicKey == null || _flutterwavePublicKey!.isEmpty) {
        _showError('Payment system unavailable. Please contact support.');
        return;
      }

      setState(() => _isLoadingKey = false);
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      _showError('Failed to initialize payment. Please try again.');
      setState(() => _isLoadingKey = false);
    }
  }

  /// Fetch Flutterwave API key from Firestore
  Future<String?> _fetchFlutterwaveApiKey() async {
    try {
      final apiDoc = await _firestore
          .collection('api')
          .doc('flutterwave')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Timeout fetching API key'),
          );

      if (apiDoc.exists) {
        final data = apiDoc.data();
        final key = data?['flutterwave'] as String?;

        if (key != null && key.isNotEmpty) {
          debugPrint('✅ API key fetched successfully');
          return key;
        }
      }

      debugPrint('⚠️ API key not found in Firestore');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching API key: $e');
      return null;
    }
  }

  /// Email validation helper
  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Fetch user data from Firestore
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Timeout fetching user data'),
          );

      if (userDoc.exists) {
        return userDoc.data();
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
    return null;
  }

  /// WEB-SPECIFIC: Open Flutterwave payment in popup/new tab
  Future<void> _processWebPayment(
    String txRef,
    int totalAmount,
    String customerEmail,
    String customerName,
    String customerPhone,
  ) async {
    try {
      // Create Flutterwave inline payment URL
      final redirectUrl = Uri.base.toString().replaceAll(
        RegExp(r'#.*$'),
        '#/payment-callback',
      );

      final paymentUrl = Uri.https('checkout.flutterwave.com', '/v3/hosted/pay', {
        'public_key': _flutterwavePublicKey!,
        'tx_ref': txRef,
        'amount': totalAmount.toString(),
        'currency': 'NGN',
        'customer[email]': customerEmail,
        'customer[name]': customerName,
        'customer[phone_number]': customerPhone,
        'customizations[title]': 'TDB Closet Order Payment',
        'customizations[description]': 'Payment for order $txRef',
        'redirect_url': redirectUrl,
        'payment_options': 'card,banktransfer,ussd',
      });

      debugPrint('🌐 Opening payment URL: $paymentUrl');

      // Open payment in popup window
      final popup = html.window.open(
        paymentUrl.toString(),
        'FlutterwavePayment',
        'width=600,height=800,scrollbars=yes,resizable=yes',
      );

      if (popup == null) {
        throw Exception('Popup blocked. Please allow popups for this site.');
      }

      // Listen for payment callback via window messages
      _listenForPaymentCallback(txRef, totalAmount, customerEmail, customerName, customerPhone);
    } catch (e) {
      debugPrint('❌ Web payment error: $e');
      rethrow;
    }
  }

  /// Listen for payment completion message from popup
  void _listenForPaymentCallback(
    String txRef,
    int totalAmount,
    String customerEmail,
    String customerName,
    String customerPhone,
  ) {
    html.window.onMessage.listen((event) async {
      debugPrint('📨 Received message: ${event.data}');

      if (event.data is Map && event.data['type'] == 'flutterwave-payment') {
        final status = event.data['status'] as String?;
        final transactionId = event.data['transaction_id'] as String?;

        if (status == 'successful' && transactionId != null) {
          final user = _auth.currentUser;
          if (user != null) {
            await _saveOrderAndPayment(
              txRef,
              totalAmount,
              user,
              customerEmail,
              customerName,
              customerPhone,
            );

            if (mounted) {
              _navigateToSuccessScreen(txRef, totalAmount);
            }
          }
        } else if (status == 'cancelled') {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showError('Payment was cancelled. Please try again.');
          }
        } else {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showError('Payment failed. Please try again.');
          }
        }
      }
    });
  }

  Future<void> _processPayment() async {
    if (_isProcessing) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showError('Please log in to complete your order.');
      return;
    }

    if (_flutterwavePublicKey == null || _flutterwavePublicKey!.isEmpty) {
      _showError('Payment system unavailable. Please try again.');
      return;
    }

    final userData = widget.orderData;
    final int totalAmount = userData['total'] as int;

    if (totalAmount <= 0) {
      _showError('Invalid order total.');
      return;
    }

    // Use cached user data if available
    final firestoreUserData = _cachedUserData ?? await _getUserData(user.uid);

    // Get email with priority order
    String customerEmail = '';
    if (firestoreUserData != null && firestoreUserData['email'] != null) {
      customerEmail = firestoreUserData['email'].toString().trim();
    } else if (userData['email'] != null &&
        userData['email'].toString().isNotEmpty) {
      customerEmail = userData['email'].toString().trim();
    } else if (userData['userEmail'] != null &&
        userData['userEmail'].toString().isNotEmpty) {
      customerEmail = userData['userEmail'].toString().trim();
    } else if (user.email != null && user.email!.isNotEmpty) {
      customerEmail = user.email!.trim();
    }

    // Validate email format
    if (!_isValidEmail(customerEmail)) {
      _showError(
        'A valid email address is required to process payment. Please update your profile.',
      );
      return;
    }

    // Get customer name
    String customerName = 'Customer';
    if (firestoreUserData != null) {
      final firstName = firestoreUserData['firstName']?.toString().trim() ?? '';
      final lastName = firestoreUserData['lastName']?.toString().trim() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        customerName = '$firstName $lastName'.trim();
      }
    } else if (userData['userName'] != null) {
      customerName = userData['userName'].toString().trim();
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      customerName = user.displayName!.trim();
    }

    // Get and validate phone
    String customerPhone = '';
    if (firestoreUserData != null && firestoreUserData['phone'] != null) {
      customerPhone = firestoreUserData['phone'].toString().trim();
    } else if (userData['userPhone'] != null) {
      customerPhone = userData['userPhone'].toString().trim();
    }

    String validatedPhone = customerPhone;
    if (validatedPhone.isNotEmpty) {
      validatedPhone = validatedPhone.replaceAll(RegExp(r'[^\d+]'), '');
      if (!validatedPhone.startsWith('+') && validatedPhone.length >= 10) {
        validatedPhone =
            '+234${validatedPhone.substring(validatedPhone.length - 10)}';
      }
    }

    if (validatedPhone.isEmpty) {
      validatedPhone = '+2340000000000';
    }

    setState(() => _isProcessing = true);

    try {
      final String txRef = 'TDB-${const Uuid().v4()}';

      debugPrint('💳 Payment Details:');
      debugPrint('  Customer: $customerName');
      debugPrint('  Email: $customerEmail');
      debugPrint('  Phone: $validatedPhone');
      debugPrint('  Amount: ₦$totalAmount');
      debugPrint('  Ref: $txRef');
      debugPrint('  Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');

      // Use web-specific payment flow for web platform
      if (kIsWeb) {
        await _processWebPayment(
          txRef,
          totalAmount,
          customerEmail,
          customerName,
          validatedPhone,
        );
        return;
      }

      // Mobile payment flow (original)
      final Customer customer = Customer(
        name: customerName,
        email: customerEmail,
        phoneNumber: validatedPhone,
      );

      final Flutterwave flutterwave = Flutterwave(
        publicKey: _flutterwavePublicKey!,
        currency: 'NGN',
        amount: totalAmount.toString(),
        customer: customer,
        txRef: txRef,
        paymentOptions: 'card,banktransfer,ussd',
        customization: Customization(
          title: 'TDB Closet Order Payment',
          description: 'Payment for order $txRef',
          logo: 'assets/images/flutterwave.png',
        ),
        isTestMode: false,
        redirectUrl: 'https://thedhemhicloset.com.ng/payment_callback.html',
      );

      final ChargeResponse response = await flutterwave.charge(context);

      debugPrint(
        '📱 Payment response: ${response.status ?? 'unknown'} - ${response.toString()}',
      );

      if (response.success == true && response.status == 'successful') {
        await _saveOrderAndPayment(
          txRef,
          totalAmount,
          user,
          customerEmail,
          customerName,
          validatedPhone,
        );

        if (mounted) {
          _navigateToSuccessScreen(txRef, totalAmount);
        }
      } else if (response.status == 'cancelled') {
        _showError('Payment was cancelled. Please try again.');
      } else {
        _showError(
          'Payment ${response.status ?? 'failed'}. ${response.toString()}',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Payment error: $e\n$st');

      String errorMessage = 'Payment failed. Please try again.';
      if (e.toString().toLowerCase().contains('email')) {
        errorMessage =
            'Invalid email address. Please check your profile and try again.';
      } else if (e.toString().toLowerCase().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().toLowerCase().contains('key')) {
        errorMessage = 'Payment configuration error. Please contact support.';
      } else if (e.toString().toLowerCase().contains('popup')) {
        errorMessage = 'Please enable popups for this site to complete payment.';
      }

      _showError(errorMessage);
    } finally {
      if (mounted && !kIsWeb) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveOrderAndPayment(
    String orderId,
    int totalAmount,
    User user,
    String customerEmail,
    String customerName,
    String customerPhone,
  ) async {
    final userData = widget.orderData;

    final orderRecord = {
      'orderId': orderId,
      'userId': user.uid,
      'userEmail': customerEmail,
      'userName': customerName,
      'userPhone': customerPhone,
      'deliveryAddress': userData['deliveryAddress'] ?? '',
      'deliveryOption': userData['deliveryOption'] ?? 'pickup',
      'items': userData['items'] ?? [],
      'subtotal': userData['subtotal'] ?? 0,
      'deliveryFee': userData['deliveryFee'] ?? 0,
      'total': totalAmount,
      'paymentMethod': _paymentMethod,
      'paymentStatus': 'paid',
      'orderStatus': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final paymentRecord = {
      'orderId': orderId,
      'userId': user.uid,
      'amount': totalAmount,
      'currency': 'NGN',
      'status': 'successful',
      'paymentMethod': _paymentMethod,
      'txRef': orderId,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save order, payment, and clear cart in parallel
    await Future.wait([
      _firestore.collection('orders').add(orderRecord),
      _firestore.collection('payments').add(paymentRecord),
      _clearUserCart(user.uid),
    ]);

    debugPrint('✅ Order, payment saved, and cart cleared successfully');
  }

  /// Clears cart items for the given user using 'userId' field
  Future<void> _clearUserCart(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cart')
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('ℹ️ No cart items found for user $userId');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('✅ Cart cleared for user: $userId');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Failed to clear cart for user $userId: $e\n$stackTrace');
    }
  }

  void _navigateToSuccessScreen(String orderId, int amount) {
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      '/payment-success',
      arguments: {
        'orderId': orderId,
        'amount': amount,
        'paymentMethod': _paymentMethod,
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.orderData['total'] as int;

    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        backgroundColor: DhemiColors.white,
        foregroundColor: DhemiColors.royalPurple,
        title: Text(
          'Secure Payment',
          style: DhemiText.bodyLarge.copyWith(fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoadingKey
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: DhemiColors.royalPurple),
                  16.h,
                  Text(
                    'Preparing payment...',
                    style: DhemiText.bodyMedium.copyWith(
                      color: DhemiColors.gray700,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: DhemiText.headlineSmall.copyWith(fontSize: 22),
                    ),
                    16.h,
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DhemiColors.gray50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DhemiColors.gray200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount:', style: DhemiText.body),
                              Text(
                                '₦$total',
                                style: DhemiText.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          8.h,
                          Text(
                            widget.orderData['deliveryOption'] == 'delivery'
                                ? '• Home Delivery (₦1,500)'
                                : '• Pickup at Link Sensation Junction',
                            style: DhemiText.bodySmall.copyWith(
                              color: DhemiColors.gray700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    30.h,
                    Text(
                      'Payment Method',
                      style: DhemiText.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    16.h,
                    _buildFlutterwaveTile(),
                    if (kIsWeb) ...[
                      12.h,
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            12.w,
                            Expanded(
                              child: Text(
                                'Please allow popups to complete payment',
                                style: DhemiText.bodySmall.copyWith(
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: DhemiWidgets.button(
                          label: _isProcessing ? 'Processing...' : 'Pay Now',
                          onPressed: _isProcessing
                              ? () {}
                              : () => _processPayment(),
                          fontSize: 18,
                          horizontalPadding: 32,
                          verticalPadding: 18,
                          minHeight: 56,
                        ),
                      ),
                    ),
                    20.h,
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFlutterwaveTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: DhemiColors.royalPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DhemiColors.royalPurple, width: 2),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/flutterwave.png',
            height: 28,
            width: 28,
            fit: BoxFit.contain,
          ),
          16.w,
          Expanded(
            child: Text(
              'Pay with Flutterwave',
              style: DhemiText.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: DhemiColors.royalPurple,
              ),
            ),
          ),
          Icon(Icons.lock, color: DhemiColors.royalPurple, size: 20),
        ],
      ),
    );
  }
}