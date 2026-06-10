import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/lottery.dart';
import 'package:videoweb_flutter/pages/lottery/betting_record_page.dart';
import 'package:videoweb_flutter/pages/lottery/lottery_record_page.dart';
import 'package:videoweb_flutter/pages/lottery/widgets/bet_dialog.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 彩票详情/下注页面（对应原生 LotteryDetailActivity.kt）
class LotteryDetailPage extends StatefulWidget {
  final LotteryItem lotteryItem;

  const LotteryDetailPage({super.key, required this.lotteryItem});

  @override
  State<LotteryDetailPage> createState() => _LotteryDetailPageState();
}

class _LotteryDetailPageState extends State<LotteryDetailPage> {
  final ApiService _api = ApiService();

  // 彩票玩法
  List<LotteryWanfa> _wanfaList = [];
  bool _loadingWanfa = true;

  // 倒计时
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  String _currentExpects = '';
  String _biaoshi = '';

  @override
  void initState() {
    super.initState();
    _biaoshi = widget.lotteryItem.biaoshi ?? '';
    _currentExpects = widget.lotteryItem.expects ?? '';
    _loadWanfa();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWanfa() async {
    setState(() => _loadingWanfa = true);
    try {
      final res = await _api.getCaipiaoWanfa(widget.lotteryItem.id, biaoshi: _biaoshi);
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          setState(() {
            _wanfaList = data
                .map((e) => LotteryWanfa.fromJson(e as Map<String, dynamic>))
                .toList();
            _loadingWanfa = false;
          });
          return;
        }
      }
      setState(() => _loadingWanfa = false);
    } catch (_) {
      setState(() => _loadingWanfa = false);
    }
  }

  void _startCountdown() {
    _loadTimes();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _loadTimes();
      }
    });
  }

  Future<void> _loadTimes() async {
    try {
      final res = await _api.getCaipiaoTimes(
        caipiaoId: widget.lotteryItem.id,
        biaoshi: _biaoshi,
      );
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map) {
          final endTime = data['end_time'];
          if (endTime != null) {
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            _remainingSeconds = (endTime as int) - now;
            if (_remainingSeconds < 0) _remainingSeconds = 0;
          }
          final expects = data['expects'] as String?;
          if (expects != null && expects.isNotEmpty) {
            _currentExpects = expects;
          }
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return '封盘中';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showBetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BetDialog(
        lotteryItem: widget.lotteryItem,
        wanfaList: _wanfaList,
        biaoshi: _biaoshi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D2B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.lotteryItem.nameZh,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            tooltip: '开奖记录',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LotteryRecordPage(
                  caipiaoId: widget.lotteryItem.id,
                  biaoshi: _biaoshi,
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white70),
            tooltip: '下注记录',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BettingRecordPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _loadWanfa();
              _loadTimes();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部信息
          _buildTopInfo(),
          // 玩法列表
          Expanded(child: _buildWanfaList()),
        ],
      ),
      // 底部下注按钮
      bottomNavigationBar: _buildBottomBetBar(),
    );
  }

  Widget _buildTopInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A4E), Color(0xFF2D2D6B)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (widget.lotteryItem.icon?.isNotEmpty == true)
            CachedNetworkImage(
              imageUrl: ImageUrl.getImageUrl(widget.lotteryItem.icon),
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
                  Container(width: 48, height: 48, color: Colors.transparent),
              errorWidget: (_, __, ___) => const Icon(
                Icons.sports_esports, color: Colors.amber, size: 40,
              ),
            )
          else
            const Icon(Icons.sports_esports, color: Colors.amber, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lotteryItem.nameZh,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '第 $_currentExpects 期',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          // 倒计时
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds > 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _remainingSeconds > 0 ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  color: _remainingSeconds > 0 ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatCountdown(_remainingSeconds),
                  style: TextStyle(
                    color: _remainingSeconds > 0 ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWanfaList() {
    if (_loadingWanfa) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    if (_wanfaList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text('暂无玩法', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadWanfa,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _wanfaList.length,
      itemBuilder: (context, index) {
        final wanfa = _wanfaList[index];
        return _WanfaCard(wanfa: wanfa);
      },
    );
  }

  Widget _buildBottomBetBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D2B),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _remainingSeconds > 0 ? _showBetDialog : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
          child: Text(
            _remainingSeconds > 0 ? '立即投注' : '当前期已封盘',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/// 玩法卡片
class _WanfaCard extends StatelessWidget {
  final LotteryWanfa wanfa;

  const _WanfaCard({required this.wanfa});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A4E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 玩法名称
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D6B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                if (wanfa.icon?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(wanfa.icon!, style: const TextStyle(fontSize: 18)),
                  ),
                Text(
                  wanfa.name,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 玩法选项
          if (wanfa.plays != null && wanfa.plays!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: wanfa.plays!.map((play) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          play.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        if (play.rate != null && play.rate!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '赔率 ${play.rate}',
                            style: const TextStyle(color: Colors.amber, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '暂无选项',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
