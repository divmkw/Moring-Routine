// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool isDarkMode, Color accentColor) onThemeChanged;
  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box settingsBox;
  bool _isDarkMode = false;
  bool _dailyReminder = false;
  bool _persistTasks = true;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  Color _accentColor = Colors.lightGreen;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications().then((_) {
      _loadSettings();
      _requestPermissions();
    });
  }

  // -----------------------------------------------------------
  // 🔔 INIT NOTIFICATIONS
  // -----------------------------------------------------------
  Future<void> _initNotifications() async {
    tz.initializeTimeZones();

    // Fallback to a known timezone
    tz.setLocalLocation(tz.getLocation("Asia/Kolkata"));

    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notify');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _requestPermissions() async {
    // iOS
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // -----------------------------------------------------------
  // 🔔 TEST NOTIFICATION
  // -----------------------------------------------------------
  Future<void> _showTestNotification() async {
    const android = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notify',
    );

    const ios = DarwinNotificationDetails();

    const details = NotificationDetails(android: android, iOS: ios);

    await _flutterLocalNotificationsPlugin.show(
      999,
      '🔔 Test Notification',
      'Your notification system is working!',
      details,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("📨 Test notification sent!")),
    );
  }

  // -----------------------------------------------------------
  // ⏰ DAILY REMINDER LOGIC
  // -----------------------------------------------------------
  tz.TZDateTime _nextInstance(TimeOfDay t) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      t.hour,
      t.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _scheduleDailyReminder(TimeOfDay t) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Your Morning Routine Awaits!',
      'Time to start your day strong 💪',
      _nextInstance(t),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel_id',
          'Daily Reminders',
          channelDescription: 'Daily routine reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notify',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Reminder set for ${t.format(context)}")),
    );
  }

  Future<void> _cancelReminder({bool show = true}) async {
    await _flutterLocalNotificationsPlugin.cancel(0);
    if (show) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Reminder cancelled")),
      );
    }
  }

  // -----------------------------------------------------------
  // 💾 BACKUP / RESTORE
  // -----------------------------------------------------------
  Future<void> _exportBackup(BuildContext context) async {
    try {
      final tasksBox = Hive.box<Task>('tasksBox');
      final prefs = await SharedPreferences.getInstance();
      final settingsBox = Hive.box('settings');

      final tasks = tasksBox.values
          .map((t) => {
                'title': t.title,
                'durationMinutes': t.durationMinutes,
                'date': t.date.toIso8601String(),
                'isCompleted': t.isCompleted,
              })
          .toList();

      final settings = {
        'currentStreak': prefs.getInt('currentStreak') ?? 0,
        'longestStreak': prefs.getInt('longestStreak') ?? 0,
        'lastCompletionDate': prefs.getString('lastCompletionDate'),
        'accentColor': settingsBox.get('accentColor'),
        'persistTasks': settingsBox.get('persistTasks'),
        'isDarkMode': settingsBox.get('isDarkMode'),
        'dailyReminder': settingsBox.get('dailyReminder'),
        'reminderHour': settingsBox.get('reminderHour'),
        'reminderMinute': settingsBox.get('reminderMinute'),
      };

      final backup = {'tasks': tasks, 'settings': settings};

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          "${dir.path}/morning_routine_backup_${DateTime.now().toIso8601String().split('T').first}.json");

      await file.writeAsString(jsonEncode(backup));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Backup exported to ${file.path}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Backup failed: $e")),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return;

      final data = jsonDecode(await File(result.files.single.path!).readAsString());
      final tasksBox = Hive.box<Task>('tasksBox');
      final prefs = await SharedPreferences.getInstance();
      final settingsBox = Hive.box('settings');

      await tasksBox.clear();
      await settingsBox.clear();

      for (var item in data['tasks']) {
        tasksBox.add(Task(
          title: item['title'],
          durationMinutes: item['durationMinutes'],
          date: DateTime.parse(item['date']),
          isCompleted: item['isCompleted'],
        ));
      }

      final s = data['settings'];

      await prefs.setInt('currentStreak', s['currentStreak'] ?? 0);
      await prefs.setInt('longestStreak', s['longestStreak'] ?? 0);
      if (s['lastCompletionDate'] != null) {
        await prefs.setString('lastCompletionDate', s['lastCompletionDate']);
      }

      await settingsBox.put('accentColor', s['accentColor']);
      await settingsBox.put('persistTasks', s['persistTasks']);
      await settingsBox.put('isDarkMode', s['isDarkMode']);
      await settingsBox.put('dailyReminder', s['dailyReminder']);
      await settingsBox.put('reminderHour', s['reminderHour']);
      await settingsBox.put('reminderMinute', s['reminderMinute']);

      await _loadSettings();
      widget.onThemeChanged(_isDarkMode, _accentColor);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Backup imported successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Import failed: $e")),
      );
    }
  }

  Future<void> _resetData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚠️ Confirm Reset"),
        content: const Text("This will delete all tasks & settings."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Reset")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Hive.box<Task>('tasksBox').clear();
      await Hive.box('settings').clear();
      await SharedPreferences.getInstance().then((prefs) => prefs.clear());
      await _cancelReminder(show: false);

      _loadSettings();
      widget.onThemeChanged(_isDarkMode, _accentColor);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ App reset successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Reset failed: $e")),
      );
    }
  }

  // -----------------------------------------------------------
  // ⚙️ SETTINGS
  // -----------------------------------------------------------
  Future<void> _loadSettings() async {
    settingsBox = await Hive.openBox('settings');

    setState(() {
      _isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);
      _dailyReminder = settingsBox.get('dailyReminder', defaultValue: false);
      _persistTasks = settingsBox.get('persistTasks', defaultValue: true);

      _accentColor = Color(
        settingsBox.get('accentColor', defaultValue: Colors.lightGreen.value),
      );

      final hour = settingsBox.get('reminderHour', defaultValue: 7);
      final minute = settingsBox.get('reminderMinute', defaultValue: 0);
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveSettings() async {
    await settingsBox.put('isDarkMode', _isDarkMode);
    await settingsBox.put('dailyReminder', _dailyReminder);
    await settingsBox.put('persistTasks', _persistTasks);
    await settingsBox.put('reminderHour', _selectedTime.hour);
    await settingsBox.put('reminderMinute', _selectedTime.minute);
    await settingsBox.put('accentColor', _accentColor.value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text("Settings saved"), backgroundColor: _accentColor),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
      await _saveSettings();

      if (_dailyReminder) {
        await _cancelReminder(show: false);
        await _scheduleDailyReminder(_selectedTime);
      }
    }
  }

  Future<void> _pickAccentColor() async {
    final colors = [
      Colors.lightGreen,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.blue,
    ];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Accent Color"),
        content: Wrap(
          spacing: 10,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() => _accentColor = color);
                widget.onThemeChanged(_isDarkMode, color);
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundColor: color,
                radius: 20,
                child: _accentColor == color
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );

    await _saveSettings();
  }

  void _toggleTheme(bool dark) async {
    setState(() => _isDarkMode = dark);
    widget.onThemeChanged(dark, _accentColor);
    await _saveSettings();
  }

  // -----------------------------------------------------------
  // UI
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor.withAlpha(200), Colors.orangeAccent],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "Build lasting morning habits",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          _section("Reminders", Icons.alarm),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text("Morning Start Time"),
            subtitle: Text(_selectedTime.format(context)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _pickTime,
            ),
          ),

          SwitchListTile(
            title: const Text("Daily Reminder"),
            value: _dailyReminder,
            onChanged: (val) async {
              setState(() => _dailyReminder = val);
              await _saveSettings();

              if (val) {
                await _scheduleDailyReminder(_selectedTime);
              } else {
                await _cancelReminder();
              }
            },
          ),

          // ElevatedButton.icon(
          //   onPressed: _showTestNotification,
          //   icon: const Icon(Icons.notifications_active),
          //   label: const Text("Send Test Notification"),
          // ),

          _section("Appearance", Icons.palette),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_isDarkMode ? _accentColor.withAlpha(80) : null,
                  ),
                  onPressed: () => _toggleTheme(false),
                  icon: const Icon(Icons.light_mode),
                  label: const Text("Light"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isDarkMode ? _accentColor.withAlpha(80) : null,
                  ),
                  onPressed: () => _toggleTheme(true),
                  icon: const Icon(Icons.dark_mode),
                  label: const Text("Dark"),
                ),
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text("Accent Color"),
            trailing: CircleAvatar(backgroundColor: _accentColor),
            onTap: _pickAccentColor,
          ),

          _section("Routine Behavior", Icons.repeat),
          SwitchListTile(
            title: const Text("Persist Tasks"),
            subtitle: const Text("Keep unfinished tasks for next day"),
            value: _persistTasks,
            onChanged: (v) {
              setState(() => _persistTasks = v);
              _saveSettings();
            },
          ),

          _section("Data Management", Icons.storage),
          ElevatedButton.icon(
            onPressed: () => _exportBackup(context),
            icon: const Icon(Icons.file_download),
            label: const Text("Export Backup"),
          ),
          ElevatedButton.icon(
            onPressed: () => _importBackup(context),
            icon: const Icon(Icons.file_upload),
            label: const Text("Import Backup"),
          ),
          ElevatedButton.icon(
            onPressed: () => _resetData(context),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Reset All Data"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _accentColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}












// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'dart:io';
// import 'dart:convert';
// import 'package:path_provider/path_provider.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// // Import notification and timezone packages
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest.dart' as tz;
// import 'package:timezone/timezone.dart' as tz;
// // import 'package:flutter_native_timezone_updated/flutter_native_timezone.dart';

// import '../models/task_model.dart';

// class SettingsScreen extends StatefulWidget {
//   final Function(bool isDarkMode, Color accentColor) onThemeChanged;
//   const SettingsScreen({super.key, required this.onThemeChanged});

//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends State<SettingsScreen> {
//   late Box settingsBox;
//   bool _isDarkMode = false;
//   bool _dailyReminder = false;
//   bool _persistTasks = true;
//   TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
//   Color _accentColor = Colors.lightGreen;

//   // Notification plugin instance
//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   @override
//   void initState() {
//     super.initState();
//     // Initialize notifications first
//     _initNotifications().then((_) {
//       // Then load settings
//       _loadSettings();
//       // Request permissions (will only prompt on first run)
//       _requestPermissions();
//     });
//   }

//   // -------------------------------------------------------------------
//   // 🔔 Notification Logic
//   // -------------------------------------------------------------------

//   Future<void> _initNotifications() async {
//     // Initialize timezone database
//     tz.initializeTimeZones();

//     // Automatically assign device local timezone
//     final String localName = DateTime.now().timeZoneName;
//     try {
//       tz.setLocalLocation(tz.getLocation(localName));
//     } catch (_) {
//       // If timezoneName is like "IST" (not in tz database), fallback to offset-based zone.
//       final now = DateTime.now();
//       final offset = now.timeZoneOffset;
//       tz.setLocalLocation(
//         tz.getLocation(
//           offset.isNegative
//               ? 'Etc/GMT+${offset.inHours.abs()}'
//               : 'Etc/GMT-${offset.inHours.abs()}',
//         ),
//       );
//     }

//     // ANDROID initialization
//     const AndroidInitializationSettings androidInitSettings =
//         AndroidInitializationSettings('ic_launcher');

//     // iOS initialization
//     const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
//       requestAlertPermission: false,
//       requestBadgePermission: false,
//       requestSoundPermission: false,
//     );

//     const InitializationSettings settings = InitializationSettings(
//       android: androidInitSettings,
//       iOS: iosInitSettings,
//     );

//     await _flutterLocalNotificationsPlugin.initialize(settings);
//   }

//   Future<void> _showTestNotification() async { //for testing
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//       'daily_reminder_channel_id',
//       'Daily Reminders',
//       channelDescription: 'Test notification channel',
//       importance: Importance.max,
//       priority: Priority.high,
//       playSound: true,
//     );

//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );

//     const NotificationDetails details =
//         NotificationDetails(android: androidDetails, iOS: iosDetails);

//     await _flutterLocalNotificationsPlugin.show(
//       999, // test notification id
//       '🔔 Test Notification',
//       'Your notification system is working!',
//       details,
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("📨 Test notification sent!")),
//     );
//   }


