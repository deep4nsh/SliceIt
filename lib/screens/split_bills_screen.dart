import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:sliceit/screens/create_split_bill_screen.dart';
import '../utils/colors.dart';

class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  File? _image;
  final picker = ImagePicker();
  TextRecognizer textRecognizer = GoogleMlKit.vision.textRecognizer();
  List<Line> _lines = [];
  bool _isParsing = false;

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _isParsing = true;
    });

    try {
      final inputImage = InputImage.fromFile(_image!);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      List<Line> lines = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          lines.add(Line(line.text, line.boundingBox));
        }
      }

      setState(() {
        _lines = lines;
        _isParsing = false;
      });
    } catch (e) {
      debugPrint('Error processing image: $e');
      setState(() => _isParsing = false);
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
      _lines = [];
    });
  }

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split Bills')),
      body: _isParsing
          ? const Center(child: CircularProgressIndicator())
          : _image == null
          ? _buildImagePicker()
          : _buildImageWithOverlay(),
      floatingActionButton: _image != null && !_isParsing
        ? Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CreateSplitBillScreen(lines: _lines),
                  ));
                },
                icon: const Icon(Icons.add), 
                label: const Text('Create Bill'),
                backgroundColor: AppColors.sageGreen,
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                onPressed: _clearImage,
                child: const Icon(Icons.clear),
                backgroundColor: AppColors.terracotta,
              ),
            ], 
          )
        : null,
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Scan a receipt to get started", style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt, color: Colors.white,),
            label: const Text('Take Photo', style: TextStyle(color: Colors.white),),
            onPressed: () => _getImage(ImageSource.camera),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            icon: const Icon(Icons.photo_library, color: Colors.white,),
            label: const Text('Choose from Gallery', style: TextStyle(color: Colors.white),),
            onPressed: () => _getImage(ImageSource.gallery),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mustardYellow,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay() {
    return InteractiveViewer(
      maxScale: 4.0,
      child: CustomPaint(
        foregroundPainter: TextOverlayPainter(_lines),
        child: Center(
          child: Image.file(_image!),
        ),
      ),
    );
  }
}

class Line {
  final String text;
  final Rect boundingBox;

  Line(this.text, this.boundingBox);
}

class TextOverlayPainter extends CustomPainter {
  final List<Line> lines;

  TextOverlayPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.terracotta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final line in lines) {
      canvas.drawRect(line.boundingBox, paint);
    }
  }

  @override
  bool shouldRepaint(TextOverlayPainter oldDelegate) => true;
}
