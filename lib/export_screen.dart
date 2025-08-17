import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExportScreen extends StatefulWidget {
  @override
  _ExportScreenState createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _exportFormat = 'txt';
  DateTimeRange? _dateRange;
  bool _includeMoods = true;
  bool _includeTags = true;
  bool _includeWeather = true;
  List<String> _selectedTags = [];
  List<String> _allTags = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadAllTags();
  }

  _loadAllTags() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Set<String> tags = {};
    
    List<String> keys = prefs.getKeys().toList();
    for (String key in keys) {
      if (key.endsWith('_tags')) {
        List<String> noteTags = prefs.getStringList(key) ?? [];
        tags.addAll(noteTags);
      }
    }
    
    setState(() {
      _allTags = tags.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Экспорт записей'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _isExporting ? _buildExportingView() : _buildExportForm(),
      bottomNavigationBar: _isExporting 
          ? null 
          : _buildExportButton(),
    );
  }

  Widget _buildExportingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          SizedBox(height: 24),
          Text(
            'Экспортируем записи...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Это может занять несколько секунд',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildExportForm() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildFormatSection(),
        SizedBox(height: 24),
        _buildDateRangeSection(),
        SizedBox(height: 24),
        _buildContentSection(),
        SizedBox(height: 24),
        _buildTagFilterSection(),
        SizedBox(height: 24),
        _buildPreviewSection(),
      ],
    );
  }

  Widget _buildFormatSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_download, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Формат экспорта',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...['txt', 'pdf', 'html', 'json'].map((format) {
              return RadioListTile<String>(
                title: Text(_getFormatName(format)),
                subtitle: Text(_getFormatDescription(format)),
                value: format,
                groupValue: _exportFormat,
                onChanged: (value) => setState(() => _exportFormat = value!),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Период',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Выбрать период'),
              subtitle: Text(_dateRange == null 
                  ? 'Все записи' 
                  : '${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year} - ${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}'),
              trailing: Icon(Icons.chevron_right),
              onTap: _selectDateRange,
            ),
            if (_dateRange != null)
              TextButton(
                onPressed: () => setState(() => _dateRange = null),
                child: Text('Сбросить фильтр'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Содержимое',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            CheckboxListTile(
              title: Text('Настроения'),
              subtitle: Text('Включить эмодзи настроений'),
              value: _includeMoods,
              onChanged: (value) => setState(() => _includeMoods = value!),
            ),
            CheckboxListTile(
              title: Text('Теги'),
              subtitle: Text('Включить теги записей'),
              value: _includeTags,
              onChanged: (value) => setState(() => _includeTags = value!),
            ),
            CheckboxListTile(
              title: Text('Погода'),
              subtitle: Text('Включить информацию о погоде'),
              value: _includeWeather,
              onChanged: (value) => setState(() => _includeWeather = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilterSection() {
    if (_allTags.isEmpty) return SizedBox();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Фильтр по тегам',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Экспортировать только записи с выбранными тегами',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _allTags.map((tag) {
                bool isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedTags.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _selectedTags.clear()),
                child: Text('Очистить выбор'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Предпросмотр',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _generatePreview(),
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return Container(
      padding: EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _performExport,
        icon: Icon(Icons.download),
        label: Text('Экспортировать'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _getFormatName(String format) {
    switch (format) {
      case 'txt': return 'Текстовый файл (.txt)';
      case 'pdf': return 'PDF документ (.pdf)';
      case 'html': return 'HTML страница (.html)';
      case 'json': return 'JSON данные (.json)';
      default: return format;
    }
  }

  String _getFormatDescription(String format) {
    switch (format) {
      case 'txt': return 'Простой текст, легко читается';
      case 'pdf': return 'Красиво оформленный документ';
      case 'html': return 'Веб-страница с оформлением';
      case 'json': return 'Структурированные данные';
      default: return '';
    }
  }

  String _generatePreview() {
    String preview = '';
    
    switch (_exportFormat) {
      case 'txt':
        preview = '''=== ДНЕВНИК БЕРИКА ===

20.07.2025 ${_includeMoods ? '😊' : ''}${_includeWeather ? ' ☀️' : ''}
${_includeTags ? '[работа, семья]' : ''}

Сегодня был хороший день. Много работал...

---''';
        break;
      case 'html':
        preview = '''<h1>Дневник Берика</h1>
<div class="entry">
  <h2>20.07.2025${_includeMoods ? ' 😊' : ''}${_includeWeather ? ' ☀️' : ''}</h2>
  ${_includeTags ? '<div class="tags">[работа, семья]</div>' : ''}
  <p>Сегодня был хороший день...</p>
</div>''';
        break;
      case 'json':
        preview = '''{
  "entries": [
    {
      "date": "2025-07-20",
      "content": "Сегодня был хороший день...",
      ${_includeMoods ? '"mood": "😊",' : ''}
      ${_includeWeather ? '"weather": "☀️",' : ''}
      ${_includeTags ? '"tags": ["работа", "семья"]' : ''}
    }
  ]
}''';
        break;
      default:
        preview = 'PDF предпросмотр недоступен';
    }
    
    return preview;
  }

  void _selectDateRange() async {
    DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
    );
    
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  void _performExport() async {
    setState(() => _isExporting = true);
    
    // Симуляция экспорта
    await Future.delayed(Duration(seconds: 3));
    
    setState(() => _isExporting = false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Экспорт завершен'),
          ],
        ),
        content: Text('Файл сохранен в папку "Загрузки"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ОК'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Открыть файл'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Справка по экспорту'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• TXT - простой текстовый формат'),
            Text('• PDF - красиво оформленный документ'),
            Text('• HTML - веб-страница'),
            Text('• JSON - для обработки данных'),
            SizedBox(height: 16),
            Text('Вы можете выбрать период и содержимое для экспорта.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Понятно'),
          ),
        ],
      ),
    );
  }
}