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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
            useMaterial3: true,
            cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
            listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            useMaterial3: true,
            cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
            listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
          ),
          routes: {
            '/login': (context) => LoginScreen(
                  onSuccess: () => Navigator.of(context).pushReplacementNamed('/'),
                ),
            '/': (_) => const _RootGate(),
            '/home': (_) => const HomeShell(),
            '/system': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is! SystemRecord) return const SizedBox.shrink();
              return SystemDetailsScreen(system: args);
            },
            '/settings': (_) => const SettingsScreen(),
            '/settings/tokens': (_) => const SettingsFingerprintsScreen(),
            '/settings/notifications': (_) => const SettingsNotificationsScreen(),
            '/settings/server': (_) => const SettingsServerScreen(),
            '/alerts': (_) => const AlertsScreen(),
            '/containers': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is! SystemRecord) return const SizedBox.shrink();
              return ContainersScreen(system: args);
            },
            '/systemd': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is! SystemRecord) return const SizedBox.shrink();
              return SystemdScreen(system: args);
            },
            '/system-alerts': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is! SystemRecord) return const SizedBox.shrink();
              return SystemAlertsScreen(system: args);
            },
            '/system-smart': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is! SystemRecord) return const SizedBox.shrink();
              return SystemSmartScreen(system: args);
            },
            '/add-system': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              return AddSystemScreen(system: args is SystemRecord ? args : null);
            },
            '/settings/config-yaml': (_) => const SettingsConfigYamlScreen(),
            '/container-details': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
              if (args == null) return const SizedBox.shrink();
              return ContainerDetailsScreen(
                systemId: args['systemId']!,
                containerId: args['containerId']!,
                containerName: args['containerName']!,
              );
            },
            '/manage-alerts': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is! SystemRecord) return const SizedBox.shrink();
              return ManageAlertsScreen(system: args);
            },
          },
          initialRoute: '/',
        );
      },
    );
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

  final List<Widget> _pages = const [
    HomeOverviewScreen(),
    SystemsScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.computer_outlined), selectedIcon: Icon(Icons.computer), label: 'Systems'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
