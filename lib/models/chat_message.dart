import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class ChatMessage {
  final String text;
  final bool isUser;
  final String userId;
  final String userEmail;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.userId,
    required this.userEmail,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    return ChatMessage(
      text: data['text'] ?? '',
      isUser: data['isUser'] ?? false,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'isUser': isUser,
      'userId': userId,
      'userEmail': userEmail,
      'timestamp': timestamp,
    };
  }
}