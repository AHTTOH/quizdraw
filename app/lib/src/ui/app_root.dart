import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state.dart';
import 'onboarding_screen.dart';
import 'tabs/home_screen.dart';
import 'tabs/palette_screen.dart';
import 'tabs/settings_screen.dart';

class AppRoot extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const AppRoot({super.key, required this.navigatorKey});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _index = 0;
  bool _showOnboarding = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadSession();
    });
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    setState(() {
      _showOnboarding = !onboardingCompleted;
      _isLoading = false;
    });
  }

  void _completeOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        navigatorKey: widget.navigatorKey,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return MaterialApp(
        title: '너랑 나의 그림퀴즈',
        navigatorKey: widget.navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          visualDensity: VisualDensity.comfortable,
        ),
        home: OnboardingScreen(onComplete: _completeOnboarding),
      );
    }

    final pages = const [HomeScreen(), PaletteScreen(), SettingsScreen()];

    return MaterialApp(
      title: '너랑 나의 그림퀴즈',
      navigatorKey: widget.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        visualDensity: VisualDensity.comfortable,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, child) {
          return Theme(
            data: appState.isHighContrast 
                ? ThemeData(
                    brightness: Brightness.dark,
                    colorScheme: const ColorScheme.dark(
                      primary: Colors.yellow,
                      secondary: Colors.cyan,
                      surface: Colors.black87,
                    ),
                    useMaterial3: true,
                  )
                : Theme.of(context).copyWith(
                    textTheme: appState.isLargeText
                        ? Theme.of(context).textTheme.apply(
                            fontSizeFactor: 1.2,
                          )
                        : null,
                  ),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('너랑 나의 그림퀴즈'),
                backgroundColor: appState.isHighContrast ? Colors.black : null,
                foregroundColor: appState.isHighContrast ? Colors.yellow : null,
              ),
              body: SafeArea(child: pages[_index]),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined), 
                    selectedIcon: Icon(Icons.home), 
                    label: 'Home'
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.palette_outlined), 
                    selectedIcon: Icon(Icons.palette), 
                    label: 'Palette'
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined), 
                    selectedIcon: Icon(Icons.settings), 
                    label: 'Settings'
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



