import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Task> taskBox;
  List<Task> todayTasks = [];
  late List<bool> completionList;

  int currentStreak = 0;
  int longestStreak = 0;
  DateTime? lastCompletionDate;
  Color accentColor = Colors.orange;
  bool autoCarryUnfinished = true;

  Timer? midnightTimer;

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasksBox');
    _loadPreferences().then((_) async {
      await _autoCarryUnfinishedTasksIfEnabled();
      _loadTodayTasks();
      _startMidnightTimer();
    });
  }

  @override
  void dispose() {
    midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentStreak = prefs.getInt('currentStreak') ?? 0;
      longestStreak = prefs.getInt('longestStreak') ?? 0;
      autoCarryUnfinished = prefs.getBool('autoCarryUnfinished') ?? true;

      final colorValue = prefs.getInt('accentColor');
      accentColor = colorValue != null ? Color(colorValue) : Colors.orange;

      final s = prefs.getString('lastCompletionDate');
      if (s != null) lastCompletionDate = DateTime.tryParse(s);
    });
  }

  Future<void> _autoCarryUnfinishedTasksIfEnabled() async {
    if (!autoCarryUnfinished) return;

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // find yesterday’s tasks that were not completed
    final unfinished = taskBox.values.where((t) =>
        t.date.year == yesterday.year &&
        t.date.month == yesterday.month &&
        t.date.day == yesterday.day &&
        !t.isCompleted).toList();

    // only carry if no tasks exist today yet
    final todayExists = taskBox.values.any((t) =>
        t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day);

    if (!todayExists && unfinished.isNotEmpty) {
      for (var oldTask in unfinished) {
        final newTask = Task(
          title: oldTask.title,
          durationMinutes: oldTask.durationMinutes,
          date: DateTime(now.year, now.month, now.day),
          isCompleted: false,
        );
        await taskBox.add(newTask);
      }
    }
  }

  void _loadTodayTasks() {
    final now = DateTime.now();
    todayTasks = taskBox.values.where((t) =>
        t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day).toList();

    completionList = todayTasks.map((t) => t.isCompleted).toList();
    setState(() {});
  }

  double _calculateProgress() {
    if (todayTasks.isEmpty) return 0;
    final completed = todayTasks.where((t) => t.isCompleted).length;
    return completed / todayTasks.length;
  }

  void _startMidnightTimer() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    midnightTimer = Timer(diff, () async {
      await _evaluateEndOfDay();
      _startMidnightTimer();
    });
  }

  /// Prevents streak from being updated multiple times a day
  Future<void> _evaluateEndOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // prevent multiple streak updates in the same day
    if (lastCompletionDate != null) {
      final lastDate = DateTime(
        lastCompletionDate!.year,
        lastCompletionDate!.month,
        lastCompletionDate!.day,
      );
      if (lastDate == today) {
        // already updated today
        debugPrint("⏳ Streak already updated for today.");
        return;
      }
    }

    final allDone =
        todayTasks.isNotEmpty && todayTasks.every((t) => t.isCompleted);

    // Reset streak if missed a full day
    if (lastCompletionDate != null) {
      final gap = now
          .difference(DateTime(lastCompletionDate!.year,
              lastCompletionDate!.month, lastCompletionDate!.day))
          .inDays;
      if (gap > 1) currentStreak = 0;
    }

    if (allDone) {
      currentStreak += 1;
      lastCompletionDate = now;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
        _showNewRecordPopup(longestStreak);
      } else if (currentStreak == 7 || currentStreak == 30) {
        _showMilestonePopup(currentStreak);
      }
    }

    await prefs.setInt('currentStreak', currentStreak);
    await prefs.setInt('longestStreak', longestStreak);
    if (lastCompletionDate != null) {
      await prefs.setString(
          'lastCompletionDate', lastCompletionDate!.toIso8601String());
    }

    setState(() {});
  }

  void _toggleTaskCompletion(Task task, int index, bool value) {
    task.isCompleted = value;
    task.save();
    completionList[index] = value;
    setState(() {});
    if (completionList.isNotEmpty && completionList.every((c) => c)) {
      _evaluateEndOfDay();
    }
  }

  void _showNewRecordPopup(int newRecord) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('🎉 New Record!'),
          content: Text('You set a new longest streak: $newRecord days! Keep going!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nice'),
            ),
          ],
        ),
      );
    });
  }

  void _showMilestonePopup(int days) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('🏆 Milestone!'),
          content: Text('Amazing — $days days streak! Keep it up!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Will do'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                accentColor,
                accentColor.withValues(alpha: 0.8),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Build lasting morning habits",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.emoji_events, color: accentColor),
              title: Text("Current Streak: $currentStreak"),
              subtitle: Text("Longest: $longestStreak"),
            ),
          ),
          const SizedBox(height: 12),
          const Text("Today's Progress"),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            color: accentColor,
            backgroundColor: Colors.grey[200],
          ),
          const SizedBox(height: 16),
          const Text("Today's Routine", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (int i = 0; i < todayTasks.length; i++)
            Card(
              child: ListTile(
                leading: Checkbox(
                  activeColor: accentColor,
                  value: completionList.isNotEmpty
                      ? completionList[i]
                      : todayTasks[i].isCompleted,
                  onChanged: (v) => _toggleTaskCompletion(todayTasks[i], i, v ?? false),
                ),
                title: Text(todayTasks[i].title),
                subtitle: Text("${todayTasks[i].durationMinutes} min"),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _evaluateEndOfDay,
            icon: const Icon(Icons.check),
            label: const Text("Check & Update Streak"),
          ),
          const SizedBox(height: 12),
          Card(
            color: accentColor.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Tip: Complete all tasks for the day to increase your streak. Miss a day and the streak resets next time you complete all tasks.",
              ),
            ),
          ),
        ],
      ),
    );
  }
}









