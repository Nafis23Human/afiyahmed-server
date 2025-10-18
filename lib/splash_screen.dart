import 'dart:async'; // Import async for Timer functionality
import 'package:flutter/material.dart'; // Import Material Design widgets
import 'home_page.dart'; // Import home page widget

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState(); // Create state for splash screen
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // Call parent initState
    super.initState();
    // Schedule navigation to home page after 3 seconds
    Timer(Duration(seconds: 3), () {
      // Replace splash screen with home page (prevents back navigation)
      Navigator.pushReplacement(
        context,
        // Create route to home page
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Return scaffold with splash screen UI
    return Scaffold(
      // Green background color
      backgroundColor: Colors.green.shade600,
      // Center content on screen
      body: Center(
        // Column for vertical layout
        child: Column(
          // Center items vertically
          mainAxisSize: MainAxisSize.min,
          children: [
            // Healing icon at top
            Icon(Icons.healing, size: 80, color: Colors.white),
            // Add spacing below icon
            SizedBox(height: 20),
            // App name text
            Text(
              "🌿 AfiyahMed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            // Add spacing below text
            SizedBox(height: 10),
            // Loading spinner
            CircularProgressIndicator(
              // White color for spinner
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
