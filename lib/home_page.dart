// lib/home_page.dart
import 'package:bottom_bar/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tdb_closet/cart_page.dart';
import 'package:tdb_closet/categories.dart';
import 'package:tdb_closet/collection_page.dart';
import 'package:tdb_closet/product_details.dart';
import 'package:tdb_closet/product_list_page.dart';
import 'package:tdb_closet/profile_page.dart';
import 'package:tdb_closet/search_page.dart';
import 'package:tdb_closet/shop_page.dart';
import 'package:tdb_closet/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  String _greetingName = "User";
  final int _notificationCount = 0;
  List<dynamic> _promoBanners = [];
  List<dynamic> _categories = [];
  List<dynamic> _newArrivals = [];
  List<dynamic> _bestSellers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      await _fetchUserData();
      await _fetchNewArrivals();
      await _fetchBestSellers();
      await _fetchCategories(); // Must come AFTER products are loaded
      await _fetchPromoBanners();
    } catch (e) {
      debugPrint('Error fetching home data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()?['firstName'] != null) {
          if (mounted) {
            setState(() {
              _greetingName = userDoc.data()!['firstName'] as String;
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
    }
  }

  Future<void> _fetchPromoBanners() async {
    try {
      final snapshot = await _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      final banners = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) setState(() => _promoBanners = banners);
    } catch (e) {
      debugPrint('Error fetching promo banners: $e');
      try {
        final snapshot = await _firestore
            .collection('promotions')
            .where('isActive', isEqualTo: true)
            .get();
        final banners = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        banners.sort((a, b) {
          final orderA = a['order'] as int? ?? 999;
          final orderB = b['order'] as int? ?? 999;
          return orderA.compareTo(orderB);
        });
        if (mounted) setState(() => _promoBanners = banners);
      } catch (e2) {
        debugPrint('Error fetching promotions (fallback): $e2');
      }
    }
  }

  // 🔁 Derive categories from products with case-insensitive deduplication
  Future<void> _fetchCategories() async {
    final Map<String, Map<String, dynamic>> categoryMap = {};
    final allProducts = [..._newArrivals, ..._bestSellers];

    for (final product in allProducts) {
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
      setState(() => _categories = categoryMap.values.toList());
    }
  }

  Future<void> _fetchNewArrivals() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isNew', isEqualTo: true)
          .limit(10)
          .get();
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) setState(() => _newArrivals = products);
    } catch (e) {
      debugPrint('Error fetching new arrivals: $e');
    }
  }

  Future<void> _fetchBestSellers() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isBestSeller', isEqualTo: true)
          .limit(10)
          .get();
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) setState(() => _bestSellers = products);
    } catch (e) {
      debugPrint('Error fetching best sellers: $e');
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

  void _handlePromoTap(Map<String, dynamic> promo) {
    final linkType = promo['linkType'] as String?;
    final linkId = promo['linkId'] as String?;
    if (linkType == null || linkId == null) return;

    if (linkType == 'product') {
      _firestore
          .collection('products')
          .doc(linkId)
          .get()
          .then((doc) {
            if (doc.exists && mounted) {
              final productData = doc.data()!;
              productData['id'] = doc.id;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProductDetailsPage(product: productData),
                ),
              );
            } else {
              _showError('Product not found');
            }
          })
          .catchError((e) {
            debugPrint('Error fetching product: $e');
            _showError('Failed to load product');
          });
    } else if (linkType == 'category') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryPage(categoryId: linkId),
        ),
      );
    } else if (linkType == 'collection') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionPage(collectionId: linkId),
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: DhemiColors.gray800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showComingSoon() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notifications coming soon!',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: DhemiColors.royalPurple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: DhemiColors.royalPurple),
            )
          : PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildHomePage(),
                const ShopPage(),
                const SearchPage(),
                const CartPage(),
                const ProfilePage(),
              ],
            ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _currentPage,
        onTap: (index) {
          _pageController.jumpToPage(index);
          setState(() => _currentPage = index);
        },
        items: [
          BottomBarItem(
            icon: const Icon(Icons.home),
            title: const Text('Home'),
            activeColor: DhemiColors.royalPurple,
          ),
          BottomBarItem(
            icon: const Icon(Icons.category),
            title: const Text('Shop'),
            activeColor: DhemiColors.royalPurple,
          ),
          BottomBarItem(
            icon: const Icon(Icons.search),
            title: const Text('Search'),
            activeColor: DhemiColors.royalPurple,
          ),
          BottomBarItem(
            icon: const Icon(Icons.shopping_cart),
            title: const Text('Cart'),
            activeColor: DhemiColors.royalPurple,
          ),
          BottomBarItem(
            icon: const Icon(Icons.person),
            title: const Text('Profile'),
            activeColor: DhemiColors.royalPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            10.h,
            // ─── TOP BAR ───────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: DhemiColors.royalPurple.withOpacity(0.15),
                  child: const Icon(
                    Icons.person,
                    color: DhemiColors.royalPurple,
                  ),
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, $_greetingName",
                        style: DhemiText.bodyMedium.copyWith(
                          color: DhemiColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "Explore amazing corporate fashion deals",
                        style: DhemiText.tagline.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: DhemiColors.royalPurple,
                      ),
                      onPressed: _showComingSoon,
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            20.h,
            // ─── SEARCH BAR ───────────────────────────────────
            GestureDetector(
              onTap: () {
                _pageController.jumpToPage(2);
                setState(() => _currentPage = 2);
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: DhemiColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: DhemiColors.gray500),
                    10.w,
                    Expanded(
                      child: Text(
                        "Search corporate shirts, trousers...",
                        style: DhemiText.body.copyWith(
                          color: DhemiColors.gray500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.mic_none, color: DhemiColors.gray500),
                  ],
                ),
              ),
            ),
            20.h,
            // ─── PROMO BANNER CAROUSEL ────────────────────────
            SizedBox(
              height: 180,
              child: _promoBanners.isEmpty
                  ? _placeholderCard("No active promotions")
                  : PageView.builder(
                      itemCount: _promoBanners.length,
                      controller: PageController(viewportFraction: 0.92),
                      itemBuilder: (_, i) {
                        final promo = _promoBanners[i];
                        final imageUrl = promo['image'] as String? ?? "";
                        return GestureDetector(
                          onTap: () => _handlePromoTap(promo),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: DhemiColors.gray100,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: DhemiColors.royalPurple,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: DhemiColors.gray500,
                                        size: 48,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      promo['title'] as String? ?? 'Promotion',
                                      style: DhemiText.bodyMedium,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            20.h,
            // ─── CATEGORIES ───────────────────────────────────
            Text("Category", style: DhemiText.bodyLarge.copyWith(fontSize: 20)),
            10.h,
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(
                    "All",
                    selected: true,
                    onTap: () {
                      _pageController.jumpToPage(1);
                      setState(() => _currentPage = 1);
                    },
                  ),
                  for (final cat in _categories)
                    _categoryChip(
                      cat['name'] as String,
                      onTap: () {
                        final categoryId = cat['id'] as String?;
                        if (categoryId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoryPage(categoryId: categoryId),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
            20.h,
            // ─── NEW ARRIVALS ─────────────────────────────────
            if (_newArrivals.isNotEmpty) ...[
              _sectionHeader("New Arrivals", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductListPage(
                      title: "New Arrivals",
                      products: _newArrivals,
                    ),
                  ),
                );
              }),
              12.h,
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newArrivals.length,
                  separatorBuilder: (_, __) => 14.w,
                  itemBuilder: (_, i) => _productCard(_newArrivals[i]),
                ),
              ),
              24.h,
            ],
            // ─── BEST SELLERS ─────────────────────────────────
            if (_bestSellers.isNotEmpty) ...[
              _sectionHeader("Best Sellers", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductListPage(
                      title: "Best Sellers",
                      products: _bestSellers,
                    ),
                  ),
                );
              }),
              12.h,
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _bestSellers.length,
                  separatorBuilder: (_, __) => 14.w,
                  itemBuilder: (_, i) => _productCard(_bestSellers[i]),
                ),
              ),
              24.h,
            ],
            // ─── EMPTY STATE ──────────────────────────────────
            if (_newArrivals.isEmpty && _bestSellers.isEmpty) ...[
              40.h,
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: DhemiColors.gray400,
                    ),
                    16.h,
                    Text(
                      'No products available yet',
                      style: DhemiText.bodyMedium.copyWith(
                        color: DhemiColors.gray600,
                      ),
                    ),
                    8.h,
                    Text(
                      'Check back soon for new arrivals!',
                      style: DhemiText.bodySmall.copyWith(
                        color: DhemiColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              40.h,
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: DhemiText.bodyLarge.copyWith(fontSize: 20)),
        TextButton(
          onPressed: onTap,
          child: Text(
            "See All",
            style: DhemiText.bodySmall.copyWith(
              color: DhemiColors.royalPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(
    String text, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DhemiColors.royalPurple : DhemiColors.gray200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: DhemiText.bodySmall.copyWith(
            color: selected ? DhemiColors.white : DhemiColors.gray700,
          ),
        ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final images = product['images'] as List?;
    final imageUrl = (images?.isNotEmpty ?? false) ? images![0] as String : "";
    final price = product['price'];
    final priceStr = price is num ? "₦${price.toStringAsFixed(0)}" : "₦0";

    return GestureDetector(
      onTap: () => _navigateToProduct(product),
      child: SizedBox(
        width: 150,
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
      ),
    );
  }

  Widget _placeholderCard(String text) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: DhemiColors.gray100,
      ),
      child: Center(
        child: Text(
          text,
          style: DhemiText.bodySmall.copyWith(color: DhemiColors.gray500),
        ),
      ),
    );
  }
}
