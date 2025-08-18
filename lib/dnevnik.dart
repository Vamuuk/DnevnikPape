import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';

class VoiceNote {
  final String id;
  final String path; // Для веба - текст заметки
  final DateTime date;
  final int durationMs;

  VoiceNote({
    required this.id,
    required this.path,
    required this.date,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'date': date.millisecondsSinceEpoch,
    'durationMs': durationMs,
  };

  factory VoiceNote.fromJson(Map<String, dynamic> json) => VoiceNote(
    id: json['id'],
    path: json['path'],
    date: DateTime.fromMillisecondsSinceEpoch(json['date']),
    durationMs: json['durationMs'],
  );

  String get formattedDuration {
    int seconds = (durationMs / 1000).round();
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }
  
  String get displayText {
    if (kIsWeb) {
      return path; // В web версии path содержит текст
    }
    return 'Голосовая заметка ${formattedDuration}';
  }
}

class TodayScreen extends StatefulWidget {
  @override
  _TodayScreenState createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with TickerProviderStateMixin {
  TextEditingController _controller = TextEditingController();
  String _todayKey = '';
  String _mood = '😊';
  List<String> _tags = [];
  int _wordCount = 0;
  bool _isEditing = false;
  
  // Голосовые заметки (для веба - текстовые)
  List<VoiceNote> _voiceNotes = [];
  bool _isRecording = false;
  
  // Анимация
  late AnimationController _pulseController;

  final List<String> _moodsList = ['😊', '😢', '😴', '🤔', '😡', '🥳', '😰', '😌', '🥰', '😎'];
  final List<String> _availableTags = [
    'работа', 'семья', 'здоровье', 'спорт', 'хобби', 'путешествие', 
    'друзья', 'книги', 'фильмы', 'планы', 'достижения', 'благодарность',
    'учеба', 'покупки', 'готовка', 'природа', 'музыка', 'творчество'
  ];

  @override
  void initState() {
    super.initState();
    _todayKey = DateTime.now().toString().split(' ')[0];
    _loadNote();
    _controller.addListener(_updateWordCount);
    
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    setState(() {
      _wordCount = _controller.text.split(' ').where((word) => word.isNotEmpty).length;
    });
  }

  _loadNote() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _controller.text = prefs.getString(_todayKey) ?? '';
      _mood = prefs.getString('${_todayKey}_mood') ?? '😊';
      _tags = prefs.getStringList('${_todayKey}_tags') ?? [];
      _updateWordCount();
      _isEditing = false;
    });
    
