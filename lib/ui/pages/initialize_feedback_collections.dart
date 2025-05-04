import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class InitializeFeedbackCollections extends StatelessWidget {
  const InitializeFeedbackCollections({super.key});

  Future<void> _initializeCollections(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: "Please sign in to initialize collections");
      return;
    }

    try {
      // Initialize feedback collection with documents for each model
      final feedbackCollection = FirebaseFirestore.instance.collection('feedback');
      final models = ['gpt-3.5-turbo', 'gpt-4', 'gpt-4-turbo'];

      for (String model in models) {
        await feedbackCollection.doc(model).set({
          'model': model,
          'score': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Initialize feedback_entries with a sample entry (optional, for testing)
      final feedbackEntriesCollection = FirebaseFirestore.instance.collection('feedback_entries');
      await feedbackEntriesCollection.add({
        'model': 'gpt-3.5-turbo',
        'userId': user.uid,
        'messageId': 'sample_message_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(msg: "Feedback collections initialized successfully!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to initialize collections: $e");
      debugPrint("Initialization error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initialize Feedback Collections')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _initializeCollections(context),
          child: const Text('Initialize Collections'),
        ),
      ),
    );
  }
}