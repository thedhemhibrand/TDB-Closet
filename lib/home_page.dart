import 'package:flutter/material.dart';
import 'package:tdb_closet/utils.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        backgroundColor: DhemiColors.royalPurple,
        title: Text(
          'TDB Closets',
          style: DhemiText.subtitle.copyWith(color: DhemiColors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to Your Closet!',
              style: DhemiText.headlineMedium,
              textAlign: TextAlign.center,
            ),
            16.h,
            Text(
              'Start browsing your favorite wears.',
              style: DhemiText.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
