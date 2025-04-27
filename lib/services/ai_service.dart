import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final String apiKey;
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  AIService(this.apiKey);

  Future<String> getResponse(String userInput) async {
    final url = Uri.parse('$_baseUrl?key=$apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
              'You are an AI assistant created by the Englishfirm AI team to help students prepare for the PTE exam. '
                  'Your responses should be clear, concise, and relevant to PTE-related topics. '
                  'If a question is unrelated to the PTE exam, respond with: "I am designed to answer PTE-related questions only." '
                  '\n\nStudent\'s query:\n\n$userInput'
            }
          ]
        }
      ]
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      }
      return 'Sorry, I couldn’t process your request.';
    } catch (e) {
      throw Exception('AI Service Error: $e');
    }
  }
}