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

class _PushMaterialApp extends ConsumerStatefulWidget {
  const _PushMaterialApp();

  @override
  ConsumerState<_PushMaterialApp> createState() => _PushMaterialAppState();
}

class _PushMaterialAppState extends ConsumerState<_PushMaterialApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force the day key to re-evaluate immediately on resume so a set
      // logged just after midnight lands in the right [DayLog] bucket.
      ref.invalidate(todayDateProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
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
