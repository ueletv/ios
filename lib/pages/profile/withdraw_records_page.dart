import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 提现记录（对应原生 WithdrawRecordsActivity）
class WithdrawRecordsPage extends StatefulWidget {
  const WithdrawRecordsPage({super.key});

  @override
  State<WithdrawRecordsPage> createState() => _WithdrawRecordsPageState();
}

class _WithdrawRecordsPageState extends State<WithdrawRecordsPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
        _hasMore = true;
      });
    }
    try {
      final res = await _api.getWithdrawList(page: _page, pageSize: _pageSize);
      if (ApiResult.isSuccess(res)) {
        final list = ApiParse.extractList(res.data['data']);
        setState(() {
          if (refresh) {
            _records = list;
          } else {
            _records.addAll(list);
          }
          _hasMore = list.length >= _pageSize;
        });
      }
    } catch (_) {
      if (mounted) AppToast.show('加载失败', context: context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load();
    setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '提现记录',
      body: _loading && _records.isEmpty
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _records.isEmpty
              ? const ProfileEmptyState(icon: Icons.account_balance_wallet_outlined, message: '暂无提现记录')
              : RefreshIndicator(
                  color: colors.accent,
                  onRefresh: () => _load(refresh: true),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) _loadMore();
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _records.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index >= _records.length) {
                          return Center(child: Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent)));
                        }
                        return _WithdrawRecordCard(colors: colors, item: _records[index]);
                      },
                    ),
                  ),
                ),
    );
  }
}

class _WithdrawRecordCard extends StatelessWidget {
  final AppColors colors;
  final Map<String, dynamic> item;

  const _WithdrawRecordCard({required this.colors, required this.item});

  @override
  Widget build(BuildContext context) {
    final amount = item['amount']?.toString() ?? '0';
    final status = item['status_text']?.toString() ?? item['status']?.toString() ?? '';
    final time = item['created_at']?.toString() ?? item['create_time']?.toString() ?? '';
    final account = item['account_number']?.toString() ?? '';

    return ProfileThemedCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¥$amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                if (account.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(account, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                ],
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(color: colors.textHint, fontSize: 12)),
                ],
              ],
            ),
          ),
          Text(status, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
        ],
      ),
    );
  }
}
