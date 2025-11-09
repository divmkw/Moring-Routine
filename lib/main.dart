import 'package:flutter/material.dart';
// import 'services/hive_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/setting_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // await initializeNotifications();
  // await HiveService.initHive();
  runApp(const MorningRoutineApp());
}

class MorningRoutineApp extends StatefulWidget {
  const MorningRoutineApp({super.key});

  @override
  State<MorningRoutineApp> createState() => _MorningRoutineAppState();
}

class _MorningRoutineAppState extends State<MorningRoutineApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // Called from SettingsScreen via widget.onThemeChanged
  Future<void> _toggleTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode); // persist choice
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morning Routine Master',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFF6B6B),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF212121),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomePage(onThemeChanged: _toggleTheme),
    );
  }
}

//******************************************************HOME PAGE*******************************************/
class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const HomePage({super.key, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const RoutineScreen(),
      const StatsPage(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: "Routine",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Stats"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

//****************************************************** Hive Service for Data Persistence *******************************************/

// Example usage in a widget
// Future<void> _saveActivity(String taskName, bool isCompleted) async {
//   final activity = DailyActivity(
//     date: DateTime.now(),
//     taskName: taskName,
//     isCompleted: isCompleted,
//     timeSpent: '5 min',
//   );
//   await HiveService.saveDailyActivity(activity);
// }

// // Check completed activities
// void _loadTodaysActivities() {
//   final activities = HiveService.getActivitiesForDate(DateTime.now());
//   for (var activity in activities) {
//     print('${activity.taskName}: ${activity.isCompleted}');
//   }
// } 


