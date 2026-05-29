import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_flutter/cloudinary_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class CloudinaryService {
  static const String cloudName = 'dpm6nkfbk';
  static const String uploadPreset = 'sliceit_upload';

  static final CloudinaryService _instance = CloudinaryService._internal();

  factory CloudinaryService() {
    return _instance;
  }

  CloudinaryService._internal() {
    CloudinaryFlutter.configure(
      cloudName: cloudName,
      apiKey: '', // Not needed for unsigned uploads
    );
  }

  Future<String?> uploadSettlementProof(
    File imageFile, {
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('Starting Cloudinary upload...');

      final response = await CloudinaryFlutter.instance.openUploadWidget(
        context: null, // We're not using the widget, just the API
        showLogo: false,
      );

      // For unsigned uploads, we use the Cloudinary HTTP API directly
      final cloudinary = CloudinaryFlutter.instance;

      final cloudinaryResponse = await cloudinary.signedUpload(
        imageFile.path,
        uploadPreset: uploadPreset,
        folder: 'sliceit/settlements',
        fileName: 'proof_${DateTime.now().millisecondsSinceEpoch}',
        onProgress: (count, total) {
          final progress = count / total;
          onProgress(progress);
          debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (cloudinaryResponse.isSuccessful) {
        final url = cloudinaryResponse.data?['secure_url'] as String?;
        debugPrint('Upload successful: $url');
        return url;
      } else {
        debugPrint('Upload failed: ${cloudinaryResponse.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  /// Alternative: Direct HTTP upload using unsigned preset (more reliable for Flutter)
  Future<String?> uploadSettlementProofDirect(
    File imageFile, {
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('Starting direct Cloudinary upload...');

      final request = MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'sliceit/settlements';
      request.fields['public_id'] = 'proof_${DateTime.now().millisecondsSinceEpoch}';

      request.files.add(
        MultipartFile.fromBytes(
          'file',
          await imageFile.readAsBytes(),
          filename: imageFile.path.split('/').last,
        ),
      );

      final streamResponse = await request.send();
      final response = await StreamedResponse(streamResponse).toResponse();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final url = jsonResponse['secure_url'] as String?;
        debugPrint('Upload successful: $url');
        onProgress(1.0);
        return url;
      } else {
        debugPrint('Upload failed with status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }
}
