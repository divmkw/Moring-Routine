import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import 'task_page.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  RoutineScreenState createState() => RoutineScreenState();
}

class RoutineScreenState extends State<RoutineScreen> {
  late Box<Task> taskBox;
  late Box settingsBox;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasksBox');
    settingsBox = Hive.box('settings');
    _handleDailyCarryForward();
  }

  // ✅ Check and carry unfinished tasks from yesterday if enabled
  void _handleDailyCarryForward() {
    final bool autoCarry = settingsBox.get('autoCarryTasks', defaultValue: true);
    if (!autoCarry) return;

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayTasks = _tasksForDate(today);
    if (todayTasks.isNotEmpty) return;

    final prevTasks = _tasksForDate(yesterday);
    for (final t in prevTasks) {
      if (!t.isCompleted) {
        final newTask = Task(
          title: t.title,
          durationMinutes: t.durationMinutes,
          date: today,
          isCompleted: false,
        );
        taskBox.add(newTask);
      }
    }
  }

  List<Task> _tasksForDate(DateTime date) {
    return taskBox.values
        .where((task) =>
            task.date.year == date.year &&
            task.date.month == date.month &&
            task.date.day == date.day)
        .toList();
  }

  void _addTask(String title, int duration) {
    final newTask = Task(
      title: title,
      durationMinutes: duration,
      date: selectedDate,
      isCompleted: false,
    );
    taskBox.add(newTask);
    setState(() {});
  }

  void _deleteTask(Task task) {
    task.delete();
    setState(() {});
  }

  void _editTask(Task task) {
    final titleCtrl = TextEditingController(text: task.title);
    final durCtrl = TextEditingController(text: task.durationMinutes.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(
              controller: durCtrl,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final dur = int.tryParse(durCtrl.text) ?? 0;
              if (title.isNotEmpty && dur > 0) {
                task.title = title;
                task.durationMinutes = dur;
                task.save();
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final durCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(
              controller: durCtrl,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final dur = int.tryParse(durCtrl.text) ?? 0;
              if (title.isNotEmpty && dur > 0) {
                _addTask(title, dur);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalMinutes, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.9),
            accentColor.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Build lasting morning habits",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Morning Routine",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: accentColor,
                ),
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text("Add"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Total time: $totalMinutes minutes",
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = selectedDate;
    final accentColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: taskBox.listenable(),
        builder: (context, Box<Task> box, _) {
          final tasks = _tasksForDate(today);
          final totalMinutes =
              tasks.fold<int>(0, (sum, t) => sum + t.durationMinutes);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(totalMinutes, accentColor),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Today's Tasks",
                          style: Theme.of(context).textTheme.titleMedium),
                      Text("${tasks.length} items"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ Safe nested ListView
              ListView.builder(
                itemCount: tasks.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Card(
                    child: ListTile(
                      leading: Checkbox(
                        activeColor: accentColor,
                        value: task.isCompleted,
                        onChanged: (v) {
                          task.isCompleted = v ?? false;
                          task.save();
                          setState(() {});
                        },
                      ),
                      title: Text(task.title),
                      subtitle: Text("${task.durationMinutes} min"),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: Icon(Icons.edit, color: accentColor),
                            onPressed: () => _editTask(task)),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(task)),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Card(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("💡 Pro Tips",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                          "• Start with 3–5 habits\n• Keep time realistic\n• Add gradually over time"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ElevatedButton(
              //   style: ElevatedButton.styleFrom(
              //       backgroundColor: accentColor,
              //       foregroundColor: Colors.white),
              //   onPressed: () => Navigator.push(
              //       context, MaterialPageRoute(builder: (_) => const TaskPage())),
              //   child: const Text("Start Routine"),
              // ),
            ],
          );
        },
      ),
    );
  }
}