import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:async';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _symptomsController = TextEditingController();
  File? _imageFile;
  Uint8List? _imageBytes;
  Map<String, dynamic>? _result;
  bool _loading = false;
  final picker = ImagePicker();

  // ✅ Your Render backend URL
  final String baseUrl = "https://afiyahmed-server.onrender.com";

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        _imageBytes = await pickedFile.readAsBytes();
      } else {
        _imageFile = File(pickedFile.path);
      }
      setState(() {});
    }
  }

  Future<void> _sendToServer() async {
    if ((kIsWeb && _imageBytes == null) ||
        (!kIsWeb && _imageFile == null) ||
        _symptomsController.text.isEmpty) {
      setState(() => _result = {"error": "⚠️ Please add image and symptoms."});
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      Uint8List imageData;

      if (kIsWeb) {
        img.Image? original = img.decodeImage(_imageBytes!);
        img.Image resized = img.copyResize(original!, width: 400);
        imageData = Uint8List.fromList(img.encodeJpg(resized));
      } else {
        Uint8List bytes = await _imageFile!.readAsBytes();
        img.Image? original = img.decodeImage(bytes);
        img.Image resized = img.copyResize(original!, width: 400);
        imageData = Uint8List.fromList(img.encodeJpg(resized));
      }

      final imageBase64 = base64Encode(imageData);

      // ✅ Full URL for predict endpoint
      final url = Uri.parse('$baseUrl/predict_json');

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "symptoms": _symptomsController.text.trim(),
              "image_base64": imageBase64,
            }),
          )
          .timeout(const Duration(seconds: 60));

      setState(() {
        _loading = false;
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data.containsKey("prediction")) {
            if (data["prediction"] is Map<String, dynamic>) {
              _result = data["prediction"];
            } else {
              _result = {"message": data["prediction"]};
            }
          } else if (data.containsKey("error")) {
            _result = {"error": data['error']};
          } else {
            _result = {"error": "Unexpected response from server."};
          }
        } else {
          _result = {"error": "❌ HTTP error: ${response.statusCode}"};
        }
      });
    } on http.ClientException catch (e) {
      setState(() {
        _loading = false;
        _result = {"error": "❌ Network error: ${e.message}"};
      });
    } on SocketException {
      setState(() {
        _loading = false;
        _result = {"error": "🚫 No internet connection."};
      });
    } on TimeoutException catch (e) {
  setState(() {
    _loading = false;
    _result = {"error": "❌ Request timed out: $e"};
  });
} catch (e) {
  setState(() {
    _loading = false;
    _result = {"error": "❌ Error: $e"};
  });
}
  }

  Widget _gradientButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
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

  Widget _buildPredictionResult() {
    if (_result == null) return SizedBox.shrink();

    if (_result!.containsKey("error")) {
      return Card(
        color: Colors.red.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _result!["error"],
            style: TextStyle(fontSize: 17, color: Colors.red),
          ),
        ),
      );
    }

    List<dynamic> topDiseases = _result!["top_diseases"] ?? [];
    String explanation = _result!["explanation"] ?? "";
    String urgency = _result!["urgency"] ?? "";
    List<dynamic> steps = _result!["recommended_next_steps"] ?? [];
    String disclaimer = _result!["disclaimer"] ?? "";

    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topDiseases.isNotEmpty) ...[
              Text("🩺 Top Possible Diseases:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              for (var disease in topDiseases)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${disease["name"] ?? "-"} - ${disease["confidence"] ?? "0%"}"),
                    LinearProgressIndicator(
                      value: double.tryParse(
                              (disease["confidence"] ?? "0%").toString().replaceAll("%", ""))! / 100,
                      color: Colors.green,
                      backgroundColor: Colors.green.shade100,
                    ),
                    SizedBox(height: 6),
                  ],
                ),
              Divider(),
            ],
            if (explanation.isNotEmpty) ...[
              Text("💡 Explanation:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(explanation),
              SizedBox(height: 8),
            ],
            if (urgency.isNotEmpty)
              Text("⚠️ Urgency: $urgency", style: TextStyle(fontWeight: FontWeight.bold)),
            if (steps.isNotEmpty) ...[
              SizedBox(height: 8),
              Text("✅ Recommended Next Steps:", style: TextStyle(fontWeight: FontWeight.bold)),
              for (var step in steps) Text("- $step"),
            ],
            if (disclaimer.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(disclaimer, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.green.shade50,
          appBar: AppBar(
            title: Text("🌿 AfiyahMed"),
            backgroundColor: Colors.green.shade600,
            centerTitle: true,
            elevation: 4,
            shadowColor: Colors.green.shade200,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "AI-Powered Skin Diagnosis",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _symptomsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Enter your symptoms",
                      labelStyle: TextStyle(color: Colors.green.shade700),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.healing, color: Colors.green.shade600),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Center(
                      child: (kIsWeb && _imageBytes != null)
                          ? Image.memory(_imageBytes!, height: 150)
                          : (!kIsWeb && _imageFile != null)
                              ? Image.file(_imageFile!, height: 150)
                              : Text("No image selected", style: TextStyle(color: Colors.grey[700])),
                    ),
                  ),
                  SizedBox(height: 16),
                  _gradientButton("📷 Pick Image", _pickImage),
                  SizedBox(height: 14),
                  _gradientButton("🔍 Analyze", _sendToServer),
                  SizedBox(height: 20),
                  _buildPredictionResult(),
                ],
              ),
            ),
          ),
        ),
        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text("Analyzing...", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
