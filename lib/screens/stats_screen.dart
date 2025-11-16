import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import 'dart:math' as math;

class StatsPage extends StatefulWidget {
  final Color accentColor;
  const StatsPage({super.key, required this.accentColor});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<String>> _events = {};
  int totalRoutines = 0;
  double completionRate = 0;
  int currentStreak = 0;
  int longestStreak = 0;

  bool firstDay = false;
  bool weekWarrior = false;
  bool perfectMonth = false;
  bool consistencyKing = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadStatsData();
  }

  Future<void> _loadStatsData() async {
    final taskBox = Hive.box<Task>('tasksBox');
    final prefs = await SharedPreferences.getInstance();

    // Load streak data
    currentStreak = prefs.getInt('currentStreak') ?? 0;
    longestStreak = prefs.getInt('longestStreak') ?? 0;

    // Group tasks by date
    Map<DateTime, List<Task>> grouped = {};
    for (var t in taskBox.values) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(d, () => []).add(t);
    }

    // Build events + stats
    int completedDays = 0;
    int totalDays = grouped.keys.length;
    int totalTasks = 0;
    int totalCompleted = 0;

    Map<DateTime, List<String>> events = {};

    grouped.forEach((date, tasks) {
      bool allCompleted = tasks.every((t) => t.isCompleted);
      bool anyCompleted = tasks.any((t) => t.isCompleted);
      totalTasks += tasks.length;
      totalCompleted += tasks.where((t) => t.isCompleted).length;

      if (allCompleted) {
        completedDays++;
        events[date] = ['Completed All'];
      } else if (anyCompleted) {
        events[date] = ['Partially Completed'];
      } else {
        events[date] = ['Missed'];
      }
    });

    double compRate =
        totalTasks > 0 ? totalCompleted / totalTasks : 0.0;

    // Determine achievements
    firstDay = totalDays > 0;
    weekWarrior = longestStreak >= 7;
    perfectMonth = longestStreak >= 30;
    consistencyKing = compRate >= 0.8;

    setState(() {
      _events = events;
      completionRate = compRate;
      totalRoutines = totalTasks;
    });
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Color _getDayStatusColor(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return const Color.fromARGB(80, 224, 224, 224);
    if (events.first.contains('Missed')) return Colors.redAccent;
    if (events.first.contains('Partially')) return Colors.orangeAccent;
    return widget.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStatsData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildStatSummary(isDark),
                      const SizedBox(height: 24),
                      _buildCalendar(isDark),
                      const SizedBox(height: 16),
                      _buildLegend(),
                      const SizedBox(height: 16),
                      if (_selectedDay != null)
                        _buildSelectedDayInfo(
                            _selectedDay!, _getEventsForDay(_selectedDay!)),
                      const SizedBox(height: 24),
                      _buildAchievements(isDark),
                      const SizedBox(height: 24),
                      _buildMotivation(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.accentColor, widget.accentColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: const [
          Text(
            "Your Routine Progress",
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            "Track your habits, streaks & achievements",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummary(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
              "Total Routines", "$totalRoutines", Icons.list_alt, isDark),
        ),
        Expanded(
          child: _buildProgressCard("Completion Rate", completionRate, isDark),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: widget.accentColor, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String label, double progress, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(60, 60),
            painter: _CircularProgressPainter(progress, widget.accentColor),
          ),
          const SizedBox(height: 8),
          Text("${(progress * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.accentColor)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCalendar(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 100, // enough height for calendar
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2025, 1, 1),
              lastDay: DateTime.utc(2026, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              eventLoader: _getEventsForDay,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha:0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: widget.accentColor,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 40),
                      decoration: BoxDecoration(
                        color: _getDayStatusColor(date),
                        shape: BoxShape.circle,
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: widget.accentColor, label: "Completed"),
        const SizedBox(width: 12),
        const _LegendDot(color: Colors.orangeAccent, label: "Partial"),
        const SizedBox(width: 12),
        const _LegendDot(color: Colors.redAccent, label: "Missed"),
      ],
    );
  }

  Widget _buildSelectedDayInfo(DateTime date, List<String> events) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("📅 ${DateFormat('EEEE, d MMMM y').format(date)}",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text("No routines tracked on this day.",
                style: TextStyle(color: Colors.grey)),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: widget.accentColor),
                    const SizedBox(width: 6),
                    Text(e, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAchievements(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🏆 Achievements",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _achievementCard("🌅 First Day", "Started your journey", firstDay, isDark),
        _achievementCard("🔥 Week Warrior", "7-day streak", weekWarrior, isDark),
        _achievementCard("🌕 Perfect Month", "30-day streak", perfectMonth, isDark),
        _achievementCard(
            "👑 Consistency King", "80% completion", consistencyKing, isDark),
      ],
    );
  }

  Widget _achievementCard(
      String title, String subtitle, bool unlocked, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? widget.accentColor.withValues(alpha: 0.15)
            : (isDark ? Colors.grey.shade900 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? widget.accentColor
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events,
              color: unlocked ? widget.accentColor : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black)),
                Text(subtitle,
                    style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey)),
              ],
            ),
          ),
          Text(unlocked ? "Unlocked" : "Locked",
              style: TextStyle(
                  color: unlocked
                      ? widget.accentColor
                      : (isDark ? Colors.grey.shade400 : Colors.grey),
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMotivation(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        "💡 Every journey starts with a single step. Stay consistent — small habits create big change!",
        style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.black87,
            fontSize: 14),
      ),
    );
  }
}

// ----- Small Components -----
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ----- Circular Progress Painter -----
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CircularProgressPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, bgPaint);
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
