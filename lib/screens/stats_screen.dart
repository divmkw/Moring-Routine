import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';      
import 'package:intl/intl.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Sample dynamic data
  Map<DateTime, List<String>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMockData();
  }

  void _loadMockData() {
    _events = {
      DateTime.utc(2025, 10, 1): ['Completed Morning Routine'],
      DateTime.utc(2025, 10, 2): ['Missed Routine'],
      DateTime.utc(2025, 10, 5): ['Completed Routine'],
      DateTime.utc(2025, 10, 6): ['Completed Routine'],
    };
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  Color _getDayStatusColor(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return const Color.fromARGB(108, 224, 224, 224);
    if (events.first.contains('Missed')) return Colors.redAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey.shade100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
                Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // Adjusted gradient colors
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Text(
                  "Build lasting morning habits",
                  style: TextStyle(
                    color: Colors.white, // Changed text color to white
                    fontSize: 18,
                    // fontWeight: FontWeight.bold, // Added bold styling
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Stats Cards
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      _buildStatCard("Total Routines", "30", isDarkMode),
                      _buildStatCard("Completion Rate", "75%", isDarkMode),
                    ],
                  ),
                  Row(
                    children: [
                      _buildStatCard("Current Streak", "2 days", isDarkMode),
                      _buildStatCard("Longest Streak", "7 days", isDarkMode),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Calendar Section
              Container(
                height: 400, // you can adjust height as needed
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: TableCalendar(
                    firstDay: DateTime.utc(2025, 9, 1),
                    lastDay: DateTime.utc(2025, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: isDarkMode ? Colors.orangeAccent : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markerDecoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      defaultDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? Colors.grey.shade700 : Colors.white,
                      ),
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
              ),


              const SizedBox(height: 8),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Colors.greenAccent, label: "Completed"),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.redAccent, label: "Missed"),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.grey, label: "Not Tracked"),
                ],
              ),

              const SizedBox(height: 20),

              // Selected Date Info
              if (_selectedDay != null)
                _buildSelectedDayInfo(_selectedDay!, _getEventsForDay(_selectedDay!)),

              const SizedBox(height: 20),

              // Achievements
              const Text(
                "🏆 Achievements",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _achievementCard("🌅 First Day", "Started your journey", true, isDarkMode),
              _achievementCard("🔥 Week Warrior", "7 day streak", false, isDarkMode),
              _achievementCard("🌕 Perfect Month", "30 day streak", false, isDarkMode),
              _achievementCard("👑 Consistency King", "80% completion", false, isDarkMode),

              const SizedBox(height: 20),

              // Motivation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "💡 Every journey starts with a single step. Start small and be patient with yourself. Consistency matters more than perfection!",
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, bool isDarkMode) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDarkMode ? Colors.white : Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementCard(String title, String subtitle, bool unlocked, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? (isDarkMode ? Colors.yellow.shade800 : Colors.yellow.shade100)
            : (isDarkMode ? Colors.grey.shade800 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: unlocked ? Colors.amber : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            unlocked ? "Unlocked" : "Locked",
            style: TextStyle(
              color: unlocked ? Colors.green : (isDarkMode ? Colors.grey.shade400 : Colors.grey),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


  Widget _buildSelectedDayInfo(DateTime date, List<String> events) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📅 ${DateFormat('EEEE, d MMMM y').format(date)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text("No routines tracked on this day.",
                style: TextStyle(color: Colors.grey)),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 18, color: Colors.deepPurple),
                    const SizedBox(width: 6),
                    Text(e, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )),
        ],
      ),
    );
  }


class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
