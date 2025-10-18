import 'package:flutter/material.dart'; // Import Material Design widgets
import 'splash_screen.dart'; // Import splash screen widget

void main() => runApp(AfiyahMedApp()); // Run the app

class AfiyahMedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Return MaterialApp for app configuration
    return MaterialApp(
      // Hide debug banner in top right corner
      debugShowCheckedModeBanner: false,
      // App title shown in task switcher
      title: "AfiyahMed",
      // Define app theme
      theme: ThemeData(
        // Set default font family
        fontFamily: 'Poppins',
        // Create color scheme from green seed color
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade600),
        // Use Material Design 3
        useMaterial3: true,
      ),
      // Set splash screen as home page
      home: SplashScreen(),
    );
  }
}
