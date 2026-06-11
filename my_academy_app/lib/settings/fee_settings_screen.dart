import 'package:flutter/material.dart';

class FeeSettingsScreen extends StatelessWidget {
  const FeeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fee Settings"),
      ),
      body: const Center(
        child: Text("Manage Fee Structure Here"),
      ),
    );
  }
}