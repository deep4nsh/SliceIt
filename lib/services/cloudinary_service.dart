import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dpm6nkfbk';
  static const String uploadPreset = 'sliceit_upload';
  static const String uploadFolder = 'sliceit/settlements';

  static final CloudinaryService _instance = CloudinaryService._internal();

  factory CloudinaryService() {
    return _instance;
  }

  CloudinaryService._internal();

  /// Upload settlement proof image to Cloudinary using unsigned uploads
  Future<String?> uploadSettlementProof(
    File imageFile, {
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('Starting Cloudinary upload...');

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = uploadFolder;
      request.fields['public_id'] = 'proof_${DateTime.now().millisecondsSinceEpoch}';

      // Add file
      final fileBytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: imageFile.path.split('/').last,
        ),
      );

      // Send request with progress tracking
      final streamResponse = await request.send();

      // Handle progress
      int bytesReceived = 0;
      final contentLength = streamResponse.contentLength ?? 0;

      final responseStream = streamResponse.stream.listen(
        (chunk) {
          bytesReceived += chunk.length;
          if (contentLength > 0) {
            final progress = bytesReceived / contentLength;
            onProgress(progress);
            debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final url = jsonResponse['secure_url'] as String?;
        debugPrint('Upload successful: $url');
        onProgress(1.0);
        return url;
      } else {
        debugPrint('Upload failed with status ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }
}
