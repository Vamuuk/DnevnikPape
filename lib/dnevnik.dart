import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class VoiceNote {
  final String id;
  final String path;
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
  
  // Голосовые заметки
  List<VoiceNote> _voiceNotes = [];
  bool _isRecording = false;
  bool _isPlaying = false;
  String _playingNoteId = '';
  DateTime? _recordingStartTime;
  
  // Audio
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  
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
    _initAudio();
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
    _closeAudio();
    super.dispose();
  }

  Future<void> _initAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    
    try {
      await _recorder!.openRecorder();
      await _player!.openPlayer();
    } catch (e) {
      print('Ошибка инициализации аудио: $e');
    }
  }

  Future<void> _closeAudio() async {
    try {
      await _recorder?.closeRecorder();
      await _player?.closePlayer();
    } catch (e) {
      print('Ошибка закрытия аудио: $e');
    }
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
    
    // Загрузка голосовых заметок
    String voiceNotesJson = prefs.getString('${_todayKey}_voice') ?? '[]';
    try {
      List<dynamic> voiceList = jsonDecode(voiceNotesJson);
      setState(() {
        _voiceNotes = voiceList.map((item) => VoiceNote.fromJson(item)).toList();
      });
    } catch (e) {
      print('Ошибка загрузки голосовых заметок: $e');
    }
  }

  _saveNote() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todayKey, _controller.text);
    await prefs.setString('${_todayKey}_mood', _mood);
    await prefs.setStringList('${_todayKey}_tags', _tags);
    
    // Сохранение голосовых заметок
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

  Future<void> _startRecording() async {
    try {
      // Запрос разрешений с учетом платформы
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нужно разрешение на микрофон')),
        );
        return;
      }

      // Получаем директорию для сохранения (кроссплатформенно)
      Directory appDir = await getApplicationDocumentsDirectory();
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      // Имя файла с временной меткой
      String fileName = '${DateTime.now().millisecondsSinceEpoch}';
      
      // Выбираем формат в зависимости от платформы
      String extension;
      Codec codec;
      if (Platform.isIOS) {
        extension = '.m4a';
        codec = Codec.aacMP4; // Лучше для iOS
      } else {
        extension = '.aac';
        codec = Codec.aacADTS; // Для Android
      }
      
      String filePath = '${appDir.path}/$fileName$extension';

      await _recorder!.startRecorder(
        toFile: filePath,
        codec: codec,
      );

      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
      });
      _pulseController.repeat();

    } catch (e) {
      print('Ошибка начала записи: $e');
      String errorMessage = Platform.isIOS 
          ? 'Ошибка записи на iOS: $e'
          : 'Ошибка записи на Android: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? path = await _recorder!.stopRecorder();
      _pulseController.stop();

      if (path != null && _recordingStartTime != null) {
        int duration = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        
        if (duration < 1000) {
          // Слишком короткая запись
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Запись слишком короткая')),
          );
        } else {
          VoiceNote newNote = VoiceNote(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: path,
            date: DateTime.now(),
            durationMs: duration,
          );

          setState(() {
            _voiceNotes.add(newNote);
            _isEditing = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Голосовая заметка записана (${newNote.formattedDuration})'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }

      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });

    } catch (e) {
      print('Ошибка остановки записи: $e');
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });
    }
  }

  Future<void> _playVoiceNote(VoiceNote note) async {
    try {
      if (_isPlaying && _playingNoteId == note.id) {
        await _player!.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playingNoteId = '';
        });
        return;
      }

      if (_isPlaying) {
        await _player!.stopPlayer();
      }

      await _player!.startPlayer(
        fromURI: note.path,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
            _playingNoteId = '';
          });
        },
      );

      setState(() {
        _isPlaying = true;
        _playingNoteId = note.id;
      });

    } catch (e) {
      print('Ошибка воспроизведения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка воспроизведения')),
      );
    }
  }

  void _deleteVoiceNote(VoiceNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Удалить запись?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Голосовая заметка будет удалена навсегда',
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
              
              // Удаляем файл
              try {
                File(note.path).deleteSync();
              } catch (e) {
                print('Ошибка удаления файла: $e');
              }
              
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
              SizedBox(height: 80), // Отступ для навигации
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '$dayName, ${now.day}.${now.month}.${now.year}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
              Icon(Icons.mic, color: Color(0xFF4CAF50), size: 18),
              SizedBox(width: 8),
              Text(
                'Голосовые заметки',
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
          
          // Список голосовых заметок
          if (_voiceNotes.isNotEmpty) ...[
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _voiceNotes.length,
                itemBuilder: (context, index) {
                  final note = _voiceNotes[index];
                  final isPlaying = _playingNoteId == note.id && _isPlaying;
                  
                  return Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF525252),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPlaying ? Color(0xFF4CAF50) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _playVoiceNote(note),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
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
                          note.formattedDuration,
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
          
          // Кнопка записи
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording 
                    ? Colors.red.withOpacity(0.2)
                    : Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isRecording ? Colors.red : Color(0xFF4CAF50), 
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  if (_isRecording) ...[
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(_pulseController.value),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Icon(Icons.mic, color: Color(0xFF4CAF50), size: 18),
                  ],
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isRecording 
                          ? 'Запись... Нажмите для остановки'
                          : 'Нажмите для записи',
                      style: TextStyle(
                        color: _isRecording ? Colors.red : Color(0xFF4CAF50),
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
      height: 200, // Фиксированная высота
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
          hintText: 'Дополните текстом или оставьте только голосовые заметки...\n\n• Что интересного произошло?\n• Планы на завтра?',
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
            Icon(Icons.mic, size: 14, color: Colors.grey[400]),
            SizedBox(width: 4),
            Text('${_voiceNotes.length} голос.', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
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