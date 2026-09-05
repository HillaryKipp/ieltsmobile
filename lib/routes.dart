import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_state.dart';
import 'screens/auth_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/skill_screen.dart';
import 'screens/unit_overview_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/upgrade_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'theme.dart';
import 'widgets/error_view.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Navigate via router or update locally to keep state
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/skills/listening');
        break;
      case 2:
        context.go('/skills/reading');
        break;
      case 3:
        context.go('/skills/writing');
        break;
      case 4:
        context.go('/skills/speaking');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      const SkillScreen(skill: 'listening'),
      const SkillScreen(skill: 'reading'),
      const SkillScreen(skill: 'writing'),
      const SkillScreen(skill: 'speaking'),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          _onItemTapped(0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[600],
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home, color: AppTheme.primaryColor),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.headphones_outlined),
                activeIcon: Icon(Icons.headphones, color: AppTheme.primaryColor),
                label: 'Listening',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined),
                activeIcon: Icon(Icons.menu_book, color: AppTheme.primaryColor),
                label: 'Reading',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.edit_note_outlined),
                activeIcon: Icon(Icons.edit_note, color: AppTheme.primaryColor),
                label: 'Writing',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.mic_none_outlined),
                activeIcon: Icon(Icons.mic, color: AppTheme.primaryColor),
                label: 'Speaking',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

GoRouter createRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (BuildContext context, GoRouterState state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.user != null;
      final onAuthPage = state.matchedLocation.startsWith('/auth');
      final onResetPage = state.matchedLocation.startsWith('/reset-password');
      final onAdminPage = state.matchedLocation.startsWith('/admin');
      final onPrivacyPage = state.matchedLocation.startsWith('/privacy-policy');
      
      // Public routes that don't need auth
      final isPublicRoute = onAuthPage || onResetPage || onPrivacyPage || state.matchedLocation == '/';

      if (onAdminPage && !authState.isAdmin) {
        debugPrint('[ROUTER] Access denied: non-admin attempted to visit /admin -> redirecting to /');
        return '/';
      }

      if (isLoggedIn) {
        if (authState.resetPasswordRequired && !onResetPage) {
          debugPrint('[ROUTER] Password recovery active -> redirecting to /reset-password');
          return '/reset-password';
        }
        if (onAuthPage) {
          debugPrint('[ROUTER] Logged-in user on /auth -> redirecting to /');
          return '/';
        }
      } else {
        // If not logged in and trying to access a protected route
        if (!isPublicRoute && !state.matchedLocation.startsWith('/skills/')) {
           if (state.matchedLocation == '/profile' || state.matchedLocation == '/stats') {
             debugPrint('[ROUTER] Guest attempted to visit protected route ${state.matchedLocation} -> redirecting to /auth');
             return '/auth';
           }
        }
      }

      debugPrint('[ROUTER] Navigating to: ${state.matchedLocation} (user: ${authState.user?.id ?? "guest"})');
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: ErrorView(
        title: 'Page Not Found',
        message: 'The page "${state.uri}" could not be found.',
        retryLabel: 'Return Home',
        icon: Icons.find_in_page_outlined,
        onRetry: () => context.go('/'),
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const MainNavigationShell(initialIndex: 0);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (BuildContext context, GoRouterState state) {
          final unitId = state.uri.queryParameters['unitId'];
          return AdminScreen(initialUnitId: unitId);
        },
      ),
      GoRoute(
        path: '/skills/:skill',
        builder: (BuildContext context, GoRouterState state) {
          final skill = state.pathParameters['skill'] ?? 'listening';
          int index = 1;
          if (skill == 'reading') index = 2;
          if (skill == 'writing') index = 3;
          if (skill == 'speaking') index = 4;
          return MainNavigationShell(initialIndex: index);
        },
      ),
      GoRoute(
        path: '/stats',
        builder: (BuildContext context, GoRouterState state) {
          return const StatsScreen();
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) {
          return const ProfileScreen();
        },
      ),
      GoRoute(
        path: '/units/:unitId',
        builder: (BuildContext context, GoRouterState state) {
          final unitId = state.pathParameters['unitId']!;
          return UnitOverviewScreen(unitId: unitId);
        },
      ),
      GoRoute(
        path: '/units/:unitId/practice',
        builder: (BuildContext context, GoRouterState state) {
          final unitId = state.pathParameters['unitId']!;
          return PracticeScreen(unitId: unitId);
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) {
          final mode = state.uri.queryParameters['mode'];
          return AuthScreen(initialIsSignUp: mode == 'signup');
        },
      ),
      GoRoute(
        path: '/upgrade',
        builder: (BuildContext context, GoRouterState state) {
          return const UpgradeScreen();
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (BuildContext context, GoRouterState state) {
          return const ResetPasswordScreen();
        },
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (BuildContext context, GoRouterState state) {
          return const PrivacyPolicyScreen();
        },
      ),
    ],
  );
}
