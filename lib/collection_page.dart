// lib/screens/collection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tdb_closet/utils.dart';
import 'product_list_page.dart';

class CollectionPage extends StatelessWidget {
  final String collectionId;

  const CollectionPage({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        backgroundColor: DhemiColors.royalPurple,
        title: Text(
          _getCollectionTitle(collectionId),
          style: DhemiText.bodyLarge,
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('collections')
            .doc(collectionId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: DhemiColors.royalPurple),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.collections_bookmark_outlined,
                    size: 60,
                    color: DhemiColors.gray500,
                  ),
                  20.h,
                  Text(
                    "Collection not found",
                    style: DhemiText.bodyMedium.copyWith(
                      color: DhemiColors.gray600,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final title =
              data?['title'] as String? ?? _getCollectionTitle(collectionId);
          final productIds =
              (data?['productIds'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [];

          return ProductListPage(
            title: title,
            productIds: productIds,
            products: [],
          );
        },
      ),
    );
  }

  String _getCollectionTitle(String id) {
    switch (id) {
      case 'new-arrivals':
        return "New Arrivals";
      case 'best-sellers':
        return "Best Sellers";
      default:
        return id.split('-').map((word) => word.capitalize()).join(' ');
    }
  }
}

extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
