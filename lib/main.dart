import 'package:bluetooth/Bluetooth/bluetooth_page.dart';
import 'package:flutter/material.dart';

// Main entry point
void main() {
  runApp(const MyApp());
}

// Root app widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth',
      home: const MainScreen(), // Replaced MyHomePage with MainScreen
    );
  }
}
