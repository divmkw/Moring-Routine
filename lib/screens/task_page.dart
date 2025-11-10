import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import 'package:intl/intl.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  late Box<Task> taskBox;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasksBox');
  }

  void _addTask(String title, int duration) {
    final task = Task(
      title: title,
      durationMinutes: duration,
      date: selectedDate,
    );
    taskBox.add(task);
    setState(() {});
  }

  void _toggleComplete(Task task) {
    task.isCompleted = !task.isCompleted;
    task.save();
    setState(() {});
  }

  List<Task> _tasksForDate(DateTime date) {
    return taskBox.values.where((task) =>
      task.date.year == date.year &&
      task.date.month == date.month &&
      task.date.day == date.day
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasksForDate(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Tracker'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(DateFormat('EEEE, d MMMM y').format(selectedDate)),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2026),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: taskBox.listenable(),
              builder: (context, Box<Task> box, _) {
                final tasks = _tasksForDate(selectedDate);
                if (tasks.isEmpty) {
                  return const Center(child: Text('No tasks for this date.'));
                }
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                      leading: Checkbox(
                        value: task.isCompleted,
                        onChanged: (_) => _toggleComplete(task),
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text('${task.durationMinutes} min'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddTaskDialog(context);
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final duration = int.tryParse(durationController.text) ?? 0;
              if (title.isNotEmpty && duration > 0) {
                _addTask(title, duration);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
