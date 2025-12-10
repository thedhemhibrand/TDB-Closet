// lib/screens/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tdb_closet/payment_page.dart';
import 'package:tdb_closet/utils.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late Future<Map<String, dynamic>?> _userFuture;
  late Stream<QuerySnapshot> _cartStream;

  bool _isLoading = true;
  bool _saveAddress = true;
  String _deliveryOption = 'pickup'; // 'pickup' or 'delivery'
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserData();
    _cartStream = _firestore.collection('cart').snapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isLoading = false);
    });
  }

  // Helper method to safely convert numeric values to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<List<dynamic>> _fetchCartItems() async {
    final snapshot = await _firestore.collection('cart').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  void _proceedToPayment(BuildContext context) async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    if (_deliveryOption == 'delivery' &&
        _addressController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a delivery address'),
            backgroundColor: DhemiColors.gray800,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      final userData = await _userFuture;
      final cartItems = await _fetchCartItems();

      // Save address if requested
      if (_saveAddress && user != null && _deliveryOption == 'delivery') {
        final address = _addressController.text.trim();
        if (address.isNotEmpty) {
          await _firestore.collection('users').doc(user.uid).update({
            'savedAddress': address,
          });
        }
      }

      // Calculate total - Fixed: safe conversion
      int subtotal = cartItems.fold(0, (sum, item) {
        final price = _toInt(item['price']);
        final qty = _toInt(item['quantity']) == 0
            ? 1
            : _toInt(item['quantity']);
        return sum + (price * qty);
      });
      final deliveryFee = _deliveryOption == 'delivery' ? 1500 : 0;
      final total = subtotal + deliveryFee;

      // Prepare order payload
      final orderData = {
        'userId': user?.uid,
        'userEmail': userData?['email'] ?? user?.email,
        'userName':
            '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'
                .trim(),
        'userPhone': userData?['phone'],
        'deliveryOption': _deliveryOption,
        'deliveryAddress': _deliveryOption == 'delivery'
            ? _addressController.text.trim()
            : 'Link Sensation Junction',
        'items': cartItems,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Navigate to payment with data
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentPage(orderData: orderData),
          ),
        );
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to prepare order. Try again.'),
            backgroundColor: DhemiColors.gray800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: DhemiColors.white,
        appBar: AppBar(
          backgroundColor: DhemiColors.white,
          foregroundColor: DhemiColors.royalPurple,
          title: Text('Checkout', style: DhemiText.bodyLarge),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: DhemiColors.royalPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DhemiColors.gray50,
      appBar: AppBar(
        backgroundColor: DhemiColors.white,
        foregroundColor: DhemiColors.royalPurple,
        elevation: 0,
        title: Text(
          'Checkout',
          style: DhemiText.bodyLarge.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Personal Info Card
                _buildPersonalInfoCard(),

                20.h,

                // Shipping Address
                _buildShippingAddress(),

                20.h,

                // Delivery Option
                _buildDeliveryOption(),

                20.h,

                // Order Summary
                _buildOrderSummary(),

                30.h,

                // Proceed Button
                SizedBox(
                  width: double.infinity,
                  child: DhemiWidgets.button(
                    label: _isProcessing
                        ? 'Processing...'
                        : 'Proceed to Payment',
                    onPressed: _isProcessing
                        ? () {}
                        : () => _proceedToPayment(context),
                    fontSize: 18,
                    horizontalPadding: 32,
                    verticalPadding: 18,
                    minHeight: 56,
                  ),
                ),
                20.h,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoCard(
            title: 'Personal Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 20, color: DhemiColors.gray200),
                8.h,
                Container(width: 180, height: 20, color: DhemiColors.gray200),
              ],
            ),
          );
        }

        final user = snapshot.data;
        final name = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'
            .trim();
        final email = user?['email'] ?? _auth.currentUser?.email ?? '—';
        final phone = user?['phone'] ?? '—';

        return _buildInfoCard(
          title: 'Personal Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: DhemiText.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              4.h,
              Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: DhemiColors.gray600,
                  ),
                  6.w,
                  Flexible(
                    child: Text(
                      email,
                      style: DhemiText.bodySmall.copyWith(
                        color: DhemiColors.gray700,
                      ),
                    ),
                  ),
                ],
              ),
              6.h,
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: DhemiColors.gray600,
                  ),
                  6.w,
                  Flexible(
                    child: Text(
                      phone,
                      style: DhemiText.bodySmall.copyWith(
                        color: DhemiColors.gray700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShippingAddress() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          _addressController.text = '';
          return _buildInfoCard(
            title: 'Shipping Address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 100, color: DhemiColors.gray200),
                12.h,
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      color: DhemiColors.gray200,
                    ),
                    8.w,
                    Container(
                      width: 150,
                      height: 20,
                      color: DhemiColors.gray200,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final user = snapshot.data;
        final savedAddress = user?['savedAddress'] as String?;

        if (savedAddress != null && _addressController.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _addressController.text = savedAddress;
          });
        }

        return _buildInfoCard(
          title: 'Shipping Address',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your full delivery address',
                  hintStyle: DhemiText.bodySmall.copyWith(
                    color: DhemiColors.gray500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                validator: (value) {
                  if (_deliveryOption == 'delivery' &&
                      (value?.trim().isEmpty ?? true)) {
                    return 'Delivery address is required';
                  }
                  return null;
                },
              ),
              12.h,
              Row(
                children: [
                  Checkbox(
                    value: _saveAddress,
                    activeColor: DhemiColors.royalPurple,
                    onChanged: (value) =>
                        setState(() => _saveAddress = value ?? true),
                  ),
                  8.w,
                  Expanded(
                    child: Text(
                      'Save this address for future orders',
                      style: DhemiText.bodySmall.copyWith(
                        color: DhemiColors.gray800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryOption() {
    return _buildInfoCard(
      title: 'Delivery Option',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeliveryChoice(
            title: 'Pickup at Link Sensation Junction',
            subtitle: 'Free • No delivery fee',
            isSelected: _deliveryOption == 'pickup',
            onTap: () => setState(() => _deliveryOption = 'pickup'),
          ),
          12.h,
          _buildDeliveryChoice(
            title: 'Home Delivery',
            subtitle: '₦1,500 • Delivered to your address',
            isSelected: _deliveryOption == 'delivery',
            onTap: () => setState(() => _deliveryOption = 'delivery'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryChoice({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? DhemiColors.royalPurple.withOpacity(0.08)
              : DhemiColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? DhemiColors.royalPurple : DhemiColors.gray300,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DhemiColors.royalPurple, width: 2),
                color: isSelected
                    ? DhemiColors.royalPurple
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: DhemiColors.white)
                  : null,
            ),
            16.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DhemiText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  4.h,
                  Text(
                    subtitle,
                    style: DhemiText.bodySmall.copyWith(
                      color: DhemiColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cartStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoCard(
            title: 'Order Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 200, height: 20, color: DhemiColors.gray200),
                12.h,
                Container(width: 180, height: 20, color: DhemiColors.gray200),
                12.h,
                Container(width: 160, height: 24, color: DhemiColors.gray200),
              ],
            ),
          );
        }

        final cartItems = snapshot.data?.docs ?? [];
        int subtotal = 0;
        for (var doc in cartItems) {
          final data = doc.data() as Map<String, dynamic>;
          final price = _toInt(data['price']); // Fixed: safe conversion
          final qty = _toInt(data['quantity']) == 0
              ? 1
              : _toInt(data['quantity']); // Fixed: safe conversion
          subtotal += price * qty;
        }
        final deliveryFee = _deliveryOption == 'delivery' ? 1500 : 0;
        final total = subtotal + deliveryFee;

        return _buildInfoCard(
          title: 'Order Summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal (${cartItems.length} item${cartItems.length == 1 ? '' : 's'}):',
                    style: DhemiText.body,
                  ),
                  Text(
                    '₦$subtotal',
                    style: DhemiText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              8.h,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _deliveryOption == 'delivery'
                        ? 'Home Delivery Fee:'
                        : 'Pickup Fee:',
                    style: DhemiText.body,
                  ),
                  Text(
                    _deliveryOption == 'delivery' ? '₦1,500' : '₦0',
                    style: DhemiText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              16.h,
              const Divider(color: DhemiColors.gray300),
              8.h,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: DhemiText.bodyLarge.copyWith(fontSize: 18),
                  ),
                  Text(
                    '₦$total',
                    style: DhemiText.bodyLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DhemiColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: DhemiColors.gray300.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DhemiText.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          20.h,
          child,
        ],
      ),
    );
  }
}
