import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/widgets/home_logo.dart';
import 'package:videoweb_flutter/pages/home/home_category_page.dart';
import 'package:videoweb_flutter/pages/home/home_layout_metrics.dart';
import 'package:videoweb_flutter/pages/search/search_page.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/home_prefetch_cache.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 首页主页面（对应原生 HomeFragment.kt）
/// 包含顶部分类 Tab + 每个分类对应的 HomeCategoryPage
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final List<GlobalKey> _categoryTabKeys = [];

  List<VideoCategory> _categories = [];
  Map<String, List<VideoCategory>> _subCategoriesByParentId = {};
  bool _isLoadingCategories = false;
  String? _categoryError;
  String? _homeLogoUrl;
  String? _homeLogoText;

  /// 排序选项（与原生 HomeCategoryPageState 一致）
  final List<_SortOption> _sortOptions = const [
    _SortOption('latest', '最新'),
    _SortOption('hot', '最热'),
  ];
  _SortOption _currentSort = const _SortOption('latest', '最新');

  /// 每个一级分类独立的二级筛选（对应 HomeCategoryPageState.selectedSubCategoryId）
  final Map<String, String?> _selectedSubByParentId = {};

  @override
  void initState() {
    super.initState();
    _applyLogoFromConfig(AppConfigCache.cached);
    _loadHomeLogo();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _applyLogoFromConfig(Map<String, dynamic>? config) {
    if (config == null) return;
    final logo = HomeLogo.logoFromConfig(config);
    final text = _firstString(config, const [
      'home_logo_text',
      'site_name',
      'app_name',
      'name',
    ]);
    if (logo == null && text == null) return;
    _homeLogoUrl = logo ?? _homeLogoUrl;
    _homeLogoText = text ?? _homeLogoText;
  }

  Future<void> _loadHomeLogo() async {
    try {
      final config = await AppConfigCache.fetch();
      if (!mounted || config == null) return;
      setState(() {
        _applyLogoFromConfig(config);
      });
    } catch (_) {}
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<void> _loadCategories() async {
    final cached = HomePrefetchCache.cached;
    if (cached != null && cached.isNotEmpty) {
      _applyCategories(cached);
      return;
    }

    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });
    try {
      final list = await HomePrefetchCache.prefetch();
      if (!mounted) return;
      if (list.isNotEmpty) {
        _applyCategories(list);
      } else {
        setState(() => _categoryError = '分类加载失败');
      }
    } catch (e) {
      if (mounted) setState(() => _categoryError = e.toString());
    }
    if (mounted) setState(() => _isLoadingCategories = false);
  }

  void _applyCategories(List<VideoCategory> list) {
    final hierarchy = _buildCategoryHierarchy(list);
    final topLevel = hierarchy.$1;
    setState(() {
      _isLoadingCategories = false;
      _categoryError = null;
      _categories = topLevel;
      _subCategoriesByParentId = hierarchy.$2;
      _categoryTabKeys
        ..clear()
        ..addAll(List.generate(topLevel.length + 2, (_) => GlobalKey()));
      _tabController?.dispose();
      _tabController = TabController(
        length: topLevel.length + 2,
        vsync: this,
      )..addListener(() {
          if (!mounted) return;
          setState(() {});
          _scrollCategoryTabIntoView(_tabController!.index);
        });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollCategoryTabIntoView(0, jump: true));
  }

  (List<VideoCategory>, Map<String, List<VideoCategory>>) _buildCategoryHierarchy(List<VideoCategory> all) {
    final filtered = all.where((cat) {
      final name = cat.name?.trim() ?? '';
      return name.isNotEmpty && name != '短视频';
    }).toList();

    final typeIdToDbId = <int, String>{};
    final dbIdToDbId = <int, String>{};
    for (final cat in filtered) {
      final id = _categoryIdString(cat.id);
      final dbId = _parseInt(cat.id);
      if (id == null || dbId == null) continue;
      dbIdToDbId[dbId] = id;
      final typeId = _parseInt(cat.typeId) ?? dbId;
      typeIdToDbId[typeId] = id;
      if (typeId != dbId) {
        typeIdToDbId.putIfAbsent(dbId, () => id);
      }
    }

    final top = <VideoCategory>[];
    final subs = <String, List<VideoCategory>>{};
    for (final cat in filtered) {
      final parentRef = _parseInt(cat.parentId);
      final id = _categoryIdString(cat.id);
      if (id == null) continue;
      if (parentRef == null || parentRef == 0) {
        top.add(cat);
        subs.putIfAbsent(id, () => <VideoCategory>[]);
      } else {
        final parentId = typeIdToDbId[parentRef] ?? dbIdToDbId[parentRef];
        if (parentId != null) {
          subs.putIfAbsent(parentId, () => <VideoCategory>[]).add(cat);
        } else {
          top.add(cat);
          subs.putIfAbsent(id, () => <VideoCategory>[]);
        }
      }
    }

    top.sort((a, b) => (a.sort ?? 0).compareTo(b.sort ?? 0));
    final sortedSubs = subs.map((key, value) {
      final list = [...value]..sort((a, b) => (a.sort ?? 0).compareTo(b.sort ?? 0));
      return MapEntry(key, list);
    });
    return (top, sortedSubs);
  }

  int? _parseInt(dynamic value) => ApiParse.asInt(value);

  String? _categoryIdString(dynamic value) {
    final n = _parseInt(value);
    if (n != null && n > 0) return n.toString();
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  void _onSubCategorySelected(String parentId, String? subCategoryId) {
    setState(() => _selectedSubByParentId[parentId] = subCategoryId);
  }

  /// 与原生 resolveVideoCategoryQuery 一致
  ({String? categoryId, String? categoryIds}) _resolveVideoCategoryQuery(
    String? parentId,
    List<VideoCategory> children,
  ) {
    if (parentId == null) return (categoryId: null, categoryIds: null);
    final subId = _selectedSubByParentId[parentId];
    if (subId != null && subId.isNotEmpty) {
      return (categoryId: subId, categoryIds: null);
    }
    if (children.isNotEmpty) {
      final ids = <String>{parentId};
      for (final child in children) {
        final cid = _categoryIdString(child.id);
        if (cid != null) ids.add(cid);
      }
      return (categoryId: null, categoryIds: ids.join(','));
    }
    return (categoryId: parentId, categoryIds: null);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    // 勿嵌套 Scaffold（外层 MainPage 已有），避免 FAB 槽位未布局时 hit test 报错
    return ColoredBox(
      color: colors.pageBg,
      child: SafeArea(
        bottom: false,
        child: HomePageBackground(
          child: Column(
            children: [
              _buildHeader(colors),
              _buildCategoryStrip(colors),
              Expanded(child: _buildBody(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    final hasLogo = _homeLogoUrl != null && _homeLogoUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeLayoutMetrics.headerPaddingH,
        HomeLayoutMetrics.headerPaddingTop,
        HomeLayoutMetrics.headerPaddingH,
        HomeLayoutMetrics.headerPaddingBottom,
      ),
      child: Row(
        children: [
          if (hasLogo) ...[
            _buildHomeLogo(colors),
            const SizedBox(width: HomeLayoutMetrics.logoMarginEnd),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              ),
              child: Container(
                height: HomeLayoutMetrics.searchBarHeight,
                padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
                decoration: BoxDecoration(
                  color: colors.homeSearchBg,
                  borderRadius: BorderRadius.circular(HomeLayoutMetrics.searchBarRadius),
                  border: Border.all(color: colors.homeSearchStroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '搜索你想看的…',
                        style: TextStyle(fontSize: 15, color: colors.homeTextHint),
                      ),
                    ),
                    Icon(Icons.search_rounded, size: 22, color: colors.homeTextHint),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeLogo(AppColors colors) {
    return HomeLogo(logoUrl: _homeLogoUrl);
  }

  /// 构建分类 Tab（推荐/新片/各分类）
  List<Widget> _buildCategoryTabs() {
    final tabs = <Widget>[
      const Tab(text: '推荐'),
      const Tab(text: '新片'),
    ];
    for (final cat in _categories) {
      tabs.add(Tab(text: cat.name ?? '分类'));
    }
    return tabs;
  }

  List<({String label, int index})> _mainCategoryTabItems() {
    return [
      (label: '推荐', index: 0),
      (label: '新片', index: 1),
      ..._categories.asMap().entries.map(
        (e) => (label: e.value.name ?? '分类', index: e.key + 2),
      ),
    ];
  }

  Widget _buildCategoryStrip(AppColors colors) {
    final tabs = _mainCategoryTabItems();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeLayoutMetrics.categoryPaddingStart,
        HomeLayoutMetrics.categoryPaddingTop,
        HomeLayoutMetrics.categoryPaddingEnd,
        HomeLayoutMetrics.categoryPaddingBottom,
      ),
      child: SingleChildScrollView(
        primary: false,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 0),
              Builder(
                builder: (context) {
                  final item = tabs[i];
                  final isSelected = _tabController?.index == item.index;
                  return GestureDetector(
                    key: _categoryTabKeys.length > i ? _categoryTabKeys[i] : null,
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _tabController?.animateTo(item.index);
                      _scrollCategoryTabIntoView(item.index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HomeLayoutMetrics.categoryTabPaddingH,
                        vertical: HomeLayoutMetrics.categoryTabPaddingV,
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: isSelected
                              ? HomeLayoutMetrics.categorySelectedFontSize
                              : HomeLayoutMetrics.categoryNormalFontSize,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          height: 1.0,
                          color: isSelected ? colors.homeCategorySelected : colors.homeCategoryNormal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scrollCategoryTabIntoView(int index, {bool jump = false}) {
    if (index < 0 || index >= _categoryTabKeys.length) return;
    final ctx = _categoryTabKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: jump ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoadingCategories) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (_categoryError != null) {
      return _buildSingleCategoryPage(null, isRecommend: true);
    }
    if (_categories.isEmpty) {
      return _buildSingleCategoryPage(null, isRecommend: true);
    }
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSingleCategoryPage(null, isRecommend: true),
              _buildSingleCategoryPage(null, isNewFilms: true),
              for (final cat in _categories)
                _buildSingleCategoryPage(_categoryIdString(cat.id), category: cat),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleCategoryPage(
    String? categoryId, {
    bool isRecommend = false,
    bool isNewFilms = false,
    String? sort,
    VideoCategory? category,
  }) {
    final parentId = category != null ? _categoryIdString(category.id) : categoryId;
    final children = parentId == null
        ? const <VideoCategory>[]
        : (_subCategoriesByParentId[parentId] ?? const <VideoCategory>[]);
    final query = isRecommend || isNewFilms
        ? (categoryId: null, categoryIds: null)
        : _resolveVideoCategoryQuery(parentId, children);
    // 主分类 Tab 用稳定 key；二级分类/排序变化由 HomeCategoryPage.didUpdateWidget 局部刷新列表
    final pageKey = isRecommend
        ? 'home-recommend'
        : isNewFilms
            ? 'home-newfilms'
            : 'home-cat-${parentId ?? 'unknown'}';

    return HomeCategoryPage(
      key: ValueKey(pageKey),
      categoryId: query.categoryId,
      categoryIds: query.categoryIds,
      isRecommend: isRecommend,
      isNewFilms: isNewFilms,
      sort: sort ?? _currentSort.field,
      showBanner: isRecommend,
      showGridAds: true,
      showSortRow: !isRecommend && !isNewFilms,
      subCategories: children,
      selectedSubCategoryId: parentId != null ? _selectedSubByParentId[parentId] : null,
      onSubCategorySelected: parentId == null
          ? null
          : (subId) => _onSubCategorySelected(parentId, subId),
      onSortChanged: parentId == null
          ? null
          : (field) {
              final label = field == 'hot' ? '最热' : '最新';
              setState(() => _currentSort = _SortOption(field, label));
            },
    );
  }
}

/// 排序选项
class _SortOption {
  final String field;
  final String label;

  const _SortOption(this.field, this.label);

  @override
  bool operator ==(Object other) =>
      other is _SortOption && field == other.field;

  @override
  int get hashCode => field.hashCode;
}
