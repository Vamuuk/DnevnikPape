import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

class VoiceNote {
  final String id, path;
  final DateTime date;
  final int durationMs;

  VoiceNote({required this.id, required this.path, required this.date, required this.durationMs});

  factory VoiceNote.fromJson(Map<String, dynamic> json) => VoiceNote(
    id: json['id'], path: json['path'], 
    date: DateTime.fromMillisecondsSinceEpoch(json['date']), 
    durationMs: json['durationMs']
  );

  String get duration => '${(durationMs ~/ 60000)}:${((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0')}';
}

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  TextEditingController _controller = TextEditingController();
  
  List<String> _tags = [];
  List<VoiceNote> _voiceNotes = [];
  Map<DateTime, List<String>> _dayTags = {};
  Map<DateTime, bool> _daysWithNotes = {};
  Map<DateTime, List<VoiceNote>> _dayVoiceNotes = {};
  
  bool _isPlaying = false;
  String _playingNoteId = '';
  FlutterSoundPlayer? _player;

  final List<String> _availableTags = [
    'работа', 'спорт', 'чтение', 'семья', 'учеба', 'отдых',
    'здоровье', 'творчество', 'планы', 'встречи', 'покупки', 'готовка'
  ];

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadAllData();
    _loadNote();
  }

  @override
  void dispose() {
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _initAudio() async {
    _player = FlutterSoundPlayer();
    try { await _player!.openPlayer(); } catch (e) { print('Audio error: $e'); }
  }

  _loadAllData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<DateTime, List<String>> dayTags = {};
    Map<DateTime, bool> daysWithNotes = {};
    Map<DateTime, List<VoiceNote>> dayVoiceNotes = {};
    
    for (String key in prefs.getKeys()) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
        DateTime date = DateTime.parse(key);
        daysWithNotes[date] = (prefs.getString(key) ?? '').isNotEmpty;
      } else if (key.endsWith('_tags')) {
        String dateStr = key.replaceAll('_tags', '');
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
          DateTime date = DateTime.parse(dateStr);
          List<String> tags = prefs.getStringList(key) ?? [];
          if (tags.isNotEmpty) dayTags[date] = tags;
        }
      } else if (key.endsWith('_voice')) {
        String dateStr = key.replaceAll('_voice', '');
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
          DateTime date = DateTime.parse(dateStr);
          try {
            List<dynamic> voiceList = jsonDecode(prefs.getString(key) ?? '[]');
            List<VoiceNote> voiceNotes = voiceList.map((item) => VoiceNote.fromJson(item)).toList();
            if (voiceNotes.isNotEmpty) {
              dayVoiceNotes[date] = voiceNotes;
              daysWithNotes[date] = true;
            }
          } catch (e) { print('Voice load error: $e'); }
        }
      }
    }
    
    setState(() {
      _dayTags = dayTags;
      _daysWithNotes = daysWithNotes;
      _dayVoiceNotes = dayVoiceNotes;
    });
  }

  _loadNote() async {
    String key = _selectedDay.toString().split(' ')[0];
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _controller.text = prefs.getString(key) ?? '';
      _tags = prefs.getStringList('${key}_tags') ?? [];
    });
    
    try {
      List<dynamic> voiceList = jsonDecode(prefs.getString('${key}_voice') ?? '[]');
      setState(() => _voiceNotes = voiceList.map((item) => VoiceNote.fromJson(item)).toList());
    } catch (e) {
      setState(() => _voiceNotes = []);
    }
  }

  _saveNote() async {
    String key = _selectedDay.toString().split(' ')[0];
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, _controller.text);
    await prefs.setStringList('${key}_tags', _tags);
    
    _loadAllData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Сохранено!')]), backgroundColor: Color(0xFF4CAF50)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCalendarHeader(),
        _buildCalendar(),
        Expanded(child: _buildDayContent()),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)])),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Календарь', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${_getMonthName(_focusedDay.month)} ${_focusedDay.year}', style: TextStyle(color: Colors.white70)),
            ],
          )),
          IconButton(icon: Icon(Icons.today, color: Colors.white), onPressed: () {
            setState(() { _selectedDay = _focusedDay = DateTime.now(); });
            _loadNote();
          }),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(color: Color(0xFF424242), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]),
      child: TableCalendar(
        firstDay: DateTime(2020), 
        lastDay: DateTime(2030), 
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.week, 
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerVisible: false,
        // Убираем locale: 'ru' - это вызывало ошибки
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold), 
          weekendStyle: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false, 
          selectedDecoration: BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Color(0xFF6A1B9A), shape: BoxShape.circle),
          defaultTextStyle: TextStyle(color: Colors.white), 
          weekendTextStyle: TextStyle(color: Color(0xFF4CAF50)),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildDayCell(day),
          todayBuilder: (context, day, focusedDay) => _buildDayCell(day, isToday: true),
          selectedBuilder: (context, day, focusedDay) => _buildDayCell(day, isSelected: true),
          // Кастомный билдер для русских дней недели
          dowBuilder: (context, day) {
            final dayNames = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
            final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
            
            return Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dayNames[day.weekday - 1],
                style: TextStyle(
                  color: isWeekend ? Color(0xFF4CAF50) : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
          _loadNote();
        },
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {bool isToday = false, bool isSelected = false}) {
    List<String> dayTags = _dayTags[day] ?? [];
    List<VoiceNote> dayVoiceNotes = _dayVoiceNotes[day] ?? [];
    bool hasNote = _daysWithNotes[day] ?? false;
    
    return Container(
      margin: EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF4CAF50) : (isToday ? Color(0xFF6A1B9A) : Colors.transparent),
        shape: BoxShape.circle,
        border: hasNote && !isSelected && !isToday ? Border.all(color: Color(0xFF4CAF50), width: 2) : null,
      ),
      child: Stack(
        children: [
          Center(child: Text('${day.day}', style: TextStyle(color: Colors.white, fontWeight: hasNote ? FontWeight.bold : FontWeight.normal))),
          if (dayVoiceNotes.isNotEmpty && !isSelected && !isToday) 
            Positioned(top: 2, right: 2, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.red[400], shape: BoxShape.circle))),
          if (dayTags.isNotEmpty && !isSelected && !isToday)
            Positioned(bottom: 2, right: 2, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: _getTagColor(dayTags.first), shape: BoxShape.circle))),
        ],
      ),
    );
  }

  Widget _buildDayContent() {
    bool isToday = isSameDay(_selectedDay, DateTime.now());
    
    return Container(
      color: Color(0xFF2E2E2E),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(isToday),
            SizedBox(height: 16),
            if (_voiceNotes.isNotEmpty) ...[_buildVoiceSection(), SizedBox(height: 16)],
            _buildTagsSection(),
            SizedBox(height: 16),
            _buildNoteField(),
            SizedBox(height: 16),
            _buildActions(),
            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(bool isToday) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isToday ? [Color(0xFF6A1B9A), Color(0xFF4A148C)] : [Color(0xFF424242), Color(0xFF525252)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isToday ? 'Сегодня' : _getDayName(_selectedDay.weekday), style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('${_selectedDay.day} ${_getMonthName(_selectedDay.month)} ${_selectedDay.year}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          )),
          Row(children: [
            if (_daysWithNotes[_selectedDay] ?? false) Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Color(0xFF4CAF50).withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.edit_note, color: Colors.white, size: 20)),
            if (_voiceNotes.isNotEmpty) ...[SizedBox(width: 8), Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red[400]!.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.mic, color: Colors.white, size: 16), SizedBox(width: 4), Text('${_voiceNotes.length}', style: TextStyle(color: Colors.white, fontSize: 12))]))],
          ]),
        ],
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Color(0xFF424242), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[400]!, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.mic, color: Colors.red[400], size: 18), SizedBox(width: 8), Text('Голосовые заметки', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)), Spacer(), Text('${_voiceNotes.length}', style: TextStyle(color: Colors.red[400], fontSize: 12))]),
          SizedBox(height: 12),
          Container(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _voiceNotes.length,
              itemBuilder: (context, index) {
                final note = _voiceNotes[index];
                final isPlaying = _playingNoteId == note.id && _isPlaying;
                return Container(
                  width: 140, margin: EdgeInsets.only(right: 8), padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Color(0xFF525252), borderRadius: BorderRadius.circular(8), border: Border.all(color: isPlaying ? Colors.red[400]! : Colors.transparent, width: 2)),
                  child: Column(children: [
                    Row(children: [
                      GestureDetector(onTap: () => _playVoiceNote(note), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.red[400], shape: BoxShape.circle), child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 16))),
                      Spacer(),
                      Text(note.duration, style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold, fontSize: 10)),
                    ]),
                    SizedBox(height: 4),
                    Text('${note.date.hour.toString().padLeft(2, '0')}:${note.date.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey[400], fontSize: 9)),
                  ]),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red[400]!.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Icon(Icons.info_outline, color: Colors.red[400], size: 14), SizedBox(width: 8), Expanded(child: Text('Для записи новых заметок перейдите в "Сегодня"', style: TextStyle(color: Colors.red[400], fontSize: 10)))]),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Color(0xFF424242), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF6A1B9A), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.label, color: Color(0xFF4CAF50), size: 18), SizedBox(width: 8), Text('Активности дня', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)), Spacer(), IconButton(icon: Icon(Icons.add, color: Color(0xFF4CAF50)), onPressed: _showTagDialog)]),
          if (_tags.isEmpty) Text('Добавьте активности для этого дня', style: TextStyle(color: Colors.grey[400], fontSize: 12))
          else Wrap(spacing: 6, children: _tags.map((tag) => Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getTagColor(tag), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(tag, style: TextStyle(color: Colors.white, fontSize: 11)), SizedBox(width: 4), GestureDetector(onTap: () => setState(() => _tags.remove(tag)), child: Icon(Icons.close, size: 12, color: Colors.white70))]))).toList()),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      height: 150,
      decoration: BoxDecoration(color: Color(0xFF424242), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF6A1B9A))),
      child: TextField(
        controller: _controller, maxLines: null, expands: true,
        style: TextStyle(color: Colors.black, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Запишите события дня ${_selectedDay.day} ${_getMonthName(_selectedDay.month)}...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.all(12), filled: true, fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Icon(Icons.text_fields, size: 14, color: Colors.grey[400]), SizedBox(width: 4),
        Text('${_controller.text.split(' ').where((word) => word.isNotEmpty).length} слов', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        Spacer(),
        TextButton.icon(onPressed: _clearDay, icon: Icon(Icons.clear, color: Colors.red[400], size: 16), label: Text('Очистить', style: TextStyle(color: Colors.red[400], fontSize: 11))),
        SizedBox(width: 8),
        ElevatedButton.icon(onPressed: _saveNote, icon: Icon(Icons.save, size: 16), label: Text('Сохранить'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      ],
    );
  }

  Future<void> _playVoiceNote(VoiceNote note) async {
    try {
      if (_isPlaying && _playingNoteId == note.id) {
        await _player!.stopPlayer();
        setState(() { _isPlaying = false; _playingNoteId = ''; });
        return;
      }
      if (_isPlaying) await _player!.stopPlayer();
      await _player!.startPlayer(fromURI: note.path, whenFinished: () => setState(() { _isPlaying = false; _playingNoteId = ''; }));
      setState(() { _isPlaying = true; _playingNoteId = note.id; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка воспроизведения'), backgroundColor: Colors.red));
    }
  }

  void _showTagDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Color(0xFF424242), title: Text('Добавить активность', style: TextStyle(color: Colors.white)),
      content: Wrap(spacing: 6, children: _availableTags.where((tag) => !_tags.contains(tag)).map((tag) => ActionChip(label: Text(tag, style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: _getTagColor(tag), onPressed: () { setState(() => _tags.add(tag)); Navigator.pop(context); })).toList()),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Закрыть', style: TextStyle(color: Color(0xFF4CAF50))))],
    ));
  }

  void _clearDay() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Color(0xFF424242), title: Text('Очистить день?', style: TextStyle(color: Colors.white)),
      content: Text('Это удалит всю запись, активности и голосовые заметки', style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: Colors.grey[400]))),
        ElevatedButton(onPressed: () async {
          String key = _selectedDay.toString().split(' ')[0];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          for (VoiceNote note in _voiceNotes) { try { File(note.path).deleteSync(); } catch (e) {} }
          await prefs.remove(key); await prefs.remove('${key}_tags'); await prefs.remove('${key}_voice');
          setState(() { _controller.clear(); _tags.clear(); _voiceNotes.clear(); });
          _loadAllData(); Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('День очищен')));
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('Удалить')),
      ],
    ));
  }

  Color _getTagColor(String tag) {
    const colors = { 'работа': Color(0xFF6A1B9A), 'спорт': Color(0xFF4CAF50), 'чтение': Color(0xFF9C27B0), 'семья': Color(0xFFE91E63), 'учеба': Color(0xFFFF9800), 'отдых': Color(0xFF009688), 'здоровье': Color(0xFFF44336), 'творчество': Color(0xFFFFEB3B), 'планы': Color(0xFF3F51B5), 'встречи': Color(0xFF795548), 'покупки': Color(0xFF607D8B), 'готовка': Color(0xFFFF5722) };
    return colors[tag] ?? Color(0xFF757575);
  }

  String _getDayName(int weekday) {
    const dayNames = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    return dayNames[weekday - 1];
  }
  
  String _getMonthName(int month) => const ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'][month - 1];
}