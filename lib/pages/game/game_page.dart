import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/banner.dart';
import 'package:videoweb_flutter/api/models/lottery.dart';
import 'package:videoweb_flutter/api/models/notice.dart';
import 'package:videoweb_flutter/pages/lottery/betting_record_page.dart';
import 'package:videoweb_flutter/pages/lottery/lottery_detail_page.dart';
import 'package:videoweb_flutter/pages/profile/customer_service_page.dart';
import 'package:videoweb_flutter/pages/profile/recharge_page.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 游戏/彩票大厅页面（对应原生 GameFragment.kt）
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();

  // Banner
  List<BannerModel> _banners = [];
  int _currentBanner = 0;
  Timer? _bannerTimer;

  // 公告
  List<Notice> _notices = [];

  // 彩票列表
  List<LotteryItem> _lotteryList = [];

  // 余额
  int _coin = 0;

  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // 并发加载
    await Future.wait([
      _loadBanners(),
      _loadNotices(),
      _loadLotteryList(),
      _loadUserInfo(),
    ]);

    if (mounted) {
      setState(() => _loading = false);
      _startBannerAutoPlay();
    }
  }

  Future<void> _loadBanners() async {
    try {
      final res = await _api.getBannerList(type: 'game');
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          _banners = data
              .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadNotices() async {
    try {
      final res = await _api.getNoticeList();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          _notices = data
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLotteryList() async {
    try {
      final res = await _api.getCaipiaoList();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          _lotteryList = data
              .map((e) => LotteryItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadUserInfo() async {
    try {
      final res = await _api.getUserInfo();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map) {
          _coin = (data['coin'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshCoin() async {
    await _loadUserInfo();
    if (mounted) setState(() {});
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _currentBanner = (_currentBanner + 1) % _banners.length;
      });
    });
  }

  void _openLotteryDetail(LotteryItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LotteryDetailPage(lotteryItem: item),
    ));
  }

  void _openRecharge() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RechargePage()),
    ).then((_) => _refreshCoin());
  }

  void _openCustomerService() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerServicePage()),
    );
  }

  void _openBetHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BettingRecordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ColoredBox(
      color: const Color(0xFFF6F7FB),
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '彩票大厅',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: Colors.grey[400], size: 44),
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loadData,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: CustomScrollView(
                            primary: false,
                            slivers: [
                              SliverToBoxAdapter(child: _buildBalanceBar()),
                              if (_banners.isNotEmpty) SliverToBoxAdapter(child: _buildBanner()),
                              if (_notices.isNotEmpty) SliverToBoxAdapter(child: _buildNoticeMarquee()),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                sliver: _buildLotteryGrid(),
                              ),
                            ],
                          ),
                        ),
            ),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBalanceBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A4E), Color(0xFF2D2D6B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          const Text('余额', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          Text('$_coin', style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: _refreshCoin,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.refresh, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      height: 160,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Stack(
        children: [
          PageView.builder(
            onPageChanged: (index) {
              setState(() => _currentBanner = index);
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: ImageUrl.getImageUrl(banner.image),
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[800]),
                  errorWidget: (_, __, ___) =>
                      Container(color: Colors.grey[800], child: const Icon(Icons.image, color: Colors.white24)),
                ),
              );
            },
          ),
          // 指示器
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentBanner ? 20 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == _currentBanner ? Colors.amber : Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeMarquee() {
    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '公告',
              style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _notices.length,
              itemBuilder: (context, index) {
                final notice = _notices[index];
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: Text(
                      notice.content ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotteryGrid() {
    if (_lotteryList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports, color: Colors.white24, size: 64),
              const SizedBox(height: 12),
              const Text('暂无彩票', style: TextStyle(color: Colors.white54, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = _lotteryList[index];
          return _LotteryCard(
            item: item,
            onTap: () => _openLotteryDetail(item),
          );
        },
        childCount: _lotteryList.length,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D2B),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomActionButton(
              icon: Icons.credit_card,
              label: '充值',
              color: Colors.amber,
              onTap: _openRecharge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BottomActionButton(
              icon: Icons.headset_mic,
              label: '客服',
              color: Colors.lightBlue,
              onTap: _openCustomerService,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BottomActionButton(
              icon: Icons.receipt_long,
              label: '投注记录',
              color: Colors.green,
              onTap: _openBetHistory,
            ),
          ),
        ],
      ),
    );
  }
}

/// 彩票卡片
class _LotteryCard extends StatelessWidget {
  final LotteryItem item;
  final VoidCallback onTap;

  const _LotteryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E4A), Color(0xFF2A2A5E)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标
            if (item.icon?.isNotEmpty == true)
              CachedNetworkImage(
                imageUrl: ImageUrl.getImageUrl(item.icon),
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    Container(width: 44, height: 44, color: Colors.transparent),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.sports_esports,
                  color: Colors.amber,
                  size: 36,
                ),
              )
            else
              const Icon(Icons.sports_esports, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            // 名称
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.nameZh,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            // 期号
            if (item.expects?.isNotEmpty == true)
              Text(
                '第${item.expects}期',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作按钮
class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
