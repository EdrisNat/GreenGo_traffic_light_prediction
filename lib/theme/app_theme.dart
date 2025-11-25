import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    primarySwatch: Colors.green,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Colors.black,
    ),
  );

  static final darkTheme = ThemeData(
    primarySwatch: Colors.lightGreen,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.grey[900],
  );
}