    // Загрузка заметок
    String voiceNotesJson = prefs.getString('${_todayKey}_voice') ?? '[]';
    try {
      List<dynamic> voiceList = jsonDecode(voiceNotesJson);
      setState(() {
        _voiceNotes = voiceList.map((item) => VoiceNote.fromJson(item)).toList();
      });
    } catch (e) {
      print('Ошибка загрузки заметок: $e');
    }
  }

  _saveNote() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todayKey, _controller.text);
    await prefs.setString('${_todayKey}_mood', _mood);
    await prefs.setStringList('${_todayKey}_tags', _tags);
    
    // Сохранение заметок
    String voiceNotesJson = jsonEncode(_voiceNotes.map((note) => note.toJson()).toList());
    await prefs.setString('${_todayKey}_voice', voiceNotesJson);
    
    setState(() => _isEditing = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Запись сохранена!'),
          ],
        ),
        backgroundColor: Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showTextNoteDialog() {
    TextEditingController noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Быстрая заметка', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          autofocus: true,
          style: TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Введите быструю заметку...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.trim().isNotEmpty) {
                VoiceNote newNote = VoiceNote(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  path: noteController.text.trim(),
                  date: DateTime.now(),
                  durationMs: noteController.text.length * 100,
                );

                setState(() {
                  _voiceNotes.add(newNote);
                  _isEditing = true;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Быстрая заметка добавлена!'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
            child: Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _viewVoiceNote(VoiceNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Быстрая заметка', style: TextStyle(color: Colors.white)),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${note.date.hour.toString().padLeft(2, '0')}:${note.date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(note.path, style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Закрыть', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVoiceNote(note);
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteVoiceNote(VoiceNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Удалить заметку?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Быстрая заметка будет удалена навсегда',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _voiceNotes.removeWhere((n) => n.id == note.id);
                _isEditing = true;
              });
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 16),
              _buildMoodTagsRow(),
              SizedBox(height: 16),
              _buildVoiceSection(),
              SizedBox(height: 16),
              _buildTagsSection(),
              SizedBox(height: 16),
              _buildNoteField(),
              SizedBox(height: 16),
              _buildBottomSection(),
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    DateTime now = DateTime.now();
    String dayName = _getDayName(now.weekday);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6A1B9A).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сегодня',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                Text(
                  '$dayName, ${now.day}.${now.month}.${now.year}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Text(_mood, style: TextStyle(fontSize: 32)),
        ],
      ),
    );
  }

  Widget _buildMoodTagsRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showMoodDialog(),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF525252),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF6A1B9A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_mood, style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('Настроение', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _showTagDialog,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF525252),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF6A1B9A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0xFF4CAF50), size: 18),
                  SizedBox(width: 8),
                  Text('Теги', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF424242),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF4CAF50), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_add, color: Color(0xFF4CAF50), size: 18),
              SizedBox(width: 8),
              Text(
                'Быстрые заметки',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Text(
                '${_voiceNotes.length}',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Список заметок
          if (_voiceNotes.isNotEmpty) ...[
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _voiceNotes.length,
                itemBuilder: (context, index) {
                  final note = _voiceNotes[index];
                  
                  return Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF525252),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _viewVoiceNote(note),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.visibility,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            Spacer(),
                            GestureDetector(
                              onTap: () => _deleteVoiceNote(note),
                              child: Icon(Icons.delete_outline, 
                                   color: Colors.red[400], size: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${note.path.length} симв.',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${note.date.hour.toString().padLeft(2, '0')}:${note.date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
          ],
          
          // Кнопка добавления заметки
          GestureDetector(
            onTap: _showTextNoteDialog,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(0xFF4CAF50), 
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_comment, color: Color(0xFF4CAF50), size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Добавить быструю заметку',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    if (_tags.isEmpty) return SizedBox();
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF525252),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF6A1B9A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Активности дня', style: TextStyle(fontSize: 12, color: Colors.grey[300])),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag, style: TextStyle(color: Colors.white, fontSize: 10)),
                deleteIcon: Icon(Icons.close, size: 14, color: Colors.white70),
                onDeleted: () => setState(() => _tags.remove(tag)),
                backgroundColor: Color(0xFF4CAF50),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isEditing ? Color(0xFF4CAF50) : Color(0xFF6A1B9A)),
      ),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        onChanged: (_) => setState(() => _isEditing = true),
        style: TextStyle(
          color: Colors.black,
          fontSize: 14, 
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: 'Дополните текстом или оставьте только быстрые заметки...\n\n• Что интересного произошло?\n• Планы на завтра?',
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.text_fields, size: 14, color: Colors.grey[400]),
            SizedBox(width: 4),
            Text('$_wordCount слов', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            SizedBox(width: 12),
            Icon(Icons.note, size: 14, color: Colors.grey[400]),
            SizedBox(width: 4),
            Text('${_voiceNotes.length} заметок', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            Spacer(),
            if (_isEditing)
              Text('Изменения', 
                   style: TextStyle(color: Colors.orange, fontSize: 10)),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveNote,
            icon: Icon(Icons.save, size: 18),
            label: Text('Сохранить'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMoodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Выберите настроение', style: TextStyle(color: Colors.white)),
        content: Wrap(
          children: _moodsList.map((mood) {
            return GestureDetector(
              onTap: () {
                setState(() => _mood = mood);
                Navigator.pop(context);
              },
              child: Container(
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _mood == mood ? Color(0xFF4CAF50).withOpacity(0.3) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(mood, style: TextStyle(fontSize: 32)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTagDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFF424242),
          title: Text('Добавить теги', style: TextStyle(color: Colors.white)),
          content: Container(
            width: double.maxFinite,
            child: Wrap(
              spacing: 8,
              children: _availableTags.where((tag) => !_tags.contains(tag)).map((tag) {
                return ActionChip(
                  label: Text(tag, style: TextStyle(color: Colors.white)),
                  backgroundColor: Color(0xFF4CAF50),
                  onPressed: () {
                    setState(() => _tags.add(tag));
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Закрыть', style: TextStyle(color: Color(0xFF4CAF50))),
            ),
          ],
        );
      },
    );
  }

  String _getDayName(int weekday) {
    const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    return days[weekday - 1];
  }
}