import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter_linkify/flutter_linkify.dart'; // Added for clickable links
import 'login_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  String? apiKey;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isBotTyping = false;
  bool _isLoading = true;
  String _selectedLanguage = 'en-US';

  late AnimationController _animationController;
  late Animation<double> _micPulseAnimation;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadEnv();
    _loadPreferences();
    _setupPushNotifications();
    _checkForUpdates();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _micPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });
    _animationController.repeat(reverse: true);
    _animationController.forward();
  }

  Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: "assets/.env");
      setState(() {
        apiKey = dotenv.env['OPENAI_API_KEY'];
        _isLoading = false;
        if (apiKey == null || apiKey!.isEmpty) {
          Fluttertoast.showToast(msg: "API Key not found in .env file");
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: "Failed to load environment variables: $e");
      debugPrint('Error loading .env: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'en-US';
    });
  }

  Future<void> _setupPushNotifications() async {
    await _firebaseMessaging.requestPermission();
    await _firebaseMessaging.subscribeToTopic('app_updates');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showUpdateDialog(
          isAndroid: Theme.of(context).platform == TargetPlatform.android,
          title: message.notification!.title ?? 'New Version Available',
          body: message.notification!.body ?? 'A new version is available with exciting features!',
        );
        _analytics.logEvent(
          name: 'push_notification_received',
          parameters: {'version': message.data['version'] ?? 'unknown'},
        );
      }
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('last_update_check') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < 24 * 60 * 60 * 1000) return;

      await prefs.setInt('last_update_check', now);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final doc = await FirebaseFirestore.instance.collection('app_config').doc('version').get();
      if (!doc.exists) return;

      final latestVersion = doc.data()?['latest_version'] as String?;
      final releaseNotes = doc.data()?['release_notes'] as String? ?? 'Check out the latest features!';
      if (latestVersion == null || latestVersion == currentVersion) return;

      _analytics.logEvent(
        name: 'update_available',
        parameters: {'current_version': currentVersion, 'latest_version': latestVersion},
      );

      _showUpdateDialog(
        isAndroid: Theme.of(context).platform == TargetPlatform.android,
        title: 'New Version $latestVersion Available',
        body: releaseNotes,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  void _showUpdateDialog({
    required bool isAndroid,
    required String title,
    required String body,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _analytics.logEvent(name: 'update_dialog_dismissed');
            },
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () async {
              if (isAndroid) {
                try {
                  final updateInfo = await InAppUpdate.checkForUpdate();
                  if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
                    await InAppUpdate.startFlexibleUpdate();
                    await InAppUpdate.completeFlexibleUpdate();
                  }
                } catch (e) {
                  Fluttertoast.showToast(msg: 'Update failed: $e');
                }
              } else {
                const appStoreUrl = 'https://apps.apple.com/app/id6744954928';
                if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
                  await launchUrl(Uri.parse(appStoreUrl));
                } else {
                  Fluttertoast.showToast(msg: 'Could not open App Store');
                }
              }
              Navigator.pop(context);
              _analytics.logEvent(name: 'update_dialog_accepted');
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a message");
      return;
    }

    if (apiKey == null || apiKey!.isEmpty) {
      Fluttertoast.showToast(msg: "API Key not initialized. Please check your .env file.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final timestamp = DateTime.now();

    final messageData = {
      "text": message,
      "isUser": true,
      "userId": user?.uid,
      "userEmail": user?.email,
      "timestamp": timestamp,
      "language": _selectedLanguage,
    };

    try {
      await FirebaseFirestore.instance.collection('chat_messages').add(messageData);
      setState(() {
        _messages.add(messageData);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      });
      _messageController.clear();

      setState(() => _isBotTyping = true);
      String botResponse = await _getAIResponse(message);
      setState(() => _isBotTyping = false);

      final botMessageData = {
        "text": botResponse,
        "isUser": false,
        "userId": user?.uid,
        "userEmail": user?.email,
        "timestamp": DateTime.now(),
      };
      await FirebaseFirestore.instance.collection('chat_messages').add(botMessageData);
      setState(() {
        _messages.add(botMessageData);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      });
    } catch (e) {
      setState(() => _isBotTyping = false);
      Fluttertoast.showToast(msg: "Failed to process message: $e");
      debugPrint('Error in _sendMessage: $e');
    }
  }

  Future<String> _getAIResponse(String userInput) async {
    const String model = "gpt-4o-search-preview";
    final String url = "https://api.openai.com/v1/chat/completions";
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';

  if (user != null) {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      userName = doc.data()?['name'] ?? user.email ?? 'User';
    } else {
      userName = user.email ?? 'User';
    }
  }
   

    final Map<String, dynamic> requestBody = {
    "model": model,
    "web_search_options": {
      "user_location": {
        "type": "approximate",
        "approximate": {
          "country": "AU",
          "city": "Parramatta",
          "region": "New South Wales"
        }
      }
    },
    "messages": [
      {
        "role": "system",
        "content": """
You are an AI assistant created by the Englishfirm AI team to help students prepare for the PTE exam.
If a user's question is unrelated to the PTE or Englishfirm services, do not attempt to answer it. Instead, reply exactly with: $userName, please ask questions related to the PTE or Englishfirm services.
Do not provide responses on general topics or questions outside the PTE domain.
Your responses must always be:
a) Clear, concise, and strictly focused on PTE-related topics or Englishfirm services.
b) If the user's question is about any PTE institution, respond only with relevant information about Englishfirm and avoid mentioning other institutions.
"""      },
      {
        "role": "user",
        "content": userInput
      }
    ]
  };


    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiResponse = data["choices"][0]["message"]["content"];
        aiResponse = aiResponse.replaceAll(RegExp(r'[*#]'), '');
        return aiResponse;
      } else {
        
        return "$userName I'm having trouble understanding your request. Please try again shortly.";
      }
    } catch (e) {
      
      return "Sorry, $userName something went wrong while processing your request. Please try again in a moment.";
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Fluttertoast.showToast(msg: "Logged out successfully!");
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
    } catch (e) {
      Fluttertoast.showToast(msg: "Logout failed: ${e.toString()}");
    }
  }

  void _showAccountDetails() {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user?.email ?? "Not available"}'),
            const SizedBox(height: 8),
            Text('User ID: ${user?.uid ?? "Not available"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    String currentName = (doc.exists && doc['name'] != null) ? doc['name'] : '';
    TextEditingController nameController = TextEditingController(text: currentName);
    bool isEditing = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${user.email ?? "Not available"}'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                enabled: isEditing,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (!isEditing)
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    isEditing = true;
                  });
                },
                child: const Text('Edit'),
              ),
            if (isEditing) ...[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  String newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                        {'name': newName, 'email': user.email},
                        SetOptions(merge: true),
                      );
                      Fluttertoast.showToast(msg: "Profile updated successfully!");
                      setDialogState(() {
                        isEditing = false;
                      });
                    } catch (e) {
                      Fluttertoast.showToast(msg: "Failed to update profile: $e");
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ] else
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    TextEditingController currentPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              String currentPassword = currentPasswordController.text.trim();
              String newPassword = newPasswordController.text.trim();
              String confirmPassword = confirmPasswordController.text.trim();

              if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                Fluttertoast.showToast(msg: "All fields are required");
                return;
              }

              if (newPassword != confirmPassword) {
                Fluttertoast.showToast(msg: "New passwords do not match");
                return;
              }

              if (newPassword.length < 6) {
                Fluttertoast.showToast(msg: "Password must be at least 6 characters");
                return;
              }

              try {
                AuthCredential credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassword,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword);
                Fluttertoast.showToast(msg: "Password updated successfully!");
                Navigator.pop(dialogContext);
              } catch (e) {
                String errorMessage = "Failed to update password";
                if (e is FirebaseAuthException) {
                  switch (e.code) {
                    case 'wrong-password':
                      errorMessage = "Current password is incorrect";
                      break;
                    case 'weak-password':
                      errorMessage = "New password is too weak";
                      break;
                    default:
                      errorMessage = "Error: ${e.message}";
                  }
                }
                Fluttertoast.showToast(msg: errorMessage);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    TextEditingController passwordController = TextEditingController();
    bool isConfirmed = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will permanently delete your account and all associated data. Enter your password to confirm.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isConfirmed,
                    onChanged: (value) {
                      setDialogState(() {
                        isConfirmed = value ?? false;
                      });
                    },
                  ),
                  const Text('I understand this action is irreversible'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isConfirmed
                  ? () async {
                      String password = passwordController.text.trim();
                      if (password.isEmpty) {
                        Fluttertoast.showToast(msg: "Password is required");
                        return;
                      }

                      try {
                        AuthCredential credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: password,
                        );
                        await user.reauthenticateWithCredential(credential);
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                        QuerySnapshot messages = await FirebaseFirestore.instance
                            .collection('chat_messages')
                            .where('userId', isEqualTo: user.uid)
                            .get();
                        for (var doc in messages.docs) {
                          await doc.reference.delete();
                        }
                        await user.delete();
                        Fluttertoast.showToast(msg: "Account deleted successfully!");
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
                      } catch (e) {
                        String errorMessage = "Failed to delete account";
                        if (e is FirebaseAuthException) {
                          switch (e.code) {
                            case 'wrong-password':
                              errorMessage = "Password is incorrect";
                              break;
                            default:
                              errorMessage = "Error: ${e.message}";
                          }
                        }
                        Fluttertoast.showToast(msg: errorMessage);
                      }
                    }
                  : null,
              child: Text('Delete', style: TextStyle(color: isConfirmed ? Colors.red : Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearChatHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isConfirmed = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Clear Chat History'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will permanently delete all your chat messages. This action cannot be undone.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isConfirmed,
                    onChanged: (value) {
                      setDialogState(() {
                        isConfirmed = value ?? false;
                      });
                    },
                  ),
                  const Text('I understand this action is irreversible'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isConfirmed
                  ? () async {
                      try {
                        QuerySnapshot messages = await FirebaseFirestore.instance
                            .collection('chat_messages')
                            .where('userId', isEqualTo: user.uid)
                            .get();
                        for (var doc in messages.docs) {
                          await doc.reference.delete();
                        }
                        setState(() {
                          _messages.clear();
                        });
                        Fluttertoast.showToast(msg: "Chat history cleared successfully!");
                        Navigator.pop(dialogContext);
                      } catch (e) {
                        Fluttertoast.showToast(msg: "Failed to clear chat history: $e");
                      }
                    }
                  : null,
              child: Text('Clear', style: TextStyle(color: isConfirmed ? Colors.red : Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Transform.translate(
                offset: Offset(0, -5 * (_animationController.value - index * 0.2).abs()),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCustomButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color backgroundColor,
    double scale = 1.0,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => scale = 0.95);
      },
      onTapUp: (_) {
        setState(() => scale = 1.0);
        onPressed();
      },
      onTapCancel: () {
        setState(() => scale = 1.0);
      },
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  // Function to handle URL launching
  Future<void> _onOpenLink(LinkableElement link) async {
    final url = Uri.parse(link.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: "Could not open the link: ${link.url}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/logo.jpeg',
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error);
            },
          ),
        ),
        title: const Center(
          child: Text(
            'Englishfirm AI Assistant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black, width: 1.0),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'account_details':
                  _showAccountDetails();
                  break;
                case 'logout':
                  _logout();
                  break;
                case 'profile':
                  _showProfile();
                  break;
                case 'change_password':
                  _showChangePassword();
                  break;
                case 'delete_account':
                  _showDeleteAccount();
                  break;
                case 'clear_chat_history':
                  _showClearChatHistory();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'account_details', child: Text('Account Details')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'change_password', child: Text('Change Password')),
              PopupMenuItem(value: 'delete_account', child: Text('Delete Account')),
              PopupMenuItem(value: 'clear_chat_history', child: Text('Clear Chat History')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey[200]!],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(10),
                itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isBotTyping && index == _messages.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
                        child: Row(
                          children: [
                            Text(
                              "Thinking",
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                            const SizedBox(width: 5),
                            _buildTypingIndicator(),
                          ],
                        ),
                      ),
                    );
                  }

                  final message = _messages[index];
                  return Align(
                    alignment: message["isUser"] ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      decoration: BoxDecoration(
                        color: message["isUser"] ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: message["isUser"]
                          ? Text(
                              message["text"] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            )
                          : Linkify(
                              onOpen: _onOpenLink,
                              text: message["text"] ?? '',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              linkStyle: const TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: _messageController.text.isNotEmpty || FocusScope.of(context).hasFocus
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _getHintText(_selectedLanguage),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCustomButton(
                    onPressed: _sendMessage,
                    icon: Icons.send,
                    backgroundColor: Colors.green[700]!,
                  ),
                  const SizedBox(width: 8),
                  ScaleTransition(
                    scale: _isListening ? _micPulseAnimation : Tween<double>(begin: 1.0, end: 1.0).animate(_animationController),
                    child: _buildCustomButton(
                      onPressed: _listen,
                      icon: _isListening ? Icons.mic_off : Icons.mic,
                      backgroundColor: _isListening ? Colors.red : Colors.green[700]!,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _selectedLanguage,
          onResult: (val) => setState(() {
            _messageController.text = val.recognizedWords;
            if (val.finalResult) {
              _isListening = false;
              _sendMessage();
            }
          }),
        );
      } else {
        Fluttertoast.showToast(msg: "Speech recognition not available");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  String _getHintText(String locale) {
    switch (locale) {
      case 'en-US':
      default:
        return 'Type a message...';
    }
  }
}