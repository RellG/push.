import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:push_app/features/home/home_placeholder_screen.dart';
import 'package:push_app/features/onboarding/onboarding_screen.dart';
import 'package:push_app/providers/app_providers.dart';

abstract final class AppRoutes {
  static const root = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.root,
    redirect: (context, state) async {
      if (state.matchedLocation != AppRoutes.root) {
        return null;
      }

      final isComplete = await ref.read(onboardingCompleteProvider.future);
      return isComplete ? AppRoutes.home : AppRoutes.onboarding;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const _LaunchScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const HomePlaceholderScreen(),
        ),
      ),
    ],
  );
});

CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 250),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
