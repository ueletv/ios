import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/banner.dart';
import 'package:videoweb_flutter/api/models/streamer.dart';
import 'package:videoweb_flutter/pages/home/widgets/banner_carousel.dart';
import 'package:videoweb_flutter/pages/live/live_room_page.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/main_tab_controller.dart';
import 'package:videoweb_flutter/services/socket_service.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/utils/live_access_helper.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 直播列表（对应原生 LiveFragment.kt + fragment_live.xml）
class LiveListPage extends StatefulWidget {
  const LiveListPage({super.key});

  @override
  State<LiveListPage> createState() => _LiveListPageState();
}

enum _LiveTab { hot, follow }

class _LiveListPageState extends State<LiveListPage> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final SocketService _hallSocket = SocketService();
  List<Streamer> _streamers = [];
  List<BannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;
  _LiveTab _tab = _LiveTab.hot;
  MainTabController? _tabController;
  int _lastReselectToken = 0;
  bool _syncHallListAfterLiveRoom = false;
  Timer? _quietReloadTimer;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  static const _liveTabIndex = 3;
  static const _streamerPageSize = 30;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBanners();
    _loadStreamers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabController = context.read<MainTabController>();
      _lastReselectToken = _tabController!.reselectToken;
      _tabController!.addListener(_onMainTabChanged);
      _onMainTabChanged();
    });
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onMainTabChanged);
    _quietReloadTimer?.cancel();
    _disconnectHallRealtime();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 320) {
      _loadMoreStreamers();
    }
  }

  void _scheduleQuietReload() {
    _quietReloadTimer?.cancel();
    _quietReloadTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _loadStreamers(quiet: true);
    });
  }

  void _onMainTabChanged() {
    final tabCtrl = _tabController ?? context.read<MainTabController>();
    if (tabCtrl.index == _liveTabIndex) {
      if (tabCtrl.reselectToken != _lastReselectToken) {
        _lastReselectToken = tabCtrl.reselectToken;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
        }
      }
      _connectHallRealtime();
      _checkFollowIntent();
    } else {
      _disconnectHallRealtime();
    }
  }

  String _normalizeStreamerId(dynamic id) {
    if (id == null) return '';
    final raw = id is num ? id.toInt().toString() : id.toString().trim();
    if (raw.isEmpty) return '';
    final noDecimal = raw.split('.').first;
    return noDecimal.replaceFirst(RegExp(r'^bx', caseSensitive: false), '');
  }

  void _connectHallRealtime() {
    final prefs = context.read<AppPrefs>();
    final token = prefs.token;
    if (token == null || token.isEmpty || _hallSocket.isConnected) return;

    _hallSocket.onStreamerListUpdate = (streamerId, status) {
      if (!mounted) return;
      final target = _normalizeStreamerId(streamerId);
      if (target.isEmpty) return;
      if (status == 0) {
        final removed = _streamers.any((s) => _normalizeStreamerId(s.id) == target);
        if (!removed) return;
        setState(() {
          _streamers = _streamers.where((s) => _normalizeStreamerId(s.id) != target).toList();
        });
      } else if (status == 1) {
        final exists = _streamers.any((s) => _normalizeStreamerId(s.id) == target);
        if (!exists) _scheduleQuietReload();
      }
    };
    _hallSocket.onAuthenticated = (_) {
      if (mounted && _syncHallListAfterLiveRoom && _streamers.isNotEmpty) {
        _syncHallListAfterLiveRoom = false;
        _scheduleQuietReload();
      }
    };
    _hallSocket.connect(token);
  }

  void _disconnectHallRealtime() {
    _hallSocket.onStreamerListUpdate = null;
    _hallSocket.onAuthenticated = null;
    _hallSocket.disconnect();
  }

  void _checkFollowIntent() {
    final tabCtrl = _tabController ?? context.read<MainTabController>();
    if (tabCtrl.index != 3) return;
    if (!tabCtrl.consumeLiveFollow()) return;
    if (_tab != _LiveTab.follow) {
      setState(() => _tab = _LiveTab.follow);
      _loadStreamers(force: true);
    }
  }

  Future<void> _loadBanners() async {
    try {
      final res = await _api.getBannerList(type: 'live');
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          final list = data
              .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => (a.sort ?? 0).compareTo(b.sort ?? 0));
          if (mounted) setState(() => _banners = list);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStreamers({bool force = false, bool quiet = false}) async {
    if (_isLoading && !force && !quiet) return;
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });
    }
    try {
      final res = await _api.getStreamerList(
        type: _tab == _LiveTab.follow ? 'follow' : null,
        page: 1,
        pageSize: _streamerPageSize,
      );
      if (ApiResult.isSuccess(res)) {
        final rows = ApiParse.extractList(res.data['data']);
        final list = rows.map(Streamer.fromJson).toList();
        setState(() {
          _streamers = list;
          _currentPage = 1;
          _hasMore = list.length >= _streamerPageSize;
          _isLoading = false;
        });
        return;
      }
      if (!quiet) {
        setState(() {
          _isLoading = false;
          _error = ApiResult.getErrorMessage(res) ?? '加载失败';
        });
      }
    } catch (e) {
      if (!quiet) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreStreamers() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    try {
      final res = await _api.getStreamerList(
        type: _tab == _LiveTab.follow ? 'follow' : null,
        page: nextPage,
        pageSize: _streamerPageSize,
      );
      if (ApiResult.isSuccess(res)) {
        final rows = ApiParse.extractList(res.data['data']);
        final list = rows.map(Streamer.fromJson).toList();
        if (mounted) {
          setState(() {
            _streamers.addAll(list);
            _currentPage = nextPage;
            _hasMore = list.length >= _streamerPageSize;
            _isLoadingMore = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _selectTab(_LiveTab tab) {
    if (_tab == tab && _streamers.isNotEmpty) return;
    setState(() => _tab = tab);
    _loadStreamers(force: true);
  }

  void _openLiveRoom(Streamer streamer) {
    LiveAccessHelper.openLiveRoomIfAllowed(context, () {
      _syncHallListAfterLiveRoom = true;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LiveRoomPage(
          streamerId: streamer.id ?? '',
          playUrl: streamer.resolvedPlayUrl ?? '',
          streamerName: streamer.displayName,
          coverUrl: ImageUrl.getImageUrl(streamer.resolvedCover),
          onlineCount: streamer.onlineCount ?? 0,
          caipiaoInfo: streamer.caipiaoInfo,
        ),
      )).then((_) {
        if (!mounted) return;
        _syncHallListAfterLiveRoom = false;
        _scheduleQuietReload();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.watch<ThemeController>();
    final c = context.appColors;
    return ColoredBox(
      color: c.pageBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(c),
          if (_banners.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: BannerCarousel(
                items: _banners
                    .map((b) => BannerCarouselItem(
                          imageUrl: b.image,
                          title: b.title,
                          link: b.link,
                          linkType: b.linkType,
                          linkId: b.linkId,
                        ))
                    .toList(),
                onTap: (item) {
                  AdLinkHelper.openLink(
                    context,
                    linkType: item.linkType,
                    linkUrl: item.link,
                    linkId: item.linkId,
                  );
                },
              ),
            ),
            Expanded(child: _buildBody(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppColors c) {
    return Container(
      color: c.pageBg,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _liveTabLabel(c, '热门', _LiveTab.hot),
                  const SizedBox(width: 16),
                  _liveTabLabel(c, '关注', _LiveTab.follow),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveSearchPage()));
            },
            icon: Icon(Icons.search, color: c.accent),
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveTabLabel(AppColors c, String text, _LiveTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => _selectTab(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: selected ? 24 : 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? c.homeCategorySelected : c.homeCategoryNormal,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppColors c) {
    if (_isLoading && _streamers.isEmpty) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }
    return RefreshIndicator(
      color: c.accent,
      onRefresh: () async {
        await _loadBanners();
        await _loadStreamers(force: true);
      },
      child: _streamers.isEmpty
          ? ListView(
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Center(
                    child: Text(
                      _error != null
                          ? '加载失败，请检查网络后下拉刷新'
                          : _tab == _LiveTab.follow
                              ? '暂无关注的主播'
                              : '暂无主播，请稍后刷新',
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                  ),
                ),
              ],
            )
          : CustomScrollView(
              controller: _scrollController,
              primary: false,
              cacheExtent: 320,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                      childAspectRatio: 1 / 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final streamer = _streamers[index];
                        return _StreamerCard(streamer: streamer, onTap: () => _openLiveRoom(streamer));
                      },
                      childCount: _streamers.length,
                    ),
                  ),
                ),
                if (_isLoadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                        ),
                      ),
                    ),
                  ),
                if (!_hasMore && _streamers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      child: Center(
                        child: Text('没有更多了', style: TextStyle(color: c.textHint, fontSize: 13)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StreamerCard extends StatelessWidget {
  final Streamer streamer;
  final VoidCallback onTap;

  const _StreamerCard({required this.streamer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final gameName = streamer.caipiaoInfo?.nameZh?.trim() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        margin: const EdgeInsets.all(6),
        color: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: ImageUrl.getImageUrl(streamer.resolvedCover),
              fit: BoxFit.cover,
              memCacheWidth: 360,
              placeholder: (_, __) => Container(color: c.placeholderBg),
              errorWidget: (_, __, ___) => Container(
                color: c.chipBg,
                child: Icon(Icons.person, size: 48, color: c.textHint),
              ),
            ),
            if (gameName.isNotEmpty)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 88),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xCCF45A7A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    gameName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 54,
              bottom: 8,
              child: Text(
                streamer.displayName.isEmpty ? '未命名主播' : streamer.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 7,
              child: Text(
                '${streamer.onlineCount ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 直播搜索（对应 LiveSearchActivity.kt）
class LiveSearchPage extends StatefulWidget {
  const LiveSearchPage({super.key});

  @override
  State<LiveSearchPage> createState() => _LiveSearchPageState();
}

class _LiveSearchPageState extends State<LiveSearchPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Streamer> _results = [];
  bool _searching = false;

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _api.getStreamerList(keyword: keyword.trim(), page: 1, pageSize: 100);
      if (ApiResult.isSuccess(res)) {
        final rows = ApiParse.extractList(res.data['data']);
        setState(() => _results = rows.map(Streamer.fromJson).toList());
      }
    } catch (_) {}
    setState(() => _searching = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        backgroundColor: c.pageBg,
        foregroundColor: c.textPrimary,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: '搜索直播间',
            border: InputBorder.none,
            hintStyle: TextStyle(color: c.textHint),
          ),
          onChanged: _search,
          onSubmitted: _search,
        ),
      ),
      body: _searching
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _searchCtrl.text.isEmpty ? '输入关键词搜索直播间' : '未找到相关直播间',
                    style: TextStyle(color: c.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    childAspectRatio: 1 / 1.05,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final streamer = _results[index];
                    return _StreamerCard(
                      streamer: streamer,
                      onTap: () {
                        LiveAccessHelper.openLiveRoomIfAllowed(context, () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LiveRoomPage(
                              streamerId: streamer.id ?? '',
                              playUrl: streamer.resolvedPlayUrl ?? '',
                              streamerName: streamer.displayName,
                              coverUrl: ImageUrl.getImageUrl(streamer.resolvedCover),
                              onlineCount: streamer.onlineCount ?? 0,
                            ),
                          ));
                        });
                      },
                    );
                  },
                ),
    );
  }
}
