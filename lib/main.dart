import 'package:flutter/material.dart';

void main() {
  runApp(const PushApp());
}

class PushApp extends StatelessWidget {
  const PushApp({super.key});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFFFAFAFA),
      fontFamily: 'Geist',
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    );

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Push.',
      home: Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(
          child: Text('Push.', style: textStyle),
        ),
      ),
    );
  }
}
