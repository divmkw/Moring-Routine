import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
// import 'package:timezone/timezone.dart' as tz;

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final tasksBox = Hive.box<Task>('tasksBox');
      final prefs = await SharedPreferences.getInstance();

      // Collect tasks
      final tasks = tasksBox.values.map((t) => {
            'title': t.title,
            'durationMinutes': t.durationMinutes,
            'date': t.date.toIso8601String(),
            'isCompleted': t.isCompleted,
          }).toList();

      // Collect settings
      final settings = {
        'currentStreak': prefs.getInt('currentStreak') ?? 0,
        'longestStreak': prefs.getInt('longestStreak') ?? 0,
        'lastCompletionDate': prefs.getString('lastCompletionDate'),
        'accentColor': prefs.getInt('accentColor'),
        'autoCarryUnfinished': prefs.getBool('autoCarryUnfinished') ?? true,
        'isDarkMode': prefs.getBool('isDarkMode') ?? false,
      };

      final backup = {
        'tasks': tasks,
        'settings': settings,
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/morning_routine_backup.json');
      await file.writeAsString(jsonEncode(backup));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Backup exported to ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Backup export failed: $e')),
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

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      final tasksBox = Hive.box<Task>('tasksBox');
      final prefs = await SharedPreferences.getInstance();

      // Clear existing
      await tasksBox.clear();

      // Restore tasks
      for (var item in data['tasks']) {
        final task = Task(
          title: item['title'],
          durationMinutes: item['durationMinutes'],
          date: DateTime.parse(item['date']),
          isCompleted: item['isCompleted'],
        );
        await tasksBox.add(task);
      }

      // Restore settings
      final s = data['settings'];
      await prefs.setInt('currentStreak', s['currentStreak'] ?? 0);
      await prefs.setInt('longestStreak', s['longestStreak'] ?? 0);
      if (s['lastCompletionDate'] != null) {
        await prefs.setString('lastCompletionDate', s['lastCompletionDate']);
      }
      if (s['accentColor'] != null) {
        await prefs.setInt('accentColor', s['accentColor']);
      }
      await prefs.setBool('autoCarryUnfinished', s['autoCarryUnfinished'] ?? true);
      await prefs.setBool('isDarkMode', s['isDarkMode'] ?? false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Backup imported successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Backup import failed: $e')),
      );
    }
  }

  Future<void> _resetData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Confirm Reset'),
        content: const Text(
            'This will delete all tasks and reset settings. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, reset')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final tasksBox = Hive.box<Task>('tasksBox');
      final prefs = await SharedPreferences.getInstance();

      await tasksBox.clear();
      await prefs.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ All data reset successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to reset data: $e')),
      );
    }
  }

  Future<void> _loadSettings() async {
    settingsBox = await Hive.openBox('settings');
    setState(() {
      _isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);
      _dailyReminder = settingsBox.get('dailyReminder', defaultValue: false);
      _persistTasks = settingsBox.get('persistTasks', defaultValue: true);
      _accentColor = Color(settingsBox.get('accentColor', defaultValue: Colors.lightGreen.value));
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
    await settingsBox.put('accentColor', _accentColor.toARGB32());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Settings saved successfully!"),
        duration: const Duration(seconds: 2),
        backgroundColor: _accentColor,
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
      await _saveSettings();
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
      builder: (ctx) => AlertDialog(
        title: const Text("Select Accent Color"),
        content: Wrap(
          spacing: 10,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() => _accentColor = color);
                widget.onThemeChanged(_isDarkMode, color);
                Navigator.pop(ctx);
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

  void _toggleTheme(bool isDark) async {
    setState(() => _isDarkMode = isDark);
    widget.onThemeChanged(isDark, _accentColor);
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🌅 Header Card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor.withValues(alpha: 0.8), Colors.orangeAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Build lasting morning habits",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // 🕐 Reminder Settings
          _buildSectionHeader("Reminders", Icons.alarm),
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
            onChanged: (val) {
              setState(() => _dailyReminder = val);
              _saveSettings();
            },
          ),
          const SizedBox(height: 8),

          // 🎨 Appearance
          _buildSectionHeader("Appearance", Icons.palette),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_isDarkMode ? _accentColor.withValues(alpha: 0.3) : null,
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
                    backgroundColor: _isDarkMode ? _accentColor.withValues(alpha: 0.3) : null,
                  ),
                  onPressed: () => _toggleTheme(true),
                  icon: const Icon(Icons.dark_mode),
                  label: const Text("Dark"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text("Accent Color"),
            trailing: CircleAvatar(backgroundColor: _accentColor),
            onTap: _pickAccentColor,
          ),
          const SizedBox(height: 8),

          // ♻️ Task Persistence
          _buildSectionHeader("Routine Behavior", Icons.repeat),
          SwitchListTile(
            title: const Text("Persist Tasks to Next Day"),
            subtitle: const Text("Keep unfinished tasks for the next day automatically."),
            value: _persistTasks,
            onChanged: (val) {
              setState(() => _persistTasks = val);
              _saveSettings();
            },
          ),
          const SizedBox(height: 8),

          // 💾 Data Management
          _buildSectionHeader("Data Management", Icons.storage),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => _resetData(context),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Reset All Data"),
          ),

        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}