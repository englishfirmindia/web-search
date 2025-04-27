import 'package:flutter/material.dart';
import 'dart:async';

class TypingLoadingScreen extends StatefulWidget {
  const TypingLoadingScreen({super.key});

  @override
  _TypingLoadingScreenState createState() => _TypingLoadingScreenState();
}

class _TypingLoadingScreenState extends State<TypingLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _typingAnimation;
  final String _text = "Englishfirm AI";
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    // Typing animation
    _typingAnimation = IntTween(begin: 0, end: _text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // Toggle cursor visibility
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });

    // Navigate to login after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Matches user_page.dart gradient end
      body: Center(
        child: AnimatedBuilder(
          animation: _typingAnimation,
          builder: (context, child) {
            String displayedText = _text.substring(0, _typingAnimation.value);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayedText,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (_showCursor)
                  Container(
                    width: 12,
                    height: 34,
                    color: Colors.black,
                    margin: const EdgeInsets.only(left: 4),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}