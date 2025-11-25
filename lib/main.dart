import 'package:flutter/material.dart';
import 'package:greengo_mobile/pages/home_page.dart';
import 'package:greengo_mobile/theme/app_theme.dart';

void main() {
  runApp(const GreenGoApp());
}

class GreenGoApp extends StatelessWidget {
  const GreenGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenGo Mobile',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}