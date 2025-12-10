// lib/screens/product_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tdb_closet/utils.dart';

class ProductDetailsPage extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? product;

  const ProductDetailsPage({super.key, this.productId, this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _product;
  List<dynamic> _recommendedProducts = [];
  String? _selectedSize;
  int _quantity = 1;
  bool _isLoading = true;
  bool _isAddingToCart = false;
  bool _isInWishlist = false;
  bool _isTogglingWishlist = false;
  int _currentPage = 0;
  String? _actualProductId;

  @override
  void initState() {
    super.initState();
    _loadProductAndRecommendations();
    _checkIfInWishlist();
  }

  Future<void> _loadProductAndRecommendations() async {
    try {
      if (widget.product != null) {
        _product = widget.product;
        // Try to get productId from the product data
        _actualProductId =
            widget.product!['productId'] as String? ??
            widget.product!['id'] as String? ??
            widget.productId;
      } else if (widget.productId != null) {
        final doc = await _firestore
            .collection('products')
            .doc(widget.productId)
            .get();
        if (doc.exists) {
          _product = doc.data()!;
          _actualProductId = doc.id;
        }
      }

      if (_product != null) {
        final mainCategory =
            _product!['mainCategory'] as String? ?? 'TDB CLASSICS';
        final snapshot = await _firestore
            .collection('products')
            .where('mainCategory', isEqualTo: mainCategory)
            .limit(10)
            .get();

        final candidates = snapshot.docs
            .map((doc) => doc.data())
            .where(
              (p) => (p['name'] as String?) != (_product!['name'] as String?),
            )
            .toList();

        final shuffled = List<Map<String, dynamic>>.from(candidates)..shuffle();
        _recommendedProducts = shuffled.take(4).toList();
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfInWishlist() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Determine the product ID to use
    String? checkProductId = _actualProductId ?? widget.productId;

    if (checkProductId == null && widget.product != null) {
      checkProductId =
          widget.product!['productId'] as String? ??
          widget.product!['id'] as String? ??
          widget.product!['name'] as String?;
    }

    if (checkProductId == null) return;

    try {
      final wishlistDoc = await _firestore
          .collection('wishlist')
          .doc(user.uid)
          .collection('items')
          .doc(checkProductId)
          .get();

      if (mounted) {
        setState(() => _isInWishlist = wishlistDoc.exists);
      }
    } catch (e) {
      debugPrint('Wishlist check error: $e');
    }
  }

  Future<void> _toggleWishlist() async {
    final user = _auth.currentUser;

    if (user == null) {
      // Prompt to log in
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in to use wishlist'),
            backgroundColor: DhemiColors.gray800,
            action: SnackBarAction(
              label: 'Login',
              textColor: DhemiColors.white,
              onPressed: () {
                // Navigate to login – adjust route as needed
                Navigator.pushNamed(context, '/login');
              },
            ),
          ),
        );
      }
      return;
    }

    if (_product == null) return;

    // Determine the product ID to use
    String? useProductId = _actualProductId ?? widget.productId;

    if (useProductId == null && widget.product != null) {
      useProductId =
          widget.product!['productId'] as String? ??
          widget.product!['id'] as String? ??
          widget.product!['name'] as String?;
    }

    if (useProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add to wishlist: Product ID not found'),
          backgroundColor: DhemiColors.gray800,
        ),
      );
      return;
    }

    if (_isTogglingWishlist) return;
    setState(() => _isTogglingWishlist = true);

    try {
      final wishlistRef = _firestore
          .collection('wishlist')
          .doc(user.uid)
          .collection('items')
          .doc(useProductId);

      if (_isInWishlist) {
        // Remove from wishlist
        await wishlistRef.delete();
        if (mounted) {
          setState(() => _isInWishlist = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_product!['name']} removed from wishlist'),
              backgroundColor: DhemiColors.gray700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Add to wishlist
        final wishlistItem = <String, dynamic>{
          'productId': useProductId,
          'name': _product!['name'],
          'price': _product!['price'],
          'image': (_product!['images'] as List?)?.isNotEmpty == true
              ? _product!['images'][0]
              : null,
          'mainCategory': _product!['mainCategory'],
          'stock': _product!['stock'] ?? 0,
          'addedAt': FieldValue.serverTimestamp(),
        };

        await wishlistRef.set(wishlistItem, SetOptions(merge: true));

        if (mounted) {
          setState(() => _isInWishlist = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_product!['name']} added to wishlist!'),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Wishlist toggle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update wishlist'),
            backgroundColor: DhemiColors.gray800,
          ),
        );
        // Revert UI state on error
        setState(() => _isInWishlist = !_isInWishlist);
      }
    } finally {
      if (mounted) setState(() => _isTogglingWishlist = false);
    }
  }

  Future<void> _addToCart() async {
    final stock = (_product?['stock'] as int?) ?? 999;
    if (_quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $stock available in stock!'),
          backgroundColor: DhemiColors.gray800,
        ),
      );
      return;
    }

    if ((_product?['sizes'] as List?)?.isNotEmpty == true &&
        _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size'),
          backgroundColor: DhemiColors.gray800,
        ),
      );
      return;
    }

    setState(() => _isAddingToCart = true);

    try {
      final user = _auth.currentUser;

      // Determine the product ID to use
      String? useProductId = _actualProductId ?? widget.productId;

      if (useProductId == null && widget.product != null) {
        useProductId =
            widget.product!['productId'] as String? ??
            widget.product!['id'] as String? ??
            _product!['name'] as String;
      }

      final cartItem = <String, dynamic>{
        'userId': user?.uid,
        'productId': useProductId ?? _product!['name'],
        'name': _product!['name'],
        'price': _product!['price'],
        'quantity': _quantity,
        'size': _selectedSize,
        'image': (_product!['images'] as List?)?.isNotEmpty == true
            ? _product!['images'][0]
            : null,
        'addedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('cart').add(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_product!['name']} added to cart!'),
            backgroundColor: DhemiColors.royalPurple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Cart error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add to cart'),
            backgroundColor: DhemiColors.gray800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildScaffold(
        child: const Center(
          child: CircularProgressIndicator(color: DhemiColors.royalPurple),
        ),
      );
    }

    if (_product == null) {
      return _buildScaffold(
        appBar: AppBar(
          backgroundColor: DhemiColors.white,
          foregroundColor: DhemiColors.royalPurple,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: DhemiColors.gray500,
              ),
              16.h,
              Text('Product not found', style: DhemiText.bodyMedium),
            ],
          ),
        ),
      );
    }

    final images = List<String>.from(
      _product!['images'] ??
          ['https://via.placeholder.com/600x600?text=No+Image'],
    );
    final stock = (_product?['stock'] as int?) ?? 999;

    return _buildScaffold(
      appBar: AppBar(
        backgroundColor: DhemiColors.white,
        foregroundColor: DhemiColors.royalPurple,
        elevation: 0,
        title: Text(
          _product!['name'],
          style: DhemiText.bodyLarge.copyWith(fontSize: 18),
        ),
        actions: [
          // Wishlist button with green color when active
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                _isInWishlist ? Icons.favorite : Icons.favorite_border,
                key: ValueKey<bool>(_isInWishlist),
                color: _isInWishlist
                    ? Colors.green.shade600
                    : DhemiColors.royalPurple,
                size: 26,
              ),
            ),
            onPressed: _isTogglingWishlist ? null : _toggleWishlist,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: DhemiColors.royalPurple),
            onPressed: () {
              // Add share functionality here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share functionality coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE CAROUSEL WITH TAP-TO-ZOOM
            Stack(
              children: [
                SizedBox(
                  height: 320,
                  child: PageView.builder(
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showZoomedImage(context, images[index]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Hero(
                              tag:
                                  'product-image-${_actualProductId ?? widget.productId ?? _product!['name']}-$index',
                              child: _buildNetworkImage(images[index]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: DhemiWidgets.dotIndicator(
                      images.length,
                      _currentPage,
                    ),
                  ),
                ),
              ],
            ),
            20.h,

            // PRODUCT INFO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _product!['name'],
                    style: DhemiText.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  8.h,

                  Row(
                    children: [
                      Text(
                        "₦${_product!['price']}",
                        style: DhemiText.bodyLarge.copyWith(
                          color: DhemiColors.royalPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      if (_product!['comparePrice'] != null) ...[
                        8.w,
                        Text(
                          "₦${_product!['comparePrice']}",
                          style: DhemiText.bodySmall.copyWith(
                            color: DhemiColors.gray500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      8.w,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stock > 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: stock > 0
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          '$stock in stock',
                          style: DhemiText.bodySmall.copyWith(
                            color: stock > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  20.h,

                  Text(
                    'Description',
                    style: DhemiText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  6.h,
                  Text(
                    (_product!['description'] ?? 'No description available.')
                        as String,
                    style: DhemiText.body,
                    textAlign: TextAlign.justify,
                  ),
                  24.h,

                  // Size
                  if ((_product!['sizes'] as List?)?.isNotEmpty == true) ...[
                    Text(
                      'Size',
                      style: DhemiText.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    12.h,
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: (_product!['sizes'] as List<dynamic>).map((
                        size,
                      ) {
                        final isSelected = _selectedSize == size;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSize = size),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DhemiColors.royalPurple
                                  : DhemiColors.gray100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? DhemiColors.royalPurple
                                    : DhemiColors.gray300,
                              ),
                            ),
                            child: Text(
                              size as String,
                              style: DhemiText.bodySmall.copyWith(
                                color: isSelected
                                    ? DhemiColors.white
                                    : DhemiColors.gray700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    24.h,
                  ],

                  // Quantity
                  Text(
                    'Quantity',
                    style: DhemiText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  12.h,
                  DhemiWidgets.quantityStepper(
                    value: _quantity,
                    max: stock,
                    onIncrement: () => setState(() => _quantity++),
                    onDecrement: () => setState(() => _quantity--),
                  ),
                  32.h,

                  // Add to Cart
                  DhemiWidgets.button(
                    label: _isAddingToCart ? 'Adding...' : 'Add to Cart',
                    onPressed: _isAddingToCart ? () {} : _addToCart,
                    fontSize: 16,
                    horizontalPadding: 32,
                    verticalPadding: 16,
                    minHeight: 52,
                  ),
                  32.h,

                  // Tags
                  if ((_product!['tags'] as List?)?.isNotEmpty == true) ...[
                    Text(
                      'Tags',
                      style: DhemiText.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    8.h,
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: (_product!['tags'] as List<dynamic>).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: DhemiColors.gray200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag as String,
                            style: DhemiText.bodySmall.copyWith(
                              color: DhemiColors.gray700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    24.h,
                  ],
                ],
              ),
            ),

            // RECOMMENDED PRODUCTS
            if (_recommendedProducts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'You May Also Like',
                  style: DhemiText.bodyLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              16.h,
              SizedBox(
                height: 250,
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendedProducts.length,
                  itemBuilder: (context, index) {
                    final prod = _recommendedProducts[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 165,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsPage(product: prod),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AspectRatio(
                                  aspectRatio: 0.85,
                                  child: _buildNetworkImage(
                                    (prod['images'] as List?)?.isNotEmpty ==
                                            true
                                        ? prod['images'][0]
                                        : 'https://via.placeholder.com/150',
                                  ),
                                ),
                              ),
                              8.h,
                              Text(
                                prod['name'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DhemiText.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              4.h,
                              Text(
                                '₦${prod['price']}',
                                style: DhemiText.bodySmall.copyWith(
                                  color: DhemiColors.royalPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              40.h,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold({required Widget child, AppBar? appBar}) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar:
          appBar ??
          AppBar(
            backgroundColor: DhemiColors.white,
            foregroundColor: DhemiColors.royalPurple,
            elevation: 0,
          ),
      body: child,
    );
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url.trim(),
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(color: DhemiColors.royalPurple),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: DhemiColors.gray100,
        child: const Icon(
          Icons.broken_image,
          size: 60,
          color: DhemiColors.gray400,
        ),
      ),
    );
  }

  void _showZoomedImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 3.0,
          child: Hero(
            tag: 'zoom-$imageUrl',
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
