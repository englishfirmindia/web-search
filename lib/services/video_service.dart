import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoService {
  static const String _baseUrl = 'https://api.synthesia.io/v2/videos';
  String? _apiKey;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  VideoService() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      await dotenv.load(fileName: "assets/.env");
      _apiKey = dotenv.env['SYNTHESIA_API_KEY'];
      if (_apiKey == null || _apiKey!.isEmpty) {
        print('Synthesia API key not found in .env file');
      }
    } catch (e) {
      print('Error loading .env file: $e');
      _apiKey = null;
    }
  }

  Future<String?> generateVideo(String input) async {
    if (_apiKey == null) {
      await _loadApiKey();
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      print('API key is missing or invalid');
      return null;
    }

    // Check cache
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'video_${input.hashCode}';
    final cachedUrl = prefs.getString(cacheKey);
    if (cachedUrl != null) {
      print('Returning cached video URL: $cachedUrl');
      return cachedUrl;
    }

    final Map<String, dynamic> requestBody = {
      "test": false,
      "title": "AI Generated Video",
      "visibility": "public",
      "aspectRatio": "16:9",
      "input": [
        {
          "avatar": "d480a1c2-afe4-4499-8f15-035a26660033",
          "background": "green_screen",
          "scriptText": input
        }
      ]
    };

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': _apiKey!,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          String videoId = data['id'];
          print('Video request successful! Video ID: $videoId');
          final videoUrl = await _pollVideoStatus(videoId);
          if (videoUrl != null) {
            // Cache the video URL
            await prefs.setString(cacheKey, videoUrl);
            return videoUrl;
          }
        } else {
          print('Error creating video: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Exception during video creation (attempt $attempt): $e');
      }

      if (attempt < _maxRetries) {
        print('Retrying video generation in ${_retryDelay.inSeconds} seconds...');
        await Future.delayed(_retryDelay);
      }
    }

    print('Video generation failed after $_maxRetries attempts');
    return null;
  }

  Future<String?> _pollVideoStatus(String videoId) async {
    final String url = '$_baseUrl/$videoId';
    const int maxAttempts = 20;
    const Duration pollingInterval = Duration(seconds: 30);
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': _apiKey!,
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String status = data['status'];
          print('Video status: $status');

          if (status == 'complete') {
            String downloadUrl = data['download'];
            print('Video is ready! Download URL: $downloadUrl');
            return downloadUrl;
          } else if (status == 'error' || status == 'rejected') {
            print('Video generation failed: $status - $data');
            return null;
          }
        } else {
          print('Polling error: ${response.statusCode} - ${response.body}');
        }

        await Future.delayed(pollingInterval);
        attempts++;
      } catch (e) {
        print('Exception during polling: $e');
        return null;
      }
    }
    print('Polling timed out after $maxAttempts attempts');
    return null;
  }
}