// lib/screens/home_screen.dart
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/task_model.dart';
// import 'dart:async';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   late Box<Task> taskBox;
//   List<Task> todayTasks = [];
//   late List<bool> completionList;

//   int currentStreak = 0;
//   int longestStreak = 0;
//   DateTime? lastCompletionDate;

//   Timer? midnightTimer;

//   @override
//   void initState() {
//     super.initState();
//     taskBox = Hive.box<Task>('tasksBox');
//     _loadStreakData().then((_) {
//       _loadTodayTasks();
//       _startMidnightTimer();
//     });
//   }

//   @override
//   void dispose() {
//     midnightTimer?.cancel();
//     super.dispose();
//   }

//   void _loadTodayTasks() {
//     final now = DateTime.now();
//     todayTasks = taskBox.values.where((t) =>
//       t.date.year == now.year && t.date.month == now.month && t.date.day == now.day
//     ).toList();

//     completionList = todayTasks.map((t) => t.isCompleted).toList();

//     setState(() {});
//   }

//   Future<void> _loadStreakData() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       currentStreak = prefs.getInt('currentStreak') ?? 0;
//       longestStreak = prefs.getInt('longestStreak') ?? 0;
//       final s = prefs.getString('lastCompletionDate');
//       if (s != null) lastCompletionDate = DateTime.tryParse(s);
//     });
//   }

//   double _calculateProgress() {
//     if (todayTasks.isEmpty) return 0;
//     final completed = todayTasks.where((t) => t.isCompleted).length;
//     return completed / todayTasks.length;
//   }

//   void _startMidnightTimer() {
//     final now = DateTime.now();
//     final midnight = DateTime(now.year, now.month, now.day + 1);
//     final diff = midnight.difference(now);
//     midnightTimer = Timer(diff, () async {
//       await _evaluateEndOfDay();
//       _startMidnightTimer(); // reschedule for next day
//     });
//   }

//   Future<void> _evaluateEndOfDay() async {
//     final prefs = await SharedPreferences.getInstance();
//     final now = DateTime.now();

//     final allDone = todayTasks.isNotEmpty && todayTasks.every((t) => t.isCompleted);

//     // If last completion date exists, check gap
//     if (lastCompletionDate != null) {
//       final gap = now.difference(DateTime(lastCompletionDate!.year, lastCompletionDate!.month, lastCompletionDate!.day)).inDays;
//       if (gap > 1) {
//         // missed at least one full day
//         currentStreak = 0;
//       }
//     }

//     if (allDone) {
//       currentStreak += 1;
//       lastCompletionDate = now;
//       if (currentStreak > longestStreak) {
//         longestStreak = currentStreak;
//         // show new record popup
//         _showNewRecordPopup(longestStreak);
//       } else {
//         // show milestone popup for certain days
//         if (currentStreak == 7 || currentStreak == 30) {
//           _showMilestonePopup(currentStreak);
//         }
//       }
//     }

//     await prefs.setInt('currentStreak', currentStreak);
//     await prefs.setInt('longestStreak', longestStreak);
//     if (lastCompletionDate != null) {
//       await prefs.setString('lastCompletionDate', lastCompletionDate!.toIso8601String());
//     }

//     setState(() {});
//   }

//   Future<void> _manualCheckAndUpdate() async {
//     // call when user marks tasks complete manually in UI
//     await _evaluateEndOfDay();
//     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Streak updated (if applicable)")));
//   }

//   void _toggleTaskCompletion(Task task, int index, bool value) {
//     task.isCompleted = value;
//     task.save();
//     completionList[index] = value;
//     setState(() {});
//     // Optionally auto-check streak when all done
//     if (completionList.isNotEmpty && completionList.every((c) => c)) {
//       // If everything done now, update streak & possibly show popup
//       _evaluateEndOfDay();
//     }
//   }

//   void _showNewRecordPopup(int newRecord) {
//     // show dialog
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text('🎉 New Record!'),
//           content: Text('You set a new longest streak: $newRecord days! Keep going!'),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nice')),
//           ],
//         ),
//       );
//     });
//   }

//   void _showMilestonePopup(int days) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text('🏆 Milestone!'),
//           content: Text('Amazing — $days days streak! Keep the momentum.'),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Will do')),
//           ],
//         ),
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final progress = _calculateProgress();

