// alert_banner.dart
import 'package:flutter/material.dart';

class AlertBanner extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;

  const AlertBanner({
    Key? key,
    required this.message,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: backgroundColor,
      child: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class SussessBanner extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;

  const SussessBanner({
    Key? key,
    required this.message,
    this.backgroundColor = Colors.green,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: backgroundColor,
      child: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}
