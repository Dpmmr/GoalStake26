import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/match_centre/match_centre_screen.dart';
import '../../features/my_bets/my_bets_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/last_dance/last_dance_screen.dart';
import '../../features/ai_centre/ai_centre_screen.dart';
import '../../features/admin/admin_access.dart';
import '../../features/notifications/notifications_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.when(
        data: (auth) => auth.session != null,
        loading: () => false,
        error: (_, __) => false,
      );

      final isOnAuth = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnAuth) {
        return '/login';
      }

      if (isLoggedIn && isOnAuth) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/matches',
        builder: (context, state) => const MatchCentreScreen(),
      ),
      GoRoute(
        path: '/bets',
        builder: (context, state) => const MyBetsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/last-dance',
        builder: (context, state) => const LastDanceScreen(),
      ),
      GoRoute(
        path: '/ai-centre',
        builder: (context, state) => const AiCentreScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminAccess(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
