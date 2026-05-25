import 'package:flutter/material.dart';
import 'package:push_app/presentation/widgets/app_bottom_nav.dart';

class StatsPlaceholderScreen extends StatelessWidget {
  const StatsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Stats', style: Theme.of(context).textTheme.displaySmall),
        ),
      ),
    );
  }
}
