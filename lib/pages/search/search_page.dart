import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/hot_search_result.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/pages/home/widgets/video_card.dart';
import 'package:videoweb_flutter/pages/video/video_detail_page.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/video_grid_layout.dart';

/// 全局搜索页（对应原生 SearchActivity.kt）
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // 热搜
  List<String> _hotKeywords = [];
  bool _loadingHot = false;

  // 搜索历史
  static const String _historyKey = 'search_history';
  List<String> _searchHistory = [];
  static const int _maxHistory = 20;

  // 搜索结果
  List<Video> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
    _loadHotKeywords();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHotKeywords() async {
    setState(() => _loadingHot = true);
    try {
      final res = await _api.getHotSearchKeywords(limit: 10);
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data != null) {
          final hotResult = HotSearchResult.fromJson(data as Map<String, dynamic>);
          setState(() => _hotKeywords = hotResult.allKeywords);
        }
      }
    } catch (_) {}
    setState(() => _loadingHot = false);
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey);
    if (history != null) {
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _saveSearchHistory(String keyword) async {
    _searchHistory.remove(keyword);
    _searchHistory.insert(0, keyword);
    if (_searchHistory.length > _maxHistory) {
      _searchHistory = _searchHistory.sublist(0, _maxHistory);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() => _searchHistory = []);
  }

  Future<void> _doSearch(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;

    _searchCtrl.text = kw;
    _searchFocus.unfocus();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    await _saveSearchHistory(kw);

    try {
      final res = await _api.searchVideos(kw, page: 1, pageSize: 50);
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          setState(() {
            _searchResults = data
                .map((e) => Video.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        } else if (data is Map && data['list'] != null) {
          setState(() {
            _searchResults = (data['list'] as List)
                .map((e) => Video.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        } else {
          setState(() => _searchResults = []);
        }
      } else {
        setState(() => _searchResults = []);
      }
    } catch (_) {
      setState(() => _searchResults = []);
    }
    setState(() => _isSearching = false);
  }

  void _onTapVideo(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoDetailPage(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.chipBg,
                      foregroundColor: colors.textPrimary,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.homeSearchBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.homeSearchStroke),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '搜索视频',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: colors.homeTextHint),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _doSearch,
                        cursorColor: colors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: () => _doSearch(_searchCtrl.text),
                    style: IconButton.styleFrom(backgroundColor: colors.accent),
                    icon: const Icon(Icons.search_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }

    if (_hasSearched) {
      return _buildSearchResults(colors);
    }

    return _buildInitialView(colors);
  }

  Widget _buildInitialView(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 热搜
          if (_hotKeywords.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.trending_up, size: 20, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  '热搜推荐',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hotKeywords.asMap().entries.map((entry) {
                final index = entry.key;
                final keyword = entry.value;
                return ActionChip(
                  avatar: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: index < 3 ? colors.accent : colors.textHint,
                      fontSize: 12,
                    ),
                  ),
                  label: Text(keyword),
                  onPressed: () => _doSearch(keyword),
                );
              }).toList(),
            ),
            Divider(height: 32, color: colors.divider),
          ],

          // 搜索历史
          if (_searchHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, size: 20, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '搜索历史',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _clearSearchHistory,
                  child: Text('清除', style: TextStyle(color: colors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchHistory.map((keyword) {
                return InputChip(
                  label: Text(keyword),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _searchHistory.remove(keyword));
                    SharedPreferences.getInstance().then(
                      (prefs) => prefs.setStringList(_historyKey, _searchHistory),
                    );
                  },
                  onPressed: () => _doSearch(keyword),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppColors colors) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: colors.textHint),
            const SizedBox(height: 16),
            Text(
              '未找到相关视频',
              style: TextStyle(color: colors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: VideoGridLayout.gridPadding,
      gridDelegate: VideoGridLayout.boxDelegate(context),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final video = _searchResults[index];
        return VideoCard(
          video: video,
          onTap: () => _onTapVideo(video),
        );
      },
    );
  }
}