//   Future<void> _requestPermissions() async {
//     // Request iOS permissions
//     await _flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//             IOSFlutterLocalNotificationsPlugin>()
//         ?.requestPermissions(
//           alert: true,
//           badge: true,
//           sound: true,
//         );

//     // Request Android 13+ permissions
//     await _flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>()
//         ?.requestNotificationsPermission(); // <-- This is the corrected line
//   }

//   /// Calculates the next instance of the selected time.
//   tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
//     final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
//     tz.TZDateTime scheduledDate = tz.TZDateTime(
//         tz.local, now.year, now.month, now.day, time.hour, time.minute);
    
//     // If the scheduled time is in the past, schedule it for the next day
//     if (scheduledDate.isBefore(now)) {
//       scheduledDate = scheduledDate.add(const Duration(days: 1));
//     }
//     return scheduledDate;
//   }

//   Future<void> _scheduleDailyReminder(TimeOfDay time) async {
//     try {
//       await _flutterLocalNotificationsPlugin.zonedSchedule(
//         0, // Notification ID
//         'Your Morning Routine Awaits!',
//         'Time to start your day strong. 💪',
//         _nextInstanceOfTime(time),
//         const NotificationDetails(
//           android: AndroidNotificationDetails(
//             'daily_reminder_channel_id',
//             'Daily Reminders',
//             channelDescription: 'Channel for daily morning routine reminders',
//             importance: Importance.max,
//             priority: Priority.high,
//           ),
//           iOS: DarwinNotificationDetails(
//             sound: 'default.wav',
//             presentAlert: true,
//             presentBadge: true,
//             presentSound: true,
//           ),
//         ),
//         // This is crucial for daily repeats
//         matchDateTimeComponents: DateTimeComponents.time,
//         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//         uiLocalNotificationDateInterpretation:
//             UILocalNotificationDateInterpretation.absoluteTime,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text('✅ Reminder set for ${_selectedTime.format(context)} daily.')),
//       );
//     } catch (e) {
//        ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Failed to set reminder: $e')),
//       );
//     }
//   }

