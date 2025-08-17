import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _backupFrequency = 'weekly';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _backupFrequency = prefs.getString('backup_frequency') ?? 'weekly';
    });
  }

  _saveSetting(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2E2E2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Настройки',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 30),
              
              // Резервное копирование
              _buildSection(
                title: 'Резервное копирование',
                children: [
                  _buildDropdownTile(
                    title: 'Автоматическое резервирование',
                    subtitle: 'Как часто создавать копии данных',
                    value: _backupFrequency,
                    items: [
                      {'value': 'daily', 'label': 'Ежедневно'},
                      {'value': 'weekly', 'label': 'Еженедельно'},
                      {'value': 'monthly', 'label': 'Ежемесячно'},
                      {'value': 'manual', 'label': 'Только вручную'},
                    ],
                    onChanged: (value) {
                      setState(() => _backupFrequency = value);
                      _saveSetting('backup_frequency', value);
                    },
                    icon: Icons.schedule,
                  ),
                  _buildActionTile(
                    title: 'Создать резервную копию',
                    subtitle: 'Сохранить все записи и голосовые заметки',
                    onTap: _createBackup,
                    icon: Icons.backup,
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // Управление данными
              _buildSection(
                title: 'Управление данными',
                children: [
                  _buildActionTile(
                    title: 'Экспорт записей',
                    subtitle: 'Сохранить все записи в файл',
                    onTap: _exportData,
                    icon: Icons.download,
                  ),
                  _buildActionTile(
                    title: 'Очистить все данные',
                    subtitle: 'Удалить все записи навсегда',
                    onTap: _showClearDataDialog,
                    icon: Icons.delete_forever,
                    isDestructive: true,
                  ),
                ],
              ),
              
              SizedBox(height: 40),
              
              // О приложении
              _buildSection(
                title: 'О приложении',
                children: [
                  _buildInfoTile(
                    title: 'Дневник Берика',
                    subtitle: 'Версия 1.0.0',
                    icon: Icons.info,
                  ),
                  _buildActionTile(
                    title: 'Обратная связь',
                    subtitle: 'Сообщить об ошибке или предложить улучшение',
                    onTap: _showFeedbackDialog,
                    icon: Icons.feedback,
                  ),
                ],
              ),
              
              SizedBox(height: 100), // Отступ для навигации
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4CAF50),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF6A1B9A).withOpacity(0.3)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<Map<String, String>> items,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF6A1B9A)),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[700]),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: SizedBox(),
        dropdownColor: Colors.white,
        style: TextStyle(color: Colors.black),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item['value'],
            child: Text(
              item['label']!,
              style: TextStyle(color: Colors.black),
            ),
          );
        }).toList(),
        onChanged: (newValue) => onChanged(newValue!),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? Colors.red : Color(0xFF6A1B9A),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[700]),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF6A1B9A)),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[700]),
      ),
    );
  }

  void _createBackup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(width: 16),
            Text('Создание резервной копии...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    // Симуляция создания бэкапа
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Резервная копия создана!'),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    });
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Экспорт записей', style: TextStyle(color: Colors.white)),
        content: Text(
          'Все ваши записи будут сохранены в файл и доступны для отправки.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Симуляция экспорта
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Записи экспортированы в файл!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
            child: Text('Экспортировать'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('⚠️ Удалить все данные?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Это действие нельзя отменить. Все записи, голосовые заметки и настройки будут удалены навсегда.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Удалить все'),
          ),
        ],
      ),
    );
  }

  void _clearAllData() async {
    // Показываем прогресс
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(width: 16),
            Text('Удаление данных...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    // Очищаем все данные
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Все данные удалены'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showFeedbackDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Обратная связь', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Расскажите, что можно улучшить в приложении...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Спасибо за отзыв!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
            child: Text('Отправить'),
          ),
        ],
      ),
    );
  }
}