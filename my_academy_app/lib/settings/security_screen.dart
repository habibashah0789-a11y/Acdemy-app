import 'package:flutter/material.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() =>
      _SecurityScreenState();
}

class _SecurityScreenState
    extends State<SecurityScreen> {
  bool biometric = false;
  bool lockApp = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Security"),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("App Lock"),
            value: lockApp,
            onChanged: (value) {
              setState(() {
                lockApp = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text("Fingerprint Login"),
            value: biometric,
            onChanged: (value) {
              setState(() {
                biometric = value;
              });
            },
          ),
        ],
      ),
    );
  }
}