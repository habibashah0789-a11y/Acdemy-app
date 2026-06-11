import 'package:flutter/material.dart';

class AcademyProfileScreen extends StatefulWidget {
  const AcademyProfileScreen({super.key});

  @override
  State<AcademyProfileScreen> createState() =>
      _AcademyProfileScreenState();
}

class _AcademyProfileScreenState
    extends State<AcademyProfileScreen> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QUAID Academy "),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Academy Name",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: "Address",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Phone",
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profile Saved"),
                  ),
                );
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}