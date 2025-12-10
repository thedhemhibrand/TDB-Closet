// lib/screens/shop_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tdb_closet/product_details.dart';
import 'package:tdb_closet/utils.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<dynamic> _allProducts = [];
  List<dynamic> _uniqueCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    try {
      // 1. Fetch all products
      final productSnapshot = await _firestore.collection('products').get();
      final products = productSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // 2. Extract unique categories from products with case-insensitive deduplication
      final Map<String, Map<String, dynamic>> categoryMap = {};

      for (final product in products) {
        final id = product['categoryId'] as String?;
        final name = product['categoryName'] as String?;

        if (id != null && name != null && name.trim().isNotEmpty) {
          // Use lowercase name as key for case-insensitive comparison
          final normalizedKey = name.trim().toLowerCase();

          // Only add if we haven't seen this category name before (case-insensitive)
          if (!categoryMap.containsKey(normalizedKey)) {
            categoryMap[normalizedKey] = {
              'id': id,
              'name': name.trim(), // Keep original casing for display
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _uniqueCategories = categoryMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shop data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        title: Text("Shop", style: DhemiText.bodyLarge),
        backgroundColor: DhemiColors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: DhemiColors.royalPurple),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── SHOP BY CATEGORY ─────────────────────────────────
                    if (_uniqueCategories.isNotEmpty) ...[
                      10.h,
                      Text("Shop by Category", style: DhemiText.header),
                      10.h,
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _uniqueCategories.length,
                          itemBuilder: (context, i) {
                            final cat = _uniqueCategories[i];
                            return GestureDetector(
                              onTap: () {
                                // TODO: Navigate to filtered category page
                                // For now, you could pass categoryId to a ProductListPage
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 16),
                                width: 100,
                                decoration: BoxDecoration(
                                  color: DhemiColors.gray100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: DhemiColors.royalPurple
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.category,
                                        color: DhemiColors.royalPurple,
                                        size: 32,
                                      ),
                                    ),
                                    8.h,
                                    Text(
                                      cat['name'] as String,
                                      style: DhemiText.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      24.h,
                    ],

                    // ─── ALL PRODUCTS ─────────────────────────────────────
                    Text("All Products", style: DhemiText.header),
                    12.h,

                    if (_allProducts.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: DhemiColors.gray500,
                              ),
                              16.h,
                              Text(
                                "No products available yet",
                                style: DhemiText.bodyMedium.copyWith(
                                  color: DhemiColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: _allProducts.length,
                        itemBuilder: (context, index) {
                          return _productCard(_allProducts[index]);
                        },
                      ),

                    30.h,
                  ],
                ),
              ),
            ),
    );
  }

  // ✅ EXACT COPY OF HOMEPAGE'S PRODUCT CARD
  Widget _productCard(Map<String, dynamic> product) {
    final images = product['images'] as List?;
    final imageUrl = (images?.isNotEmpty ?? false) ? images![0] as String : "";
    final price = product['price'];
    final priceStr = price is num ? "₦${price.toStringAsFixed(0)}" : "₦0";

    return GestureDetector(
      onTap: () => _navigateToProduct(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: DhemiColors.gray100,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: DhemiColors.royalPurple,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: DhemiColors.gray100,
                        child: const Icon(
                          Icons.broken_image,
                          color: DhemiColors.gray500,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      color: DhemiColors.gray100,
                      child: const Icon(
                        Icons.image_outlined,
                        color: DhemiColors.gray400,
                        size: 40,
                      ),
                    ),
            ),
          ),
          8.h,
          Text(
            product['name'] as String? ?? 'Product',
            style: DhemiText.bodySmall.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          4.h,
          Text(
            priceStr,
            style: DhemiText.bodySmall.copyWith(
              color: DhemiColors.royalPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
