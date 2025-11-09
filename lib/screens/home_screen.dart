import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../models/daily_activity.dart';
// import '../services/hive_service.dart';
import 'dart:async';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // List of tasks
  final List<Map<String, String>> tasks = [
    {"title": "Drink Water", "time": "1 min"},
    {"title": "Stretch for 5 minutes", "time": "5 min"},
    {"title": "Meditate", "time": "10 min"},
  ];

  //final streakKey = "streak";
  int currentStreak = 0;
  int longestStreak = 0;

  // List to track task completion status
  late List<bool> taskCompletion;

  @override
  void initState() {
    super.initState();
    // Initialize task completion status to false for all tasks
    taskCompletion = List<bool>.filled(tasks.length, false);
    // _loadStreaks(); // Load streaks from SharedPreferences
    // Schedule end-of-day logic
    _scheduleEndOfDay();
  }

  // Calculate progress based on completed tasks
  double _calculateProgress() {
    final completedTasks = taskCompletion
        .where((completed) => completed)
        .length;
        // await _updateStreaks();
    return completedTasks / tasks.length;
  }

  // Save streaks to SharedPreferences
  // Future<void> _saveStreaks() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setInt('currentStreak', currentStreak);
  //   await prefs.setInt('longestStreak', longestStreak);
  // }

  // // Load streaks from SharedPreferences
  // Future<void> _loadStreaks() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     currentStreak = prefs.getInt('currentStreak') ?? 0;
  //     longestStreak = prefs.getInt('longestStreak') ?? 0;
  //   });
  // }

  // // Update streaks when daily tasks are completed
  // Future<void> _updateStreaks() async {
  //   if (_calculateProgress() == 1.0) {
  //     currentStreak++;
  //     if (currentStreak > longestStreak) {
  //       longestStreak = currentStreak;
  //     }
  //     await _saveStreaks();
  //     Fluttertoast.showToast(
  //       msg: "Congratulations! You've completed today's tasks!",
  //       toastLength: Toast.LENGTH_SHORT,
  //       gravity: ToastGravity.BOTTOM,
  //       backgroundColor: Colors.black54,
  //       textColor: Colors.white,
  //       fontSize: 16.0,
  //     );
  //   } else {
  //     currentStreak = 0; // Reset streak if tasks are not completed
  //     await _saveStreaks();
  //   }
  // }

  // Save daily activity to Hive
  // Future<void> _saveDailyActivity() async {
  //   final now = DateTime.now();
  //   final dailyActivities = tasks.asMap().entries.map((entry) {
  //     final index = entry.key;
  //     final task = entry.value;
  //     return DailyActivity(
  //       date: now,
  //       taskName: task["title"]!,
  //       isCompleted: taskCompletion[index],
  //       timeSpent: task["time"]!,
  //     );
  //   }).toList();

  //   for (var activity in dailyActivities) {
  //     await HiveService.saveDailyActivity(activity);
  //   }

  //   Fluttertoast.showToast(
  //     msg: "Daily activities saved for ${DateFormat('yyyy-MM-dd').format(now)}",
  //     toastLength: Toast.LENGTH_SHORT, // or Toast.LENGTH_LONG
  //     gravity: ToastGravity.BOTTOM, // position: TOP, CENTER, BOTTOM
  //     backgroundColor: Colors.black54,
  //     textColor: Colors.white,
  //     fontSize: 16.0,
  //   );

  //   // print("Daily activities saved for ${DateFormat('yyyy-MM-dd').format(now)}");
  // }

  // Schedule end-of-day logic
  void _scheduleEndOfDay() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final durationUntilMidnight = midnight.difference(now);

    Timer(durationUntilMidnight, () async {
      // await _saveDailyActivity();
      _scheduleEndOfDay(); // Reschedule for the next day
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Build lasting morning habits",
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Card(
            color: const Color.fromARGB(255, 131, 160, 5),
            child: const ListTile(
              leading: Icon(Icons.star, color: Colors.orange),
              title: Text("Morning rituals create extraordinary days"),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color.fromARGB(255, 162, 91, 209),
            child: const ListTile(
              title: Text("Current Streak: 0 days in a row"),
              subtitle: Text("Longest: 0 days"),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Today's Progress"),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _calculateProgress(),
            backgroundColor: Colors.grey[200],
          ),
          const SizedBox(height: 16),
          const Text(
            "Today's Routine",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < tasks.length; i++)
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: taskCompletion[i],
                  onChanged: (value) {
                    setState(() {
                      taskCompletion[i] = value!;
                    });
                  },
                ),
                title: Text(tasks[i]["title"]!),
                subtitle: Text(tasks[i]["time"]!),
              ),
            ),
        ],
      ),
    );
  }
}