//   Future<void> _cancelDailyReminder({bool showSnackbar = true}) async {
//     await _flutterLocalNotificationsPlugin.cancel(0); // Cancel by ID
    
//     // Check if the confirmation snackbar should be displayed
//     if (showSnackbar) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('❌ Reminder canceled.')),
//       );
//     }
//   }

//   // Future<void> _cancelDailyReminder() async {
//   //   await _flutterLocalNotificationsPlugin.cancel(0); // Cancel by ID
//   //   ScaffoldMessenger.of(context).showSnackBar(
//   //     const SnackBar(content: Text('❌ Reminder canceled.')),
//   //   );
//   // }

//   // -------------------------------------------------------------------
//   // 💾 Data Management Logic (FIXED)
//   // -------------------------------------------------------------------

//   Future<void> _exportBackup(BuildContext context) async {
//     try {
//       final tasksBox = Hive.box<Task>('tasksBox');
//       final prefs = await SharedPreferences.getInstance();
//       // **FIX: Read from settingsBox, not prefs**
//       final settingsBox = Hive.box('settings'); 

//       // Collect tasks
//       final tasks = tasksBox.values
//           .map((t) => {
//                 'title': t.title,
//                 'durationMinutes': t.durationMinutes,
//                 'date': t.date.toIso8601String(),
//                 'isCompleted': t.isCompleted,
//               })
//           .toList();

