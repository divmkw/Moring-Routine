import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';

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
  // Hive tasks box
  late Box<Task> taskBox;

  // List of tasks initialized from Hive (title + time string)
  List<Map<String, String>> tasks = [];


  //final streakKey = "streak";
  int currentStreak = 0;
  int longestStreak = 0;

  // List to track task completion status
  late List<bool> taskCompletion;

  @override
  void initState() {
    super.initState();
    // Load today's tasks from Hive and initialize completion status
    taskBox = Hive.box<Task>('tasksBox');
    final now = DateTime.now();
    final todayTasks = taskBox.values.where((t) =>
      t.date.year == now.year &&
      t.date.month == now.month &&
      t.date.day == now.day
    ).toList();

    tasks = todayTasks.map((t) => {
      "title": t.title,
      "time": "${t.durationMinutes} min",
    }).toList();

    taskCompletion = List<bool>.filled(tasks.length, false);
    _scheduleEndOfDay();
  }

  // Calculate progress based on completed tasks
  double _calculateProgress() {
    if (tasks.isEmpty) return 0;
    final completedTasks = taskCompletion.where((completed) => completed).length;
    return completedTasks / tasks.length;
  }

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
            child: ListTile(
              title: Text("Current Streak: $currentStreak days in a row"),
              subtitle: Text("Longest: $longestStreak days"),
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
