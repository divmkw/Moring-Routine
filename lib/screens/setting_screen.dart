import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();


class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const SettingsScreen({super.key,context, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminder = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  bool _isDarkMode = false;
  //Function(bool) onThemeChanged();
  // onThemeChanged(true);

  dynamic onThemeChanged(bool isDarkMode) {
    widget.onThemeChanged(isDarkMode);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _dailyReminder = prefs.getBool('dailyReminder') ?? false;
      final hour = prefs.getInt('reminderHour') ?? 7;
      final minute = prefs.getInt('reminderMinute') ?? 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setBool('dailyReminder', _dailyReminder);
    await prefs.setInt('reminderHour', _selectedTime.hour);
    await prefs.setInt('reminderMinute', _selectedTime.minute);

    if (_dailyReminder) {
      await scheduleDailyNotification(_selectedTime);
    } else {
      await cancelDailyNotification();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
      content: Text("Settings saved"),
      duration: Duration(seconds: 2),
      backgroundColor: Colors.blue
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> scheduleDailyNotification(TimeOfDay time) async {
  final now = tz.TZDateTime.now(tz.local);
  var scheduledDate = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    time.hour,
    time.minute,
  );

  if (scheduledDate.isBefore(now)) {// If the scheduled time is before now, schedule for the next day
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }

  // Cancel any previous scheduled notification with the same id first
  await flutterLocalNotificationsPlugin.cancel(0);

  // Optionally inspect pending notifications (debug)
  final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  debugPrint('Pending notifications: ${pending.length}');

  await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification',
      'If you see this, notifications are working!',
      const NotificationDetails(
        android: AndroidNotificationDetails('test_channel', 'Test Channel'),
        iOS: DarwinNotificationDetails(),   
      )
  );

  // Request permissions if not already granted
// final androidInfo = await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestPermission();

// final iosInfo = await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);

Future<void> requestNotificationPermissions() async {
  // Android permissions
  if (Theme.of(context).platform == TargetPlatform.android) {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      debugPrint("Notification permission granted");
    } else {
      debugPrint("Notification permission denied");
    }
  }

  // iOS permissions
  final iosImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  await iosImplementation?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
}

  // requestNotificationPermissions();
  // Then schedule
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Morning Routine Reminder',
    'Good morning! Time to start your day 🌅',
    scheduledDate,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder_channel',
        'Daily Reminder',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
  }

  Future<void> cancelDailyNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> _applyTheme(bool isDark) async {
      setState(() => _isDarkMode = isDark);
      widget.onThemeChanged(isDark);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
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
            title: const Text("Daily Reminders"),
            value: _dailyReminder,
            onChanged: (value) {
              setState(() {
                _dailyReminder = value;
              });
            },
          ),
          const Text("Theme"),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_isDarkMode ? Colors.lightGreen : null,
                  ),
                  onPressed: () => _applyTheme(false),
                  icon: const Icon(Icons.light_mode),
                  label: const Text("Light"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isDarkMode ? Colors.lightGreen : null,
                  ),
                  onPressed: () => _applyTheme(true),
                  icon: const Icon(Icons.dark_mode),
                  label: const Text("Dark"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveSettings,
            child: const Text("Save Settings"),
          ),
          const SizedBox(height: 24),
          const Text("Data Management"),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.file_download),
            label: const Text("Export Backup"),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.file_upload),
            label: const Text("Import Backup"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {},
            icon: const Icon(Icons.delete),
            label: const Text("Reset All Data"),
          ),
        ],
      ),
    );
  }
}