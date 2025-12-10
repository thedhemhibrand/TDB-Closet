// lib/screens/product_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tdb_closet/product_details.dart';
import 'package:tdb_closet/utils.dart';

class ProductListPage extends StatefulWidget {
  final String title;
  final String? collectionId;
  final List<String>? productIds;

  // Accept products directly (as in your constructor usage)
  final List<dynamic> products;

  const ProductListPage({
    super.key,
    required this.title,
    this.collectionId,
    this.productIds,
    required this.products, // Now properly used
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use passed-in products if available (e.g., from HomePage)
    if (widget.products.isNotEmpty) {
      _products = widget.products;
      _isLoading = false;
    } else {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    try {
      List<dynamic> products = [];

      if (widget.productIds != null && widget.productIds!.isNotEmpty) {
        final chunks = _chunkList(widget.productIds!, 10);
        for (var chunk in chunks) {
          final snapshot = await _firestore
              .collection('products')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          products.addAll(snapshot.docs.map((doc) => doc.data()).toList());
        }
      } else if (widget.collectionId != null) {
        final doc = await _firestore
            .collection('collections')
            .doc(widget.collectionId)
            .get();
        if (doc.exists && doc.data()?['productIds'] is List) {
          final ids = doc.data()!['productIds'] as List<dynamic>;
          final idStrings = ids.whereType<String>().toList();
          if (idStrings.isNotEmpty) {
            final chunks = _chunkList(idStrings, 10);
            for (var chunk in chunks) {
              final snapshot = await _firestore
                  .collection('products')
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
              products.addAll(snapshot.docs.map((doc) => doc.data()).toList());
            }
          }
        }
      } else {
        final snapshot = await _firestore.collection('products').get();
        products = snapshot.docs.map((doc) => doc.data()).toList();
      }

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

  List<List<String>> _chunkList(List<String> list, int chunkSize) {
    final chunks = <List<String>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        title: Text(widget.title, style: DhemiText.bodyLarge),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: DhemiColors.royalPurple),
            )
          : _products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 60,
                    color: DhemiColors.gray500,
                  ),
                  20.h,
                  Text(
                    "No products found",
                    style: DhemiText.bodyMedium.copyWith(
                      color: DhemiColors.gray600,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return _productCard(product);
                },
              ),
            ),
    );
  }

  // ✅ Exact replica of HomePage's _productCard (adjusted for grid)
  Widget _productCard(Map<String, dynamic> product) {
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
      child: SizedBox(
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
            8.h, // Match HomePage
            Text(
              product['name'] as String? ?? 'Product',
              style: DhemiText.bodySmall.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1, // ✅ Prevent overflow
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
      ),
    );
  }
}
