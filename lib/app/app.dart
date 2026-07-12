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
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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

    // Auth-flow debug readout, opt-in via an `authdebug` query param
    // (https://bussdown.space/?authdebug=1): shows how the Google redirect
    // settled so the flow can be diagnosed on devices without a console.
    ref
      ..listen<String?>(authRedirectDebugProvider, (previous, next) {
        if (next == null || !Uri.base.query.contains('authdebug')) {
          return;
        }
        // Replace rather than queue: the breadcrumb grows as the flow
        // progresses, and only the latest (fullest) state matters.
        _scaffoldMessengerKey.currentState
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('auth debug: $next'),
              duration: const Duration(seconds: 45),
            ),
          );
      })
      // Surface auth failures (including redirect errors that land on a
      // fresh page load) as a SnackBar. On a mobile PWA the browser console
      // is out of reach, so this is the only place a sign-in error is
      // actually visible.
      ..listen<String?>(lastAuthErrorProvider, (previous, next) {
        if (next == null) {
          return;
        }
        _scaffoldMessengerKey.currentState
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Sign-in error: $next')));
        // Clear so the same error doesn't re-fire on rebuild; the re-entrant
        // callback hits the null early-return above.
        ref.read(lastAuthErrorProvider.notifier).state = null;
      });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Push.',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: PushTheme.light(),
      darkTheme: PushTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
