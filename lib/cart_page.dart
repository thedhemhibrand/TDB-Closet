// lib/screens/cart_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tdb_closet/checkout.dart';
import 'package:tdb_closet/product_details.dart';
import 'package:tdb_closet/utils.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  static Future<void> clearCart() async {
    final cartRef = FirebaseFirestore.instance.collection('cart');
    final snapshot = await cartRef.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _cartStream;
  bool _isProcessing = false;

  // Cache product stock by productId to avoid repeated fetches
  final Map<String, int> _productStockCache = {};

  @override
  void initState() {
    super.initState();
    _cartStream = _firestore.collection('cart').snapshots();
  }

  Future<void> _removeItem(String docId) async {
    await _firestore.collection('cart').doc(docId).delete();
  }

  // Enhanced: Respect stock limit when updating quantity
  Future<void> _updateQuantity(
    String docId,
    int newQty,
    String productId,
  ) async {
    if (newQty < 1) return;

    // Fetch or use cached stock
    int? stock = _productStockCache[productId];
    if (stock == null) {
      try {
        final productDoc = await _firestore
            .collection('products')
            .doc(productId)
            .get();
        if (productDoc.exists) {
          stock = (productDoc.data()?['stock'] as int?) ?? 999;
          _productStockCache[productId] = stock;
        } else {
          stock = 999;
        }
      } catch (e) {
        debugPrint('Error fetching product stock: $e');
        stock = 999;
      }
    }

    // Check if new quantity exceeds stock
    if (newQty > stock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only $stock available in stock!'),
            backgroundColor: DhemiColors.gray800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await _firestore.collection('cart').doc(docId).update({'quantity': newQty});
  }

  Future<List<dynamic>> _fetchRecommendations() async {
    try {
      final snapshot = await _firestore.collection('products').limit(4).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
      return [];
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        title: Text(
          "Shopping Cart",
          style: DhemiText.bodyLarge.copyWith(
            fontSize: 20,
            color: DhemiColors.royalPurple,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _cartStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: DhemiColors.royalPurple,
                ),
              );
            }

            final cartItems = snapshot.data?.docs ?? [];
            final isEmpty = cartItems.isEmpty;

            // Use Column with Expanded to push button to bottom
            return Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEmpty) ...[
                          _buildEmptyCart(),
                          32.h,
                          FutureBuilder<List<dynamic>>(
                            future: _fetchRecommendations(),
                            builder: (context, recSnapshot) {
                              if (recSnapshot.hasData) {
                                final recs = recSnapshot.data!;
                                if (recs.isNotEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Recommended For You",
                                        style: DhemiText.bodyLarge.copyWith(
                                          color: DhemiColors.black,
                                          fontSize: 20,
                                        ),
                                      ),
                                      16.h,
                                      SizedBox(
                                        height: 240,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: recs.length,
                                          itemBuilder: (context, i) {
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                right: i == recs.length - 1
                                                    ? 0
                                                    : 16,
                                              ),
                                              child: _buildRecommendedProduct(
                                                recs[i],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ] else ...[
                          ...cartItems.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name =
                                data['name'] as String? ?? 'Unknown Item';
                            final price = _toInt(data['price']);
                            final qty = _toInt(data['quantity']) == 0
                                ? 1
                                : _toInt(data['quantity']);
                            final image = data['image'] as String?;
                            final size = data['size'] as String?;
                            final productId =
                                data['productId'] as String? ?? name;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: DhemiColors.gray50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: DhemiColors.gray200),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: image != null
                                        ? Image.network(
                                            image,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: DhemiColors.gray100,
                                                  child: const Icon(
                                                    Icons.image,
                                                    color: DhemiColors.gray400,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: DhemiColors.gray100,
                                            child: const Icon(
                                              Icons.image,
                                              color: DhemiColors.gray400,
                                            ),
                                          ),
                                  ),
                                  16.w,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: DhemiText.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (size != null) ...[
                                          4.h,
                                          Text(
                                            'Size: $size',
                                            style: DhemiText.bodySmall.copyWith(
                                              color: DhemiColors.gray700,
                                            ),
                                          ),
                                        ],
                                        8.h,
                                        Text(
                                          "₦${price * qty}",
                                          style: DhemiText.bodyLarge.copyWith(
                                            color: DhemiColors.royalPurple,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildQuantityControl(
                                        qty: qty,
                                        onIncrement: () => _updateQuantity(
                                          doc.id,
                                          qty + 1,
                                          productId,
                                        ),
                                        onDecrement: () => _updateQuantity(
                                          doc.id,
                                          qty - 1,
                                          productId,
                                        ),
                                      ),
                                      12.h,
                                      GestureDetector(
                                        onTap: () => _removeItem(doc.id),
                                        child: Icon(
                                          Icons.delete_outline,
                                          color: DhemiColors.gray500,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Summary
                          _buildCartSummary(cartItems),

                          // Extra bottom padding for scrolling
                          24.h,
                        ],
                      ],
                    ),
                  ),
                ),

                // Fixed checkout button at bottom (only shown when cart is not empty)
                if (!isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DhemiColors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: DhemiWidgets.button(
                        label: "Proceed to Checkout",
                        onPressed: !_isProcessing
                            ? () {
                                setState(() => _isProcessing = true);
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                    if (mounted) {
                                      setState(() => _isProcessing = false);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CheckoutPage(),
                                        ),
                                      );
                                    }
                                  },
                                );
                              }
                            : () {},
                        fontSize: 17,
                        horizontalPadding: 32,
                        verticalPadding: 18,
                        minHeight: 56,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: DhemiColors.gray100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DhemiColors.gray200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: DhemiColors.royalPurple,
          ),
          16.h,
          Text(
            "Your cart is empty",
            style: DhemiText.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          10.h,
          Text(
            "Browse our collection to find items you love",
            style: DhemiText.bodySmall.copyWith(color: DhemiColors.gray600),
            textAlign: TextAlign.center,
          ),
          24.h,
          DhemiWidgets.button(
            label: "Continue Shopping",
            onPressed: () => Navigator.of(context).pop(),
            fontSize: 16,
            horizontalPadding: 32,
            verticalPadding: 16,
            minHeight: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedProduct(Map<String, dynamic> product) {
    final price = _toInt(product['price']);
    final productId =
        product['productId'] as String? ??
        product['name'] as String? ??
        'unknown';

    return SizedBox(
      width: 160,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsPage(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 0.85,
                child: Image.network(
                  (product['images'] as List?)?.isNotEmpty == true
                      ? (product['images'][0] as String).trim()
                      : 'https://via.placeholder.com/150',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loading) {
                    if (loading == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: DhemiColors.royalPurple,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: DhemiColors.gray200,
                    child: const Icon(
                      Icons.broken_image,
                      size: 40,
                      color: DhemiColors.gray500,
                    ),
                  ),
                ),
              ),
            ),
            10.h,
            Text(
              product['name'] as String,
              style: DhemiText.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            4.h,
            Text(
              "₦$price",
              style: DhemiText.bodySmall.copyWith(
                color: DhemiColors.royalPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl({
    required int qty,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: qty > 1 ? onDecrement : null,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: qty > 1 ? DhemiColors.gray200 : DhemiColors.gray50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.remove,
              size: 18,
              color: qty > 1 ? DhemiColors.gray800 : DhemiColors.gray400,
            ),
          ),
        ),
        12.w,
        Text('$qty', style: DhemiText.bodyMedium.copyWith(fontSize: 16)),
        12.w,
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DhemiColors.royalPurple,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, size: 18, color: DhemiColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCartSummary(List<QueryDocumentSnapshot> cartItems) {
    final total = cartItems.fold(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final price = _toInt(data['price']);
      final qty = _toInt(data['quantity']) == 0 ? 1 : _toInt(data['quantity']);
      return sum + (price * qty);
    });

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: DhemiColors.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DhemiColors.gray200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Total (${cartItems.length} item${cartItems.length == 1 ? '' : 's'}):",
            style: DhemiText.body.copyWith(
              color: DhemiColors.gray800,
              fontSize: 16,
            ),
          ),
          Text(
            "₦$total",
            style: DhemiText.bodyLarge.copyWith(
              color: DhemiColors.royalPurple,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