//       // Collect settings
//       final settings = {
//         // Streak data from SharedPreferences
//         'currentStreak': prefs.getInt('currentStreak') ?? 0,
//         'longestStreak': prefs.getInt('longestStreak') ?? 0,
//         'lastCompletionDate': prefs.getString('lastCompletionDate'),

//         // App settings from Hive 'settings' box
//         'accentColor': settingsBox.get('accentColor'),
//         'persistTasks': settingsBox.get('persistTasks'),
//         'isDarkMode': settingsBox.get('isDarkMode'),
//         'dailyReminder': settingsBox.get('dailyReminder'),
//         'reminderHour': settingsBox.get('reminderHour'),
//         'reminderMinute': settingsBox.get('reminderMinute'),
//       };

//       final backup = {
//         'tasks': tasks,
//         'settings': settings,
//       };

//       // **FIX: Changed default path to be more robust**
//       final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
//       final String fileName = 'morning_routine_backup_${DateTime.now().toIso8601String().split('T').first}.json';
//       final file = File('${dir.path}/$fileName');
//       await file.writeAsString(jsonEncode(backup));

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('✅ Backup exported to ${file.path}')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Backup export failed: $e')),
//       );
//     }
//   }

//   Future<void> _importBackup(BuildContext context) async {
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['json'],
//       );
//       if (result == null) return;

