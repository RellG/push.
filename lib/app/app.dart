import 'package:flutter/material.dart';
import 'package:push_app/app/theme/theme.dart';

class PushApp extends StatelessWidget {
  const PushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Push.',
      theme: PushTheme.light(),
      darkTheme: PushTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Text(
          'Push.',
          style: textTheme.displaySmall,
        ),
      ),
    );
  }
}
