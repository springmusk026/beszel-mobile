import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/systems_screen.dart';
import 'screens/system_details_screen.dart';
import 'screens/home_overview_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/containers_screen.dart';
import 'screens/systemd_screen.dart';
import 'screens/system_alerts_screen.dart';
import 'screens/settings_fingerprints_screen.dart';
import 'screens/settings_notifications_screen.dart';
import 'screens/system_smart_screen.dart';
import 'screens/settings_server_screen.dart';
import 'screens/add_system_screen.dart';
import 'screens/settings_config_yaml_screen.dart';
import 'screens/container_details_screen.dart';
import 'screens/manage_alerts_screen.dart';
import 'models/system_record.dart';
import 'services/auth_service.dart';
import 'api/pb_client.dart';
import 'theme/theme_controller.dart';
import 'navigation/animated_navigation_bar.dart';
import 'animations/app_durations.dart';
import 'animations/app_curves.dart';
import 'animations/page_transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ThemeController.instance.load(),
    PocketBaseManager.instance.load(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance.themeMode,
      builder: (context, _) {
        return MaterialApp(
          title: 'Beszel',
          themeMode: ThemeController.instance.themeMode.value,
          // Use enhanced theme configurations from design tokens
          theme: ThemeController.lightTheme,
          darkTheme: ThemeController.darkTheme,
          // Enable animated theme transitions (300ms per requirements)
          themeAnimationDuration: ThemeController.themeTransitionDuration,
          themeAnimationCurve: Curves.easeInOutCubic,
          onGenerateRoute: _generateRoute,
          initialRoute: '/',
        );
      },
    );
  }
}

/// Generates routes with custom page transitions.
/// Uses SlideUpPageRoute for detail screens per Requirements 2.1, 2.2, 2.5.
Route<dynamic>? _generateRoute(RouteSettings settings) {
  final args = settings.arguments;

  switch (settings.name) {
    // Root routes - use standard MaterialPageRoute
    case '/':
      return MaterialPageRoute(
        builder: (_) => const _RootGate(),
        settings: settings,
      );
    case '/login':
      return MaterialPageRoute(
        builder: (context) => LoginScreen(
          onSuccess: () => Navigator.of(context).pushReplacementNamed('/'),
        ),
        settings: settings,
      );
    case '/home':
      return MaterialPageRoute(
        builder: (_) => const HomeShell(),
        settings: settings,
      );

    // Detail screens - use SlideUpPageRoute for smooth transitions
    case '/system':
      if (args is! SystemRecord) return null;
      return SlideUpPageRoute(
        page: SystemDetailsScreen(system: args),
      );
    case '/containers':
      if (args is! SystemRecord) return null;
      return SlideUpPageRoute(
        page: ContainersScreen(system: args),
      );
    case '/systemd':
      if (args is! SystemRecord) return null;
      return SlideUpPageRoute(
        page: SystemdScreen(system: args),
      );
    case '/system-alerts':
      if (args is! SystemRecord) return null;
      return SlideUpPageRoute(
        page: SystemAlertsScreen(system: args),
      );
    case '/system-smart':
      if (args is! SystemRecord) return null;
      return SlideUpPageRoute(
        page: SystemSmartScreen(system: args),
      );
    case '/container-details':
      final mapArgs = args as Map<String, String>?;
      if (mapArgs == null) return null;
      return SlideUpPageRoute(
        page: ContainerDetailsScreen(
          systemId: mapArgs['systemId']!,
          containerId: mapArgs['containerId']!,
          containerName: mapArgs['containerName']!,
        ),
      );
    case '/manage-alerts':
      if (args is! SystemRecord) return null;
      return SlideUpPageRoute(
        page: ManageAlertsScreen(system: args),
      );
    case '/add-system':
      return SlideUpPageRoute(
        page: AddSystemScreen(system: args is SystemRecord ? args : null),
      );

    // Settings screens - use SlideUpPageRoute for consistency
    case '/settings':
      return SlideUpPageRoute(
        page: const SettingsScreen(),
      );
    case '/settings/tokens':
      return SlideUpPageRoute(
        page: const SettingsFingerprintsScreen(),
      );
    case '/settings/notifications':
      return SlideUpPageRoute(
        page: const SettingsNotificationsScreen(),
      );
    case '/settings/server':
      return SlideUpPageRoute(
        page: const SettingsServerScreen(),
      );
    case '/settings/config-yaml':
      return SlideUpPageRoute(
        page: const SettingsConfigYamlScreen(),
      );

    // Alerts screen
    case '/alerts':
      return SlideUpPageRoute(
        page: const AlertsScreen(),
      );

    default:
      return null;
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkBaseUrlAndAuth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data ?? false;
        if (!result) {
          // Base URL not configured, show server settings
          return SettingsServerScreen(
            onConfigured: () => setState(() {}), // Rebuild to check auth
          );
        }
        // Base URL configured, check authentication
        return FutureBuilder<bool>(
          future: _auth.isAuthenticated(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final ok = authSnapshot.data ?? false;
            if (!ok) {
              return LoginScreen(
                onSuccess: () => Navigator.of(context).pushReplacementNamed('/'),
              );
            }
            return const HomeShell();
          },
        );
      },
    );
  }

  Future<bool> _checkBaseUrlAndAuth() async {
    return await PocketBaseManager.instance.hasConfiguredBaseUrl();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Use a method to get pages to ensure proper key assignment for AnimatedSwitcher
  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const HomeOverviewScreen(key: ValueKey('home'));
      case 1:
        return const SystemsScreen(key: ValueKey('systems'));
      case 2:
        return const AlertsScreen(key: ValueKey('alerts'));
      case 3:
        return const SettingsScreen(key: ValueKey('settings'));
      default:
        return const HomeOverviewScreen(key: ValueKey('home'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppDurations.tabCrossFade, // 200ms cross-fade per Requirements 2.3
        switchInCurve: AppCurves.enter,
        switchOutCurve: AppCurves.exit,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _getPage(_index),
      ),
      bottomNavigationBar: AnimatedNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.computer_outlined),
            selectedIcon: Icon(Icons.computer),
            label: 'Systems',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
