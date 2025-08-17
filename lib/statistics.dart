import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DayActivity {
  final DateTime date;
  final List<String> tags;
  final String mood;
  final bool hasNote;
  final double productivity;

  DayActivity({
    required this.date,
    required this.tags,
    required this.mood,
    required this.hasNote,
    required this.productivity,
  });
}

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, int> _weeklyStats = {};
  Map<String, Color> _activityColors = {};
  int _totalNotes = 0;
  int _weekNotes = 0;
  List<DayActivity> _weekData = [];

  @override
  void initState() {
    super.initState();
    _initActivityColors();
    _loadWeeklyStats();
  }

  void _initActivityColors() {
    _activityColors = {
      'работа': Color(0xFF6A1B9A),
      'спорт': Color(0xFF4CAF50),
      'чтение': Color(0xFF9C27B0),
      'семья': Color(0xFFE91E63),
      'учеба': Color(0xFFFF9800),
      'отдых': Color(0xFF009688),
      'здоровье': Color(0xFFF44336),
      'творчество': Color(0xFFFFEB3B),
      'планы': Color(0xFF3F51B5),
      'встречи': Color(0xFF795548),
    };
  }

  _loadWeeklyStats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    Map<String, int> weeklyStats = {};
    List<DayActivity> weekData = [];
    int totalNotes = 0;
    int weekNotes = 0;
    
    List<String> keys = prefs.getKeys().toList();
    
    for (String key in keys) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
        String content = prefs.getString(key) ?? '';
        if (content.isNotEmpty) totalNotes++;
      }
    }
    
    for (int i = 0; i < 7; i++) {
      DateTime day = startOfWeek.add(Duration(days: i));
      String dayKey = day.toString().split(' ')[0];
      
      List<String> tags = prefs.getStringList('${dayKey}_tags') ?? [];
      String content = prefs.getString(dayKey) ?? '';
      String mood = prefs.getString('${dayKey}_mood') ?? '';
      
      if (content.isNotEmpty) weekNotes++;
      
      for (String tag in tags) {
        weeklyStats[tag] = (weeklyStats[tag] ?? 0) + 1;
      }
      
      weekData.add(DayActivity(
        date: day,
        tags: tags,
        mood: mood,
        hasNote: content.isNotEmpty,
        productivity: _calculateProductivity(tags),
      ));
    }
    
    setState(() {
      _weeklyStats = weeklyStats;
      _totalNotes = totalNotes;
      _weekNotes = weekNotes;
      _weekData = weekData;
    });
  }

  double _calculateProductivity(List<String> tags) {
    Map<String, double> productivityPoints = {
      'работа': 0.9,
      'учеба': 1.0,
      'чтение': 0.8,
      'спорт': 0.7,
      'здоровье': 0.6,
      'творчество': 0.8,
      'планы': 0.5,
      'встречи': 0.4,
      'семья': 0.3,
      'отдых': 0.1,
    };
    
    if (tags.isEmpty) return 0.0;
    
    double total = 0;
    for (String tag in tags) {
      total += productivityPoints[tag] ?? 0.2;
    }
    
    return (total / tags.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 16),
          _buildWeekOverview(),
          SizedBox(height: 16),
          _buildWeeklyChart(),
          SizedBox(height: 16),
          _buildActivityStats(),
          SizedBox(height: 16),
          _buildProductivityInsights(),
          SizedBox(height: 80), // Отступ для навигации
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статистика',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Анализ недели',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.analytics, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildWeekOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Записей',
            '$_weekNotes/7',
            Icons.edit_note,
            Color(0xFF4CAF50),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Всего',
            '$_totalNotes',
            Icons.book,
            Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF424242),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF6A1B9A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Продуктивность по дням',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Container(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weekData.map((day) {
                String dayName = _getDayName(day.date.weekday);
                bool isToday = _isSameDay(day.date, DateTime.now());
                
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? Color(0xFF4CAF50) : Colors.white70,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          width: 20,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 20,
                                height: (day.productivity * 40).clamp(2.0, 40.0),
                                decoration: BoxDecoration(
                                  color: _getProductivityColor(day.productivity),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 2),
                        if (day.mood.isNotEmpty)
                          Text(day.mood, style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStats() {
    if (_weeklyStats.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF424242),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Добавьте активности\nв записи дневника',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF424242),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF6A1B9A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активности недели',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          ..._weeklyStats.entries.take(5).map((entry) {
            double percentage = entry.value / 7;
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _activityColors[entry.key] ?? Colors.grey,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activityColors[entry.key] ?? Colors.grey,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProductivityInsights() {
    double avgProductivity = _weekData.isEmpty 
        ? 0.0 
        : _weekData.map((d) => d.productivity).reduce((a, b) => a + b) / _weekData.length;
    
    String insight = _getProductivityInsight(avgProductivity);
    IconData icon = _getProductivityIcon(avgProductivity);
    Color color = _getProductivityColor(avgProductivity);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          SizedBox(height: 8),
          Text(
            insight,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Продуктивность: ${(avgProductivity * 100).round()}%',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getProductivityColor(double productivity) {
    if (productivity >= 0.8) return Color(0xFF4CAF50);
    if (productivity >= 0.6) return Color(0xFFFF9800);
    if (productivity >= 0.4) return Color(0xFF6A1B9A);
    return Color(0xFFF44336);
  }

  IconData _getProductivityIcon(double productivity) {
    if (productivity >= 0.8) return Icons.trending_up;
    if (productivity >= 0.6) return Icons.trending_flat;
    if (productivity >= 0.4) return Icons.show_chart;
    return Icons.trending_down;
  }

  String _getProductivityInsight(double productivity) {
    if (productivity >= 0.8) return 'Отличная неделя! 🚀';
    if (productivity >= 0.6) return 'Хорошая активность! 👍';
    if (productivity >= 0.4) return 'Можно лучше 📈';
    return 'Больше активности! 💪';
  }

  String _getDayName(int weekday) {
    const days = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return days[weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}