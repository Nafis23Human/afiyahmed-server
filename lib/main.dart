import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() => runApp(AfiyahMedApp());

class AfiyahMedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AfiyahMed",
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade600),
        useMaterial3: true,
      ),
      home: SplashScreen(), // Start with SplashScreen
    );
  }
}