//       final file = File(result.files.single.path!);
//       final content = await file.readAsString();
//       final data = jsonDecode(content);

//       final tasksBox = Hive.box<Task>('tasksBox');
//       final prefs = await SharedPreferences.getInstance();
//       // **FIX: Get settingsBox**
//       final settingsBox = Hive.box('settings');

//       // Clear existing
//       await tasksBox.clear();
//       // **FIX: Clear settingsBox too**
//       await settingsBox.clear(); 
//       // Note: We don't clear all prefs, just the ones we're restoring
      
//       // Restore tasks
//       for (var item in data['tasks']) {
//         final task = Task(
//           title: item['title'],
//           durationMinutes: item['durationMinutes'],
//           date: DateTime.parse(item['date']),
//           isCompleted: item['isCompleted'],
//         );
//         await tasksBox.add(task);
//       }

//       // Restore settings
//       final s = data['settings'];
      
//       // Restore streak to SharedPreferences
//       await prefs.setInt('currentStreak', s['currentStreak'] ?? 0);
//       await prefs.setInt('longestStreak', s['longestStreak'] ?? 0);
//       if (s['lastCompletionDate'] != null) {
//         await prefs.setString('lastCompletionDate', s['lastCompletionDate']);
//       }
      
//       // **FIX: Restore app settings to Hive 'settings' box**
//       if (s['accentColor'] != null) {
//         await settingsBox.put('accentColor', s['accentColor']);
//       }
//       await settingsBox.put('persistTasks', s['persistTasks'] ?? true);
//       await settingsBox.put('isDarkMode', s['isDarkMode'] ?? false);
//       await settingsBox.put('dailyReminder', s['dailyReminder'] ?? false);
//       await settingsBox.put('reminderHour', s['reminderHour'] ?? 7);
//       await settingsBox.put('reminderMinute', s['reminderMinute'] ?? 0);


//       // **FIX: Reload settings into UI and update theme**
//       await _loadSettings();
//       widget.onThemeChanged(_isDarkMode, _accentColor);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('✅ Backup imported successfully! Refresh app.')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Backup import failed: $e')),
//       );
//     }
//   }

//   Future<void> _resetData(BuildContext context) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('⚠️ Confirm Reset'),
//         content: const Text(
//             'This will delete all tasks and reset settings. Continue?'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
//           TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, reset')),
//         ],
//       ),
//     );

//     if (confirmed != true) return;