//     return SafeArea(
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             padding: const EdgeInsets.all(16),
//             child: const Text("Build lasting morning habits", style: TextStyle(color: Colors.white, fontSize: 18)),
//           ),
//           const SizedBox(height: 12),
//           Card(
//             child: ListTile(
//               leading: const Icon(Icons.emoji_events, color: Colors.orange),
//               title: Text("Current Streak: $currentStreak"),
//               subtitle: Text("Longest: $longestStreak"),
//             ),
//           ),
//           const SizedBox(height: 12),
//           const Text("Today's Progress"),
//           const SizedBox(height: 8),
//           LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200]),
//           const SizedBox(height: 16),
//           const Text("Today's Routine", style: TextStyle(fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           for (int i = 0; i < todayTasks.length; i++)
//             Card(
//               child: ListTile(
//                 leading: Checkbox(
//                   value: completionList.isNotEmpty ? completionList[i] : todayTasks[i].isCompleted,
//                   onChanged: (v) {
//                     _toggleTaskCompletion(todayTasks[i], i, v ?? false);
//                   },
//                 ),
//                 title: Text(todayTasks[i].title),
//                 subtitle: Text("${todayTasks[i].durationMinutes} min"),
//               ),
//             ),
//           const SizedBox(height: 12),
//           ElevatedButton.icon(
//             onPressed: _manualCheckAndUpdate,
//             icon: const Icon(Icons.check),
//             label: const Text("Check & Update Streak"),
//           ),
//           const SizedBox(height: 12),
//           Card(
//             color: Theme.of(context).colorScheme.primaryContainer,
//             child: const Padding(
//               padding: EdgeInsets.all(12),
//               child: Text("Tip: Complete all tasks for the day to increase your streak. Miss a day and the streak resets next time you complete all tasks."),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../models/task_model.dart';

// // import 'package:intl/intl.dart';
// // import '../models/daily_activity.dart';
// // import '../services/hive_service.dart';
// import 'dart:async';
// // import 'package:fluttertoast/fluttertoast.dart';
// // import 'package:shared_preferences/shared_preferences.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   // Hive tasks box
//   late Box<Task> taskBox;

//   // List of tasks initialized from Hive (title + time string)
//   List<Map<String, String>> tasks = [];


//   //final streakKey = "streak";
//   int currentStreak = 0;
//   int longestStreak = 0;

//   // List to track task completion status
//   late List<bool> taskCompletion;

//   @override
//   void initState() {
//     super.initState();
//     // Load today's tasks from Hive and initialize completion status
//     taskBox = Hive.box<Task>('tasksBox');
//     final now = DateTime.now();
//     final todayTasks = taskBox.values.where((t) =>
//       t.date.year == now.year &&
//       t.date.month == now.month &&
//       t.date.day == now.day
//     ).toList();

//     tasks = todayTasks.map((t) => {
//       "title": t.title,
//       "time": "${t.durationMinutes} min",
//     }).toList();

//     taskCompletion = List<bool>.filled(tasks.length, false);
//     _scheduleEndOfDay();
//   }

//   // Calculate progress based on completed tasks
//   double _calculateProgress() {
//     if (tasks.isEmpty) return 0;
//     final completedTasks = taskCompletion.where((completed) => completed).length;
//     return completedTasks / tasks.length;
//   }

//   // Schedule end-of-day logic
//   void _scheduleEndOfDay() {
//     final now = DateTime.now();
//     final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
//     final durationUntilMidnight = midnight.difference(now);

//     Timer(durationUntilMidnight, () async {
//       // await _saveDailyActivity();
//       _scheduleEndOfDay(); // Reschedule for the next day
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             padding: const EdgeInsets.all(16),
//             child: const Text(
//               "Build lasting morning habits",
//               style: TextStyle(color: Colors.white, fontSize: 18),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           const SizedBox(height: 16),
//           const SizedBox(height: 16),
//           Card(
//             color: const Color.fromARGB(255, 131, 160, 5),
//             child: const ListTile(
//               leading: Icon(Icons.star, color: Colors.orange),
//               title: Text("Morning rituals create extraordinary days"),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Card(
//             color: const Color.fromARGB(255, 162, 91, 209),
//             child: ListTile(
//               title: Text("Current Streak: $currentStreak days in a row"),
//               subtitle: Text("Longest: $longestStreak days"),
//             ),
//           ),
//           const SizedBox(height: 16),
//           const Text("Today's Progress"),
//           const SizedBox(height: 8),
//           LinearProgressIndicator(
//             value: _calculateProgress(),
//             backgroundColor: Colors.grey[200],
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             "Today's Routine",
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 8),
//           for (int i = 0; i < tasks.length; i++)
//             Card(
//               child: ListTile(
//                 leading: Checkbox(
//                   value: taskCompletion[i],
//                   onChanged: (value) {
//                     setState(() {
//                       taskCompletion[i] = value!;
//                     });
//                   },
//                 ),
//                 title: Text(tasks[i]["title"]!),
//                 subtitle: Text(tasks[i]["time"]!),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
