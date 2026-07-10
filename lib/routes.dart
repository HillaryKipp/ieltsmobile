import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'auth_state.dart';
import 'screens/auth_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/skill_screen.dart';
import 'screens/unit_overview_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';
import 'theme.dart';

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

    return Scaffold(
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
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final auth = Provider.of<AuthState>(context, listen: false);
    
    if (auth.isLoading) return null; // Wait for initial auth state check

    final isLoggedIn = auth.user != null;
    final onAuthPage = state.matchedLocation == '/auth';
    final onResetPage = state.matchedLocation == '/reset-password';

    if (!isLoggedIn && !onAuthPage && !onResetPage) {
      return '/auth';
    }

    if (isLoggedIn) {
      if (auth.resetPasswordRequired && !onResetPage) {
        return '/reset-password';
      }
      if (onAuthPage) {
        return '/';
      }
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const MainNavigationShell(initialIndex: 0);
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
        return const AuthScreen();
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (BuildContext context, GoRouterState state) {
        return const ResetPasswordScreen();
      },
    ),
  ],
);
