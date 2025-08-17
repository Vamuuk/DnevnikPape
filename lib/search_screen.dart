import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  String _searchFilter = 'all'; // all, mood, tags, text

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  _loadRecentSearches() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }
    await prefs.setStringList('recent_searches', _recentSearches);
    setState(() {});
  }

  _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _saveRecentSearch(query);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<SearchResult> results = [];
    List<String> keys = prefs.getKeys().toList();

    for (String key in keys) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
        String content = prefs.getString(key) ?? '';
        String mood = prefs.getString('${key}_mood') ?? '';
        List<String> tags = prefs.getStringList('${key}_tags') ?? [];
        
        bool matches = false;
        String matchType = '';
        
        switch (_searchFilter) {
          case 'all':
            matches = content.toLowerCase().contains(query.toLowerCase()) ||
                     mood.contains(query) ||
                     tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
            if (content.toLowerCase().contains(query.toLowerCase())) {
              matchType = 'text';
            } else if (mood.contains(query)) {
              matchType = 'mood';
            } else if (tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))) {
              matchType = 'tag';
            }
            break;
          case 'mood':
            matches = mood.contains(query);
            matchType = 'mood';
            break;
          case 'tags':
            matches = tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
            matchType = 'tag';
            break;
          case 'text':
            matches = content.toLowerCase().contains(query.toLowerCase());
            matchType = 'text';
            break;
        }
        
        if (matches && content.isNotEmpty) {
          results.add(SearchResult(
            date: DateTime.parse(key),
            content: content,
            mood: mood,
            tags: tags,
            matchType: matchType,
          ));
        }
      }
    }

    results.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск в дневнике'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Поиск записей, настроений, тегов...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              _buildFilterChips(),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('all', 'Всё', Icons.search),
          SizedBox(width: 8),
          _buildFilterChip('text', 'Текст', Icons.text_fields),
          SizedBox(width: 8),
          _buildFilterChip('mood', 'Настроение', Icons.mood),
          SizedBox(width: 8),
          _buildFilterChip('tags', 'Теги', Icons.label),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    bool isSelected = _searchFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() => _searchFilter = value);
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return _buildRecentSearches();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return _buildSearchResults();
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Недавние поиски',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          if (_recentSearches.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Начните поиск по вашему дневнику',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              children: _recentSearches.map((search) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _searchController.text = search;
                          _performSearch(search);
                        },
                        child: Padding(
                          padding: EdgeInsets.only(left: 12, top: 8, bottom: 8),
                          child: Text(search),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(search),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Попробуйте изменить запрос или фильтр',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        SearchResult result = _searchResults[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(SearchResult result) {
    String preview = result.content.length > 100 
        ? result.content.substring(0, 100) + '...'
        : result.content;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pop(context, result.date),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getMatchTypeColor(result.matchType),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getMatchTypeIcon(result.matchType),
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.date.day}.${result.date.month}.${result.date.year}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getMatchTypeLabel(result.matchType),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (result.mood.isNotEmpty)
                    Text(result.mood, style: TextStyle(fontSize: 24)),
                ],
              ),
              SizedBox(height: 12),
              Text(
                preview,
                style: TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (result.tags.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: result.tags.take(3).map((tag) {
                    return Chip(
                      label: Text(tag, style: TextStyle(fontSize: 10)),
                      backgroundColor: Colors.blue[100],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getMatchTypeColor(String matchType) {
    switch (matchType) {
      case 'text': return Colors.blue;
      case 'mood': return Colors.orange;
      case 'tag': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getMatchTypeIcon(String matchType) {
    switch (matchType) {
      case 'text': return Icons.text_fields;
      case 'mood': return Icons.mood;
      case 'tag': return Icons.label;
      default: return Icons.search;
    }
  }

  String _getMatchTypeLabel(String matchType) {
    switch (matchType) {
      case 'text': return 'Найдено в тексте';
      case 'mood': return 'Найдено в настроении';
      case 'tag': return 'Найдено в тегах';
      default: return 'Совпадение';
    }
  }

  void _removeRecentSearch(String search) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(search);
    await prefs.setStringList('recent_searches', _recentSearches);
    setState(() {});
  }
}

class SearchResult {
  final DateTime date;
  final String content;
  final String mood;
  final List<String> tags;
  final String matchType;

  SearchResult({
    required this.date,
    required this.content,
    required this.mood,
    required this.tags,
    required this.matchType,
  });
}