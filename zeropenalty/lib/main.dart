import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/trip_provider.dart';
import 'providers/history_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/risk_zone_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/live_trip_screen.dart';
import 'screens/trip_summary_screen.dart';
import 'screens/history_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/risk_zone_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ZeroPenaltyApp());
}

class ZeroPenaltyApp extends StatelessWidget {
  const ZeroPenaltyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => RiskZoneProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ZeroPenalty',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
            routes: {
              '/trip': (context) => const LiveTripScreen(),
              '/summary': (context) => const TripSummaryScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Main navigation shell with bottom nav bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    HistoryScreen(),
    RiskZoneScreen(),
    RewardsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          border: Border(
            top: BorderSide(color: context.borderColor.withOpacity(0.5)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: context.surfaceBg,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: context.textMuted,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_rounded),
              label: 'Risk Zones',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stars_rounded),
              label: 'Rewards',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
