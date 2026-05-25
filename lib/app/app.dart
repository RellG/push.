import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/app/router.dart';
import 'package:push_app/app/theme/theme.dart';
import 'package:push_app/providers/app_providers.dart';

class PushApp extends StatelessWidget {
  const PushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _PushMaterialApp(),
    );
  }
}

class _PushMaterialApp extends ConsumerWidget {
  const _PushMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Push.',
      theme: PushTheme.light(),
      darkTheme: PushTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
