import 'package:flutter/material.dart';
import 'task_page.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  RoutineScreenState createState() => RoutineScreenState();
}

class RoutineScreenState extends State<RoutineScreen> {
  // List to hold tasks
  List<Map<String, String>> tasks = [
    {"title": "Drink Water", "time": "1 min"},
    {"title": "Stretch for 5 minutes", "time": "5 min"},
    {"title": "Meditate", "time": "10 min"},
  ];

  // Function to add a new task
  void _addTask(String title, String time) {
    setState(() {
      tasks.add({"title": title, "time": time});
    });
  }

  // Function to show the Add Task dialog
  void _showAddTaskDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Task Name",
                  hintText: "e.g., Drink water, Stretch",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: "Time Estimate (minutes)",
                  hintText: "e.g., 5",
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              // onPressed: () => Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => const TaskPage()),
              // ),
               onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final String title = titleController.text.trim();
                final String time = timeController.text.trim();
                if (title.isNotEmpty && time.isNotEmpty) {
                  _addTask(title, "$time min");
                  Navigator.pop(context);
                }
              },
              child: const Text("Add Task"),
            ),
          ],
        );
      },
    );
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Morning Routine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ElevatedButton.icon(
                onPressed: _showAddTaskDialog, // Show Add Task dialog
                icon: const Icon(Icons.add),
                label: const Text("Add Task"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Total time: ${tasks.fold<int>(0, (sum, task) => sum + int.parse(task["time"]!.split(" ")[0]))} minutes"),
          const SizedBox(height: 16),
          for (var task in tasks)
            Card(
              child: ListTile(
                leading: const Icon(Icons.drag_handle),
                title: Text(task["title"]!),
                subtitle: Text(task["time"]!),
                trailing: Wrap(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        // Add functionality for editing tasks here
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          tasks.remove(task);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            color: const Color.fromARGB(255, 68, 113, 240),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("💡 Pro Tips", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("• Drag tasks to reorder\n• Start with 3–5 habits\n• Keep time estimates realistic\n• Add gradually over time"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaskPage()),
              );
            },
            child: const Text("Start Routine"),
          ),
        ],
      ),
    );
  }
}