import 'dart:async';
import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/lottery.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';

/// 快速金额选项
const List<int> _quickAmounts = [2, 10, 50, 100, 1000, 200000];

/// 下注弹窗（对应原生 LiveRoomBetDialogFragment.kt）
///
/// 底部 66% 高度 Dialog，包含：
/// - 玩法分类 Tab
/// - 投注选项
/// - 金额输入/快速选择
/// - 倍数选择
/// - 确认投注
/// - 倒计时
class BetDialog extends StatefulWidget {
  final LotteryItem lotteryItem;
  final List<LotteryWanfa> wanfaList;
  final String biaoshi;

  const BetDialog({
    super.key,
    required this.lotteryItem,
    required this.wanfaList,
    this.biaoshi = '',
  });

  @override
  State<BetDialog> createState() => _BetDialogState();
}

class _BetDialogState extends State<BetDialog> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  late TabController _tabController;

  // 选中的玩法 Tab 索引
  int _selectedTabIndex = 0;

  // 投注选项选中状态：<玩法ID, <选项名, 是否选中>>
  final Map<int, Map<String, bool>> _selectedPlays = {};

  // 金额
  final TextEditingController _amountCtrl = TextEditingController();
  int _selectedQuickAmount = -1;

  // 倍数列表
  List<BeishuItem> _beishuList = [];
  int _selectedBeishuIndex = 0;
  bool _loadingBeishu = true;

  // 倒计时
  Timer? _countdownTimer;
  int _remainingSeconds = 60;

  // 投注中
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.wanfaList.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _loadBeishu();
    _startCountdown();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBeishu() async {
    try {
      final res = await _api.getBeishuList();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          setState(() {
            _beishuList = data
                .map((e) => BeishuItem.fromJson(e as Map<String, dynamic>))
                .where((b) => b.isEnabled)
                .toList();
            _loadingBeishu = false;
          });
          return;
        }
      }
      setState(() => _loadingBeishu = false);
    } catch (_) {
      setState(() => _loadingBeishu = false);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  /// 切换投注选项选中
  void _togglePlaySelected(int wanfaId, String playName) {
    _selectedPlays.putIfAbsent(wanfaId, () => {});
    setState(() {
      _selectedPlays[wanfaId]![playName] =
          !(_selectedPlays[wanfaId]![playName] ?? false);
    });
  }

  /// 获取当前 Tab 下已选中的玩法名称
  List<String> _getCurrentSelectedPlays() {
    if (widget.wanfaList.isEmpty || _selectedTabIndex >= widget.wanfaList.length) {
      return [];
    }
    final wanfa = widget.wanfaList[_selectedTabIndex];
    final selected = _selectedPlays[wanfa.id] ?? {};
    return selected.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  /// 获取投注金额
  int get _betAmount {
    final text = _amountCtrl.text.trim();
    if (text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }

  /// 获取选中倍数
  int get _beishu {
    if (_beishuList.isEmpty) return 1;
    if (_selectedBeishuIndex >= _beishuList.length) return 1;
    return _beishuList[_selectedBeishuIndex].beishuValue;
  }

  /// 计算总金额
  int get _totalAmount {
    final selected = _getCurrentSelectedPlays();
    if (selected.isEmpty || _betAmount <= 0) return 0;
    return _betAmount * selected.length * _beishu;
  }

  void _onQuickAmount(int amount) {
    setState(() {
      _selectedQuickAmount = amount;
      _amountCtrl.text = amount.toString();
    });
  }

  Future<void> _submitBet() async {
    final selected = _getCurrentSelectedPlays();
    if (selected.isEmpty) {
      AppToast.show('请至少选择一个投注选项', context: context);
      return;
    }
    if (_betAmount <= 0) {
      AppToast.show('请输入投注金额', context: context);
      return;
    }
    if (_remainingSeconds <= 0) {
      AppToast.show('当前期已封盘，请等待下期', context: context);
      return;
    }

    setState(() => _submitting = true);

    try {
      final wanfa = widget.wanfaList[_selectedTabIndex];
      final prefs = context.read<AppPrefs>();
      final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
        return _api.caipiaoTouzhu({
          'caipiao_id': widget.lotteryItem.id,
          'biaoshi': widget.biaoshi,
          'wanfa_id': wanfa.id,
          'plays': selected,
          'amount': _betAmount,
          'beishu': _beishu,
        });
      });

      if (res != null && ApiResult.isSuccess(res)) {
        if (mounted) {
          AppToast.show('投注成功', context: context);
          Navigator.of(context).pop();
        }
      } else {
        final msg = res != null ? (ApiResult.getErrorMessage(res) ?? '投注失败') : '投注失败';
        if (mounted) {
          AppToast.show(msg, context: context);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('投注失败: $e', context: context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.66,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D2B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题 + 倒计时
          _buildHeader(),
          // 玩法 Tab
          if (widget.wanfaList.length > 1) _buildTabs(),
          // 内容
          Expanded(child: _buildContent()),
          // 底部操作栏
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.lotteryItem.nameZh,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 倒计时
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _remainingSeconds > 10
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: _remainingSeconds > 10 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: _remainingSeconds > 10 ? Colors.green : Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.amber,
        indicatorWeight: 3,
        labelColor: Colors.amber,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: widget.wanfaList.map((w) => Tab(text: w.name)).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.wanfaList.isEmpty) {
      return const Center(
        child: Text('暂无玩法', style: TextStyle(color: Colors.white54)),
      );
    }

    if (_selectedTabIndex >= widget.wanfaList.length) {
      return const SizedBox.shrink();
    }

    final wanfa = widget.wanfaList[_selectedTabIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 投注选项
          if (wanfa.plays != null && wanfa.plays!.isNotEmpty) ...[
            const Text(
              '选择投注选项',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wanfa.plays!.map((play) {
                final isSelected =
                    _selectedPlays[wanfa.id]?[play.name] ?? false;
                return GestureDetector(
                  onTap: () => _togglePlaySelected(wanfa.id, play.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber.withOpacity(0.15)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          play.name,
                          style: TextStyle(
                            color: isSelected ? Colors.amber : Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (play.rate != null && play.rate!.isNotEmpty)
                          Text(
                            '赔率 ${play.rate}',
                            style: TextStyle(
                              color: isSelected ? Colors.amber : Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('暂无投注选项', style: TextStyle(color: Colors.white38)),
              ),
            ),
          const SizedBox(height: 20),

          // 金额输入
          const Text(
            '投注金额',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: '输入金额',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixText: '¥ ',
              prefixStyle: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: const Color(0xFF1A1A4E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) {
              setState(() => _selectedQuickAmount = -1);
            },
          ),
          const SizedBox(height: 10),

          // 快速金额
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((amount) {
              final isSelected = _selectedQuickAmount == amount;
              return GestureDetector(
                onTap: () => _onQuickAmount(amount),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.withOpacity(0.15)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? Colors.amber : Colors.white12,
                    ),
                  ),
                  child: Text(
                    amount >= 10000 ? '${amount ~/ 10000}万' : '$amount',
                    style: TextStyle(
                      color: isSelected ? Colors.amber : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 倍数选择
          const Text(
            '选择倍数',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          _loadingBeishu
              ? const SizedBox(
                  height: 36,
                  child: Center(child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)),
                )
              : _beishuList.isEmpty
                  ? const Text('暂无可选倍数', style: TextStyle(color: Colors.white38, fontSize: 13))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_beishuList.length, (i) {
                        final isSelected = _selectedBeishuIndex == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBeishuIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.amber.withOpacity(0.15)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? Colors.amber : Colors.white12,
                              ),
                            ),
                            child: Text(
                              '${_beishuList[i].beishuValue}倍',
                              style: TextStyle(
                                color: isSelected ? Colors.amber : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final selected = _getCurrentSelectedPlays();
    final total = _totalAmount;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D2B),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 选中信息
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已选 ${selected.length} 项',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total > 0 ? '合计: ¥$total' : '',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 确认投注
            SizedBox(
              height: 44,
              width: 140,
              child: ElevatedButton(
                onPressed:
                    selected.isNotEmpty && _betAmount > 0 && !_submitting
                        ? _submitBet
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        '确认投注',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
