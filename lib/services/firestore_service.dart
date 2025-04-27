import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/chat_message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUserData(String uid, String name, String email) async {
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'isAdmin': false,
    }, SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc.data()!, uid);
    }
    return null;
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    await _db.collection('chat_messages').add(message.toFirestore());
  }

  Stream<List<ChatMessage>> getUserChats(String userId) {
    return _db
        .collection('chat_messages')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc.data())).toList());
  }
}