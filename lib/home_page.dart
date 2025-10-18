import 'dart:async'; // Import async for TimeoutException handling
import 'dart:io'; // Import for File operations
import 'dart:typed_data'; // Import for Uint8List data type
import 'dart:convert'; // Import for base64 encoding/decoding

import 'package:flutter/foundation.dart' show kIsWeb; // Import to check if running on web
import 'package:flutter/material.dart'; // Import Material Design widgets
import 'package:image_picker/image_picker.dart'; // Import for image picking functionality
import 'package:image/image.dart' as img; // Import for image resizing
import 'package:http/http.dart' as http; // Import for HTTP requests

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState(); // Create state for HomePage
}

class _HomePageState extends State<HomePage> {
  // Controller for symptoms text input field
  final TextEditingController _symptomsController = TextEditingController();
  // Store image file for non-web platforms
  File? _imageFile;
  // Store image bytes for web platform
  Uint8List? _imageBytes;
  // Flag to track if API request is in progress
  bool _loading = false;
  // Widget to display prediction results
  Widget? _resultWidget;
  // Image picker instance
  final picker = ImagePicker();

  // Base URL for the backend server
  final String baseUrl = "https://afiyahmed-server.onrender.com";

  Future<void> _pickImage() async {
    // Open image picker to select from gallery
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    // Check if user selected an image
    if (pickedFile != null) {
      // For web platform, read image as bytes
      if (kIsWeb) {
        _imageBytes = await pickedFile.readAsBytes();
      } else {
        // For mobile platforms, store as File object
        _imageFile = File(pickedFile.path);
      }
      // Rebuild widget to display selected image
      setState(() {});
    }
  }

  Future<void> _sendToServer() async {
    // Validate that both image and symptoms are provided
    if ((kIsWeb && _imageBytes == null) ||
        (!kIsWeb && _imageFile == null) ||
        _symptomsController.text.trim().isEmpty) {
      // Show warning message if validation fails
      setState(() => _resultWidget =
          _buildSimpleText("⚠️ Please add an image and describe symptoms."));
      return;
    }

    // Set loading state to true and clear previous results
    setState(() {
      _loading = true;
      _resultWidget = null;
    });

    try {
      // Resize image to reduce file size
      Uint8List imageData;
      // Check if running on web platform
      if (kIsWeb) {
        // Decode image bytes
        final original = img.decodeImage(_imageBytes!);
        // Check if image decoding was successful
        if (original == null) throw Exception("Failed to decode image");
        // Resize image to 400px width
        final resized = img.copyResize(original, width: 400);
        // Encode resized image as JPEG
        imageData = Uint8List.fromList(img.encodeJpg(resized));
      } else {
        // Read image file from mobile storage
        final bytes = await _imageFile!.readAsBytes();
        // Decode image bytes
        final original = img.decodeImage(bytes);
        // Check if image decoding was successful
        if (original == null) throw Exception("Failed to decode image");
        // Resize image to 400px width
        final resized = img.copyResize(original, width: 400);
        // Encode resized image as JPEG
        imageData = Uint8List.fromList(img.encodeJpg(resized));
      }

      // Convert image to base64 string for transmission
      final imageBase64 = base64Encode(imageData);
      // Create URI for the prediction endpoint
      final uri = Uri.parse("$baseUrl/predict_json");

      // Send POST request to server with image and symptoms
      final response = await http
          .post(
            uri,
            // Set content type to JSON
            headers: {"Content-Type": "application/json"},
            // Encode request body as JSON
            body: jsonEncode({
              "symptoms": _symptomsController.text.trim(),
              "image_base64": imageBase64,
            }),
          )
          // Set timeout to 90 seconds
          .timeout(const Duration(seconds: 90));

      // Print server response for debugging
      print("Server Response: ${response.body}");

      // Check if request was successful (status code 200)
      if (response.statusCode == 200) {
        // Decode JSON response from server
        final data = jsonDecode(response.body);

        // Check if prediction data is a Map (structured JSON)
        if (data["prediction"] is Map) {
          // Extract prediction data from response
          final pred = data["prediction"];
          // Extract and format top diseases list
          final topDiseases = (pred["top_3_possible_diseases"] as List?)
                  ?.map((d) => {
                        "name": d["name"].toString(),
                        "confidence": d["confidence_percentage"].toString()
                      })
                  .toList() ??
              [];
          // Extract recommended next steps list
          final steps = (pred["recommended_next_steps"] as List?)
                  ?.map((s) => s.toString())
                  .toList() ??
              [];

          // Update UI with prediction results
          setState(() {
            _resultWidget = _buildRichResult(
              topDiseases: topDiseases,
              explanation: pred["explanation"] ?? "N/A",
              urgency: pred["urgency"] ?? "N/A",
              steps: steps,
              disclaimer: pred["disclaimer"] ?? "N/A",
            );
          });
        } else if (data["prediction"] is String) {
          // If prediction is a string, display it as simple text
          setState(() => _resultWidget = _buildSimpleText(data["prediction"]));
        } else {
          // Handle unexpected response format
          setState(() => _resultWidget =
              _buildSimpleText("Unexpected server response format."));
        }
      } else {
        // Display error message with status code and response body
        setState(() => _resultWidget = _buildSimpleText(
            "❌ Server Error: ${response.statusCode}\n${response.body}"));
      }
    } on TimeoutException {
      // Handle request timeout error
      setState(() =>
          _resultWidget = _buildSimpleText("⏳ Request timed out. Please try again."));
    } on SocketException {
      // Handle network connection error
      setState(() =>
          _resultWidget = _buildSimpleText("🚫 No internet connection."));
    } catch (e) {
      // Handle any other errors
      setState(() => _resultWidget = _buildSimpleText("❌ Network Error: $e"));
    } finally {
      // Set loading state to false after request completes
      setState(() => _loading = false);
    }
  }

