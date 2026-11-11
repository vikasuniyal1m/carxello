import 'package:flutter/material.dart';

class MyBidsAndOffersScreen extends StatelessWidget {
  const MyBidsAndOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bids & Offers'),
      ),
      body: const Center(
        child: Text('My Bids & Offers Content'),
      ),
    );
  }
}