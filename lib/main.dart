import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/setting_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());

  await Hive.openBox<Task>('tasksBox');
  await Hive.openBox('settings');

  // Auto carry forward unfinished tasks
  await carryForwardUnfinishedTasks();

  runApp(const MorningRoutineApp());
}

/// Automatically move unfinished tasks from yesterday to today
Future<void> carryForwardUnfinishedTasks() async {
  final box = Hive.box<Task>('tasksBox');
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  final yesterdayTasks = box.values.where(
    (task) =>
        isSameDate(task.date, yesterday) &&
        task.isCompleted == false,
  );

  for (var task in yesterdayTasks) {
    // Check if same task already exists for today
    bool alreadyExists = box.values.any(
      (t) => isSameDate(t.date, today) && t.title == task.title,
    );
    if (!alreadyExists) {
      box.add(Task(
        title: task.title,
        durationMinutes: task.durationMinutes,
        date: today,
        isCompleted: false,
      ));
    }
  }
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class MorningRoutineApp extends StatefulWidget {
  const MorningRoutineApp({super.key});

  @override
  State<MorningRoutineApp> createState() => _MorningRoutineAppState();
}

class _MorningRoutineAppState extends State<MorningRoutineApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Color accentColor = const Color(0xFFFF6B6B);

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

  Future<void> _toggleTheme(bool isDarkMode, Color newAccentColor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      accentColor = newAccentColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morning Routine Master',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: accentColor,
        useMaterial3: true,
        brightness: Brightness.light,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: accentColor,
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: HomePage(
        onThemeChanged: _toggleTheme,
        accentColor: accentColor,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(bool, Color) onThemeChanged;
  final Color accentColor;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.accentColor,
  });

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
      StatsPage(accentColor: widget.accentColor),
      SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: widget.accentColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: "Routine",
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: "Stats"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}