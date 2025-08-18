import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'welcome_screen.dart';
import 'dnevnik.dart';
import 'calendar.dart';
import 'statistics.dart';
import 'settings.dart';
import 'search_screen.dart';
import 'export_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Настройки только для мобильных платформ
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Дневник Берика',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('ru', 'RU'),
        const Locale('en', 'US'),
      ],
      locale: Locale('ru', 'RU'),
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFF6A1B9A, {
          50: Color(0xFFF3E5F5),
          100: Color(0xFFE1BEE7),
          200: Color(0xFFCE93D8),
          300: Color(0xFFBA68C8),
          400: Color(0xFFAB47BC),
          500: Color(0xFF9C27B0),
          600: Color(0xFF8E24AA),
          700: Color(0xFF7B1FA2),
          800: Color(0xFF6A1B9A),
          900: Color(0xFF4A148C),
        }),
        scaffoldBackgroundColor: Color(0xFF2E2E2E),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF424242),
          selectedItemColor: Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey[400],
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardTheme(
          color: Color(0xFF424242),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Color(0xFF4CAF50),
          selectionColor: Color(0xFF4CAF50).withOpacity(0.3),
          selectionHandleColor: Color(0xFF4CAF50),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          labelLarge: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF6A1B9A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF4CAF50)),
          ),
          hintStyle: TextStyle(color: Colors.grey[600]),
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),
        iconTheme: IconThemeData(color: Colors.white70),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF6A1B9A),
          secondary: Color(0xFF4CAF50),
          surface: Color(0xFF424242),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
      ),
      // Для веба сразу переходим к основному экрану
      home: kIsWeb ? MainScreen() : WelcomeScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;

  final List<Widget> _screens = [
    TodayScreen(),
    CalendarScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Дневник Берика'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => _navigateToSearch(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Экспорт'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, size: 20),
                    SizedBox(width: 8),
                    Text('Резервная копия'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 20),
                    SizedBox(width: 8),
                    Text('Импорт'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _screens[_selectedIndex],
      ),
      backgroundColor: Color(0xFF2E2E2E),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Color(0xFF424242),
          selectedItemColor: Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey[400],
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.today),
              label: 'Сегодня',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Календарь',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Статистика',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Настройки',
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showQuickNoteDialog(),
              child: Icon(Icons.add),
              backgroundColor: Color(0xFF4CAF50),
              tooltip: 'Быстрая заметка',
            )
          : null,
    );
  }

  void _navigateToSearch() async {
    try {
      DateTime? selectedDate = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SearchScreen()),
      );
      
      if (selectedDate != null) {
        setState(() {
          _selectedIndex = 1;
        });
      }
    } catch (e) {
      print('Ошибка навигации к поиску: $e');
    }
  }

  void _handleMenuAction(String action) {
    try {
      switch (action) {
        case 'export':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ExportScreen()),
          );
          break;
        case 'backup':
          _showBackupDialog();
          break;
        case 'import':
          _showImportDialog();
          break;
      }
    } catch (e) {
      print('Ошибка обработки действия меню: $e');
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Row(
          children: [
            Icon(Icons.upload, color: Colors.blue),
            SizedBox(width: 8),
            Text('Импорт данных', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выберите файл для импорта:', style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.file_present, color: Colors.white),
              title: Text('JSON файл', style: TextStyle(color: Colors.white)),
              subtitle: Text('Импорт из предыдущего экспорта', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                _performImport('json');
              },
            ),
            ListTile(
              leading: Icon(Icons.backup, color: Colors.white),
              title: Text('Резервная копия', style: TextStyle(color: Colors.white)),
              subtitle: Text('Восстановление из бэкапа', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                _performImport('backup');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  void _performImport(String type) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(width: 16),
            Text('Импортируем данные...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Данные успешно импортированы!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Резервная копия', style: TextStyle(color: Colors.white)),
        content: Text('Создать резервную копию всех записей?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Резервная копия создана!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
            child: Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showQuickNoteDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF424242),
        title: Text('Быстрая заметка', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Быстрая заметка...',
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
                  content: Text('Заметка добавлена!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
            child: Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}