//     try {
//       final tasksBox = Hive.box<Task>('tasksBox');
//       final prefs = await SharedPreferences.getInstance();
//       // **FIX: Get settingsBox**
//       final settingsBox = Hive.box('settings');

//       await tasksBox.clear();
//       await prefs.clear();
//       // **FIX: Clear settingsBox**
//       await settingsBox.clear();

//       // **FIX: Cancel any active reminders**
//       await _cancelDailyReminder();

//       // **FIX: Reload settings to reset UI to defaults**
//       await _loadSettings();
//       widget.onThemeChanged(_isDarkMode, _accentColor);


//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('✅ All data reset successfully.')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Failed to reset data: $e')),
//       );
//     }
//   }

//   // -------------------------------------------------------------------
//   // ⚙️ Settings Load/Save (FIXED)
//   // -------------------------------------------------------------------

//   Future<void> _loadSettings() async {
//     settingsBox = await Hive.openBox('settings');
//     setState(() {
//       _isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);
//       _dailyReminder = settingsBox.get('dailyReminder', defaultValue: false);
//       _persistTasks = settingsBox.get('persistTasks', defaultValue: true);
//       // **FIX: Load color .value (int) and provide a .value default**
//       _accentColor = Color(settingsBox.get('accentColor', defaultValue: Colors.lightGreen.value));
//       final hour = settingsBox.get('reminderHour', defaultValue: 7);
//       final minute = settingsBox.get('reminderMinute', defaultValue: 0);
//       _selectedTime = TimeOfDay(hour: hour, minute: minute);
//     });
//   }

//   Future<void> _saveSettings() async {
//     await settingsBox.put('isDarkMode', _isDarkMode);
//     await settingsBox.put('dailyReminder', _dailyReminder);
//     await settingsBox.put('persistTasks', _persistTasks);
//     await settingsBox.put('reminderHour', _selectedTime.hour);
//     await settingsBox.put('reminderMinute', _selectedTime.minute);
//     // **FIX: Save color .value (int) instead of the Color object**
//     await settingsBox.put('accentColor', _accentColor.value); 

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text("Settings saved successfully!"),
//         duration: const Duration(seconds: 2),
//         backgroundColor: _accentColor,
//       ),
//     );
//   }

//   Future<void> _pickTime() async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: _selectedTime,
//     );
//     if (picked != null) {
//       setState(() {
//         _selectedTime = picked;
//       });
//       await _saveSettings();

//       // **UPDATE: If reminder is on, update the schedule**
//       if (_dailyReminder) {
//         // Pass false so it doesn't show the "Canceled" snackbar
//         await _cancelDailyReminder(showSnackbar: false); 
//         await _scheduleDailyReminder(_selectedTime);
//       }
//     }
//   }

//   Future<void> _pickAccentColor() async {
//     final colors = [
//       Colors.lightGreen,
//       Colors.teal,
//       Colors.orange,
//       Colors.purple,
//       Colors.pink,
//       Colors.blue,
//     ];

//     await showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Select Accent Color"),
//         content: Wrap(
//           spacing: 10,
//           children: colors.map((color) {
//             return GestureDetector(
//               onTap: () {
//                 setState(() => _accentColor = color);
//                 widget.onThemeChanged(_isDarkMode, color);
//                 Navigator.pop(ctx);
//               },
//               child: CircleAvatar(
//                 backgroundColor: color,
//                 radius: 20,
//                 child: _accentColor == color
//                     ? const Icon(Icons.check, color: Colors.white)
//                     : null,
//               ),
//             );
//           }).toList(),
//         ),
//       ),
//     );

//     await _saveSettings();
//   }

//   void _toggleTheme(bool isDark) async {
//     setState(() => _isDarkMode = isDark);
//     widget.onThemeChanged(isDark, _accentColor);
//     await _saveSettings();
//   }