  Widget _gradientButton(String text, VoidCallback onPressed) {
    // Create gesture detector for tap handling
    return GestureDetector(
      onTap: onPressed,
      // Container with gradient background
      child: Container(
        // Set vertical padding for button height
        padding: EdgeInsets.symmetric(vertical: 14),
        // Apply gradient and styling
        decoration: BoxDecoration(
          // Create gradient from darker to lighter green
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
          // Round button corners
          borderRadius: BorderRadius.circular(12),
          // Add shadow effect
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        // Center text inside button
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleText(String text) {
    // Return text with styling
    return Text(
      text,
      style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
    );
  }

  Widget _buildRichResult({
    required List<Map<String, String>> topDiseases,
    required String explanation,
    required String urgency,
    required List<String> steps,
    required String disclaimer,
  }) {
    // Return column with all result sections
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display top diseases with progress bars
        _buildDiseaseSection("🩺 Top Possible Diseases", topDiseases),
        // Display explanation section
        _buildSection("💡 Explanation", Colors.orange, [explanation]),
        // Display urgency level
        _buildSection("⚠️ Urgency", Colors.red, [urgency]),
        // Display recommended next steps
        _buildSection("✅ Recommended Next Steps", Colors.green, steps),
        // Display medical disclaimer
        _buildSection("📜 Disclaimer", Colors.grey, [disclaimer]),
      ],
    );
  }

  Widget _buildDiseaseSection(String title, List<Map<String, String>> diseases) {
    // Return padded column with disease information
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display section title
          Text(
            title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          // Add spacing below title
          SizedBox(height: 6),
          // Map each disease to a widget with progress bar
          ...diseases.map((d) {
            // Initialize confidence value
            double confValue = 0;
            // Try to parse confidence percentage from string
            try {
              // Remove % symbol and parse as double
              confValue = double.parse(d["confidence"]!.replaceAll("%", "").trim());
            } catch (_) {
              // Set to 0 if parsing fails
              confValue = 0;
            }

            // Green for high confidence (>=50%), orange for medium (>=30%), red for low
            Color badgeColor = confValue >= 50
                ? Colors.green
                : (confValue >= 30 ? Colors.orange : Colors.red);

            // Return disease item with progress bar
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display disease name with confidence percentage in a row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Disease name (takes up most of the space)
                      Expanded(
                        child: Text(
                          d["name"] ?? "Unknown Disease",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      // Confidence percentage in a colored badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          border: Border.all(color: badgeColor, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${confValue.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Add spacing between title and progress bar
                  SizedBox(height: 6),
                  // Progress bar container with background
                  Container(
                    // Set progress bar height to 28 for better visibility
                    height: 28,
                    // Style the background container
                    decoration: BoxDecoration(
                      // Light gray background for unfilled portion
                      color: Colors.grey.shade200,
                      // Round the corners
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // FractionallySizedBox fills based on confidence percentage
                    child: FractionallySizedBox(
                      // Align filled portion to the left
                      alignment: Alignment.centerLeft,
                      // Set width factor based on confidence (0.0 to 1.0)
                      widthFactor: confValue / 100,
                      // Filled portion of progress bar
                      child: Container(
                        // Apply color based on confidence level
                        decoration: BoxDecoration(
                          color: badgeColor,
                          // Round the corners to match background
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Color color, List<String> items) {
    // Return padded column with section content
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display section title with custom color
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          // Add spacing below title
          SizedBox(height: 4),
          // Map each item to a text widget
          ...items.map((item) => Padding(
                // Add vertical padding between items
                padding: const EdgeInsets.symmetric(vertical: 2),
                // Display item text with styling
                child: Text(item, style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4)),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return stack to overlay loading indicator on top of main content
    return Stack(
      children: [
        // Main scaffold with app structure
        Scaffold(
          // Light green background color
          backgroundColor: Colors.green.shade50,
          // App bar at the top
          appBar: AppBar(
            // App title
            title: Text("🌿 AfiyahMed"),
            // Green background for app bar
            backgroundColor: Colors.green.shade600,
            // Center the title
            centerTitle: true,
            // Add shadow below app bar
            elevation: 4,
            // Shadow color
            shadowColor: Colors.green.shade200,
          ),
          // Main body content
          body: SafeArea(
            // Allow scrolling for long content
            child: SingleChildScrollView(
              // Add padding around content
              padding: EdgeInsets.all(18),
              // Column for vertical layout
              child: Column(
                // Stretch children to full width
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Display app title
                  Text(
                    "AI-Powered Skin Diagnosis",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800),
                  ),
                  // Add spacing below title
                  SizedBox(height: 20),
                  // Text field for symptoms input
                  TextField(
                    // Connect to symptoms controller
                    controller: _symptomsController,
                    // Allow 2 lines of text
                    maxLines: 2,
                    // Input field styling
                    decoration: InputDecoration(
                      // Placeholder text
                      labelText: "Enter your symptoms",
                      // Label color
                      labelStyle: TextStyle(color: Colors.green.shade700),
                      // Border when focused
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // Default border
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      // Icon inside text field
                      prefixIcon: Icon(Icons.healing, color: Colors.green.shade600),
                    ),
                  ),
                  // Add spacing below text field
                  SizedBox(height: 16),
                  // Container for image preview
                  Container(
                    // Set height for image preview area
                    height: 180,
                    // Style the container
                    decoration: BoxDecoration(
                      // White background
                      color: Colors.white,
                      // Round corners
                      borderRadius: BorderRadius.circular(12),
                      // Green border
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    // Center content inside container
                    child: Center(
                      // Display image or placeholder text
                      child: (kIsWeb && _imageBytes != null)
                          // For web: display image from bytes
                          ? Image.memory(_imageBytes!, height: 150)
                          : (!kIsWeb && _imageFile != null)
                              // For mobile: display image from file
                              ? Image.file(_imageFile!, height: 150)
                              // No image selected: show placeholder text
                              : Text("No image selected", style: TextStyle(color: Colors.grey[700])),
                    ),
                  ),
                  // Add spacing below image preview
                  SizedBox(height: 16),
                  // Button to pick image from gallery
                  _gradientButton("📷 Pick Image", _pickImage),
                  // Add spacing between buttons
                  SizedBox(height: 14),
                  // Button to send image and symptoms to server
                  _gradientButton("🔍 Analyze", _sendToServer),
                  // Add spacing below buttons
                  SizedBox(height: 20),
                  // Display results if available
                  if (_resultWidget != null)
                    // Card container for results
                    Card(
                      // White background
                      color: Colors.white,
                      // Add shadow effect
                      elevation: 3,
                      // Round card corners
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      // Add padding inside card
                      child: Padding(padding: const EdgeInsets.all(16), child: _resultWidget!),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Loading overlay that appears during API request
        if (_loading)
          // Semi-transparent dark background
          Container(
            color: Colors.black.withOpacity(0.4),
            // Center loading indicator
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular loading spinner
                  CircularProgressIndicator(color: Colors.white),
                  // Add spacing below spinner
                  SizedBox(height: 12),
                  // Loading text
                  Text("Analyzing...", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
