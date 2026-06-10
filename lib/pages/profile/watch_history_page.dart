import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/pages/home/widgets/video_card.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/pages/video/video_detail_page.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/video_grid_layout.dart';

/// 观看历史页（对应原生 WatchHistoryActivity.kt）
class WatchHistoryPage extends StatefulWidget {
  const WatchHistoryPage({super.key});

  @override
  State<WatchHistoryPage> createState() => _WatchHistoryPageState();
}

class _WatchHistoryPageState extends State<WatchHistoryPage> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Video> _videos = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _hasMore = true;
    });
    try {
      final res = await _api.getViewHistory(page: _page, pageSize: _pageSize);
      if (ApiResult.isSuccess(res)) {
        final data = _parseVideoList(res.data['data']);
        setState(() {
          _videos = data;
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final res = await _api.getViewHistory(page: _page, pageSize: _pageSize);
      if (ApiResult.isSuccess(res)) {
        final data = _parseVideoList(res.data['data']);
        setState(() {
          _videos.addAll(data);
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (_) {
      _page--;
    }
    if (mounted) setState(() => _isLoadingMore = false);
  }

  List<Video> _parseVideoList(dynamic data) {
    if (data is List) {
      return data.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  void _openVideoDetail(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoDetailPage(video: video)),
    );
  }

  Future<void> _clearHistory() async {
    final colors = context.appColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBg,
        title: Text('清空历史', style: TextStyle(color: colors.textPrimary)),
        content: Text('确定要清空所有观看历史吗？', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await _api.clearViewHistory();
      if (ApiResult.isSuccess(res)) {
        setState(() => _videos = []);
        _showToast('观看历史已清空');
      }
    } catch (_) {
      _showToast('操作失败');
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '观看历史',
      actions: [
        if (_videos.isNotEmpty)
          IconButton.filledTonal(
            onPressed: _clearHistory,
            style: IconButton.styleFrom(backgroundColor: colors.chipBg, foregroundColor: colors.textPrimary),
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
      ],
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _videos.isEmpty
              ? const ProfileEmptyState(icon: Icons.history, message: '暂无观看历史')
              : RefreshIndicator(
                  color: colors.accent,
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    controller: _scrollController,
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: VideoGridLayout.gridPadding,
                        sliver: SliverGrid(
                          gridDelegate: VideoGridLayout.sliverDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final video = _videos[index];
                              return VideoCard(
                                video: video,
                                onTap: () => _openVideoDetail(video),
                              );
                            },
                            childCount: _videos.length,
                          ),
                        ),
                      ),
                      if (_isLoadingMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