//   // -------------------------------------------------------------------
//   // 📱 Build Method (Updated Reminder Switch)
//   // -------------------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // 🌅 Header Card
//           Container(
//             decoration: BoxDecoration(
//               // **FIX: Use .withAlpha(204) instead of .withValues()**
//               gradient: LinearGradient(
//                 colors: [_accentColor.withAlpha(204), Colors.orangeAccent],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             padding: const EdgeInsets.all(16),
//             child: const Text(
//               "Build lasting morning habits",
//               style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           const SizedBox(height: 16),

//           // 🕐 Reminder Settings
//           _buildSectionHeader("Reminders", Icons.alarm),
//           ListTile(
//             leading: const Icon(Icons.access_time),
//             title: const Text("Morning Start Time"),
//             subtitle: Text(_selectedTime.format(context)),
//             trailing: IconButton(
//               icon: const Icon(Icons.edit),
//               onPressed: _pickTime,
//             ),
//           ),
//           SwitchListTile(
//             title: const Text("Daily Reminder"),
//             value: _dailyReminder,
//             // **UPDATE: Handle scheduling/canceling notifications**
//             onChanged: (val) async {
//               setState(() => _dailyReminder = val);
//               await _saveSettings(); // Save the setting
//               if (val) {
//                 // If turned ON, schedule the notification
//                 await _scheduleDailyReminder(_selectedTime);
//               } else {
//                 // If turned OFF, cancel the notification
//                 await _cancelDailyReminder();
//               }
//             },
//           ),
//           const SizedBox(height: 8),
//           // for testing
//           ElevatedButton.icon(
//             onPressed: _showTestNotification,
//             icon: const Icon(Icons.notifications_active),
//             label: const Text("Send Test Notification"),
//           ),


//           // 🎨 Appearance
//           _buildSectionHeader("Appearance", Icons.palette),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   style: OutlinedButton.styleFrom(
//                     // **FIX: Use .withAlpha(77) for 30% opacity**
//                     backgroundColor: !_isDarkMode ? _accentColor.withAlpha(77) : null,
//                   ),
//                   onPressed: () => _toggleTheme(false),
//                   icon: const Icon(Icons.light_mode),
//                   label: const Text("Light"),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   style: OutlinedButton.styleFrom(
//                     backgroundColor: _isDarkMode ? _accentColor.withAlpha(77) : null,
//                   ),
//                   onPressed: () => _toggleTheme(true),
//                   icon: const Icon(Icons.dark_mode),
//                   label: const Text("Dark"),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ListTile(
//             leading: const Icon(Icons.color_lens),
//             title: const Text("Accent Color"),
//             trailing: CircleAvatar(backgroundColor: _accentColor),
//             onTap: _pickAccentColor,
//           ),
//           const SizedBox(height: 8),

//           // ♻️ Task Persistence
//           _buildSectionHeader("Routine Behavior", Icons.repeat),
//           SwitchListTile(
//             title: const Text("Persist Tasks to Next Day"),
//             subtitle: const Text("Keep unfinished tasks for the next day automatically."),
//             value: _persistTasks,
//             onChanged: (val) {
//               setState(() => _persistTasks = val);
//               _saveSettings();
//             },
//           ),
//           const SizedBox(height: 8),

//           // 💾 Data Management
//           _buildSectionHeader("Data Management", Icons.storage),
//           ElevatedButton.icon(
//             onPressed: () => _exportBackup(context),
//             icon: const Icon(Icons.file_download),
//             label: const Text("Export Backup"),
//           ),
//           ElevatedButton.icon(
//             onPressed: () => _importBackup(context),
//             icon: const Icon(Icons.file_upload),
//             label: const Text("Import Backup"),
//           ),
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
//             onPressed: () => _resetData(context),
//             icon: const Icon(Icons.delete_forever),
//             label: const Text("Reset All Data"),
//           ),

//         ],
//       ),
//     );
//   }

//   Widget _buildSectionHeader(String title, IconData icon) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         children: [
//           Icon(icon, color: _accentColor),
//           const SizedBox(width: 8),
//           Text(
//             title,
//             style: TextStyle(
//               color: _accentColor,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }