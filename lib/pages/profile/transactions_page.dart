import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 收支明细（对应原生 TransactionsActivity）
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTransactionsList(page: 1, pageSize: 30, type: _typeFilter);
      if (ApiResult.isSuccess(res)) {
        setState(() => _records = ApiParse.extractList(res.data['data']));
      }
    } catch (_) {
      if (mounted) AppToast.show('加载失败', context: context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '收支明细',
      actions: [
        PopupMenuButton<String?>(
          icon: Icon(Icons.filter_list, color: colors.textPrimary),
          color: colors.cardBg,
          onSelected: (value) {
            _typeFilter = value;
            _load();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: null, child: Text('全部', style: TextStyle(color: colors.textPrimary))),
            PopupMenuItem(value: 'income', child: Text('收入', style: TextStyle(color: colors.textPrimary))),
            PopupMenuItem(value: 'expense', child: Text('支出', style: TextStyle(color: colors.textPrimary))),
          ],
        ),
      ],
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _records.isEmpty
              ? const ProfileEmptyState(icon: Icons.receipt_long, message: '暂无记录')
              : RefreshIndicator(
                  color: colors.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _records[index];
                      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                      final isIncome = amount >= 0;
                      return ProfileThemedCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title']?.toString() ??
                                        item['type_text']?.toString() ??
                                        item['remark']?.toString() ??
                                        '交易',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['created_at']?.toString() ?? item['create_time']?.toString() ?? '',
                                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isIncome ? '+' : ''}$amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
