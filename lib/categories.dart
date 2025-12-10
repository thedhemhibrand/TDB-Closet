// lib/category_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tdb_closet/product_details.dart';
import 'utils.dart';

class CategoryPage extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;

  const CategoryPage({super.key, this.categoryId, this.categoryName});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _categoryTitle;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (widget.categoryId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch products by categoryId
      final snapshot = await _firestore
          .collection('products')
          .where('categoryId', isEqualTo: widget.categoryId)
          .get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Get category name from the first product (if available)
      if (products.isNotEmpty && _categoryTitle == null) {
        _categoryTitle = products[0]['categoryName'] as String?;
      }

      // Sort by createdAt if available
      products.sort((a, b) {
        final aCreated = a['createdAt'] as Timestamp?;
        final bCreated = b['createdAt'] as Timestamp?;
        if (aCreated == null && bCreated == null) return 0;
        if (aCreated == null) return 1;
        if (bCreated == null) return -1;
        return bCreated.compareTo(aCreated); // descending
      });

      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use categoryName from widget if provided, otherwise use fetched title
    final displayTitle = widget.categoryName ?? _categoryTitle ?? "Category";

    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        backgroundColor: DhemiColors.royalPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          displayTitle,
          style: DhemiText.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: DhemiColors.royalPurple),
            )
          : _products.isEmpty
          ? _buildEmptyState()
          : _buildProductGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: DhemiColors.gray400,
            ),
            16.h,
            Text(
              "No products in this category yet",
              style: DhemiText.bodyMedium.copyWith(color: DhemiColors.gray600),
              textAlign: TextAlign.center,
            ),
            8.h,
            Text(
              "Check back soon for new items!",
              style: DhemiText.bodySmall.copyWith(color: DhemiColors.gray500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          return _buildProductCard(_products[index]);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final images = product['images'] as List?;
    final imageUrl = (images?.isNotEmpty ?? false) ? images![0] as String : "";
    final price = product['price'];
    final priceStr = price is num ? "₦${price.toStringAsFixed(0)}" : "₦0";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: DhemiColors.gray50,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: DhemiColors.gray200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
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
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: DhemiColors.gray100,
                            child: const Icon(
                              Icons.broken_image,
                              color: DhemiColors.gray400,
                              size: 40,
                            ),
                          );
                        },
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

            10.h,

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                product['name'] as String? ?? 'Product',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DhemiText.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DhemiColors.black,
                ),
              ),
            ),

            6.h,

            // Price
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                priceStr,
                style: DhemiText.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DhemiColors.royalPurple,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
