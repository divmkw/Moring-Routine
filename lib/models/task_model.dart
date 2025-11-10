import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  int durationMinutes; // duration in minutes

  @HiveField(2)
  DateTime date; // the date task belongs to

  @HiveField(3)
  bool isCompleted;

  Task({
    required this.title,
    required this.durationMinutes,
    required this.date,
    this.isCompleted = false,
  });
}
