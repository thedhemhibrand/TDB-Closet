// lib/search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tdb_closet/product_details.dart';
import 'package:tdb_closet/utils.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _recentSearches = [
    'Corporate Shirt',
    'Men\'s Trouser',
    'Women\'s Blazer',
    'Office Skirt',
  ];
  final List<String> _popularSearches = [
    'Corporate Wear',
    'Business Attire',
    'Formal Dress',
    'Office Pants',
    'Professional Outfit',
  ];

  late final StreamController<SearchState> _resultsController;
  Timer? _debounce;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _resultsController = StreamController<SearchState>.broadcast();
    _searchController.addListener(_onSearchInputChanged);
    _resultsController.add(SearchState.empty());
  }

  void _onSearchInputChanged() {
    final text = _searchController.text;
    final isEmpty = text.trim().isEmpty;

    if (isEmpty && !_fadeController.isDismissed) {
      _fadeController.reverse();
    } else if (!isEmpty && !_fadeController.isCompleted) {
      _fadeController.forward();
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(text.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    _resultsController.add(SearchState.loading());

    if (query.isEmpty) {
      _resultsController.add(SearchState.empty());
      return;
    }

    try {
      final tokens = query
          .toLowerCase()
          .split(RegExp(r'[\s\-_]+'))
          .where((t) => t.length > 1)
          .toList();

      if (tokens.isEmpty) {
        _resultsController.add(SearchState.empty());
        return;
      }

      // Use first token for Firestore array-contains (only 1 allowed per query)
      final primaryToken = tokens.first;

      final searchIndexSnapshot = await _firestore
          .collection('search_index')
          .where('searchTokens', arrayContains: primaryToken)
          .limit(40) // over-fetch to allow ranking
          .get();

      final List<RankedProduct> rankedProducts = [];
      final Set<String> seenProductIds = {};

      for (final indexDoc in searchIndexSnapshot.docs) {
        final indexData = indexDoc.data();
        final productId = indexData['productId'] as String?;
        if (productId == null || !seenProductIds.add(productId)) continue;

        // Fetch full product data
        final productDoc = await _firestore.collection('products').doc(productId).get();
        if (!productDoc.exists) continue;

        final productData = productDataFromSnapshot(productDoc);
        final storedTokens = (indexData['searchTokens'] as List<dynamic>?)
            ?.map((e) => (e as String).toLowerCase())
            .toSet() ?? {};

        // Score: +1 per matching token
        int score = tokens.where((t) => storedTokens.contains(t)).length;
        // Bonus for exact name match
        if (productData['name'].toLowerCase() == query.toLowerCase()) {
          score += 10;
        }
        // Popularity bonus (if exists)
        final popularity = indexData['popularity'] as num? ?? 0;
        score += (popularity ~/ 10).clamp(0, 5);

        rankedProducts.add(RankedProduct(data: productData, score: score));
      }

      // Sort by score (desc)
      rankedProducts.sort((a, b) => b.score.compareTo(a.score));
      final topResults = rankedProducts.take(15).map((r) => r.data).toList();

      _resultsController.add(SearchState.results(topResults));
    } catch (e) {
      _resultsController.add(SearchState.error(e.toString()));
    }
  }

  Map<String, dynamic> productDataFromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return {
        'id': doc.id,
        'name': 'Untitled',
        'price': 0.0,
        'image': null,
        'categoryId': '',
        'categoryName': '',
      };
    }
    return {
      'id': doc.id,
      'name': data['name'] ?? 'Untitled',
      'price': data['price'] ?? 0.0,
      'image': (data['images'] as List?)?.isNotEmpty == true
          ? (data['images'][0] as String?)
          : null,
      'categoryId': data['categoryId'] ?? '',
      'categoryName': data['categoryName'] ?? '',
    };
  }

  void _onChipTap(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchInputChanged)
      ..dispose();
    _fadeController.dispose();
    _resultsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: _buildAppBar(),
      body: StreamBuilder<SearchState>(
        stream: _resultsController.stream,
        initialData: SearchState.empty(),
        builder: (context, snapshot) {
          final state = snapshot.data!;
          final isQueryEmpty = _searchController.text.trim().isEmpty;

          if (isQueryEmpty) return _buildHomeView();
          if (state.isLoading) return _buildLoading();
          if (state.hasError) return _buildError(state.error!);
          return _buildResults(state.results);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72.0),
      child: SafeArea(
        child: Container(
          color: DhemiColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: DhemiColors.gray50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DhemiColors.gray200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: DhemiColors.gray600,
                    size: 20,
                  ),
                  12.w,
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        _searchController.text = value.trim();
                      },
                      decoration: InputDecoration(
                        hintText: "Search for shirts, trousers, blazers...",
                        hintStyle: DhemiText.body.copyWith(
                          color: DhemiColors.gray500,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: DhemiText.bodyMedium.copyWith(
                        color: DhemiColors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  8.w,
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DhemiColors.gray100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: DhemiColors.gray600,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.mic, size: 20, color: DhemiColors.gray400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recent Searches",
                  style: DhemiText.bodyLarge.copyWith(
                    color: DhemiColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                12.h,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentSearches.map(_buildSearchChip).toList(),
                ),
                24.h,
                Text(
                  "Popular Searches",
                  style: DhemiText.bodyLarge.copyWith(
                    color: DhemiColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                12.h,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _popularSearches.map(_buildSearchChip).toList(),
                ),
                32.h,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchChip(String text) {
    return GestureDetector(
      onTap: () => _onChipTap(text),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: DhemiColors.gray100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: DhemiText.bodySmall.copyWith(
            color: DhemiColors.gray700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator.adaptive(
        valueColor: AlwaysStoppedAnimation<Color>(DhemiColors.royalPurple),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: DhemiColors.gray400),
          16.h,
          Text(
            "Oops! Search failed",
            style: DhemiText.bodyMedium.copyWith(
              color: DhemiColors.gray700,
              fontWeight: FontWeight.w600,
            ),
          ),
          8.h,
          Text(
            "Please try again",
            textAlign: TextAlign.center,
            style: DhemiText.bodySmall.copyWith(color: DhemiColors.gray500),
          ),
          24.h,
          ElevatedButton.icon(
            onPressed: () => _performSearch(_searchController.text.trim()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: DhemiColors.royalPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: DhemiColors.gray50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: DhemiColors.gray400,
              ),
            ),
            20.h,
            Text(
              "No matches found",
              style: DhemiText.headlineSmall.copyWith(
                color: DhemiColors.gray800,
                fontWeight: FontWeight.w600,
              ),
            ),
            10.h,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Try different words or check spelling",
                textAlign: TextAlign.center,
                style: DhemiText.bodyMedium.copyWith(
                  color: DhemiColors.gray600,
                ),
              ),
            ),
            24.h,
            ElevatedButton(
              onPressed: () => _searchController.clear(),
              style: ElevatedButton.styleFrom(
                backgroundColor: DhemiColors.white,
                foregroundColor: DhemiColors.royalPurple,
                side: BorderSide(color: DhemiColors.royalPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("Clear Search"),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final data = results[index];
          return _buildProductTile(data);
        },
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(product: data),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: DhemiColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DhemiColors.gray100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: data['image'] != null
                        ? Image.network(
                            data['image'] as String,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: DhemiColors.gray100,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 32,
                                    color: DhemiColors.gray400,
                                  ),
                                ),
                          )
                        : Container(
                            color: DhemiColors.gray100,
                            child: const Icon(
                              Icons.image,
                              size: 32,
                              color: DhemiColors.gray400,
                            ),
                          ),
                  ),
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] as String,
                        style: DhemiText.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DhemiColors.black,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      4.h,
                      if ((data['categoryName'] as String?)?.isNotEmpty == true)
                        Text(
                          data['categoryName'] as String,
                          style: DhemiText.bodySmall.copyWith(
                            color: DhemiColors.gray600,
                          ),
                          maxLines: 1,
                        ),
                      4.h,
                      Text(
                        "₦${(data['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                        style: DhemiText.bodyMedium.copyWith(
                          color: DhemiColors.royalPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 16),
                  child: Icon(
                    Icons.chevron_right,
                    color: DhemiColors.gray400,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Supporting Classes ---
class SearchState {
  final bool isLoading;
  final List<Map<String, dynamic>> results;
  final String? error;

  SearchState._({this.isLoading = false, this.results = const [], this.error});

  factory SearchState.empty() => SearchState._();
  factory SearchState.loading() => SearchState._(isLoading: true);
  factory SearchState.results(List<Map<String, dynamic>> results) =>
      SearchState._(results: results);
  factory SearchState.error(String error) => SearchState._(error: error);

  bool get hasError => error != null;
}

class RankedProduct {
  final Map<String, dynamic> data;
  final int score;

  RankedProduct({required this.data, required this.score});
}