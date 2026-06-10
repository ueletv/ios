import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';

/// 下注记录（对应原生 BettingRecordActivity.kt）
class BettingRecordPage extends StatefulWidget {
  const BettingRecordPage({super.key});

  @override
  State<BettingRecordPage> createState() => _BettingRecordPageState();
}

class _BettingRecordPageState extends State<BettingRecordPage> {
  final ApiService _api = ApiService();
  List<_BettingRecordRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getMyTouzhu(page: 1, pageSize: 20);
      final rows = <_BettingRecordRow>[];
      if (ApiResult.isSuccess(res)) {
        final list = ApiParse.extractList(res.data['data']);
        for (final item in list) {
          rows.add(_BettingRecordRow(
            nameZh: item['name_zh']?.toString() ?? item['cpname']?.toString() ?? '未知',
            expect: item['expect']?.toString() ?? '',
            playtitle: item['playtitle']?.toString() ?? '',
            tzcode: item['tzcode']?.toString() ?? '',
            amount: (item['amount'] as num?)?.toDouble() ?? 0,
            beishu: (item['beishu'] as num?)?.toInt() ?? 1,
            statusText: item['status_text']?.toString() ?? '',
            winAmount: (item['win_amount'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      if (mounted) {
        AppToast.show('加载失败', context: context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('下注记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text('暂无下注记录', style: TextStyle(color: Colors.grey[600])),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _BettingRecordCard(row: _rows[index]),
                  ),
                ),
    );
  }
}

class _BettingRecordRow {
  final String nameZh;
  final String expect;
  final String playtitle;
  final String tzcode;
  final double amount;
  final int beishu;
  final String statusText;
  final double winAmount;

  const _BettingRecordRow({
    required this.nameZh,
    required this.expect,
    required this.playtitle,
    required this.tzcode,
    required this.amount,
    required this.beishu,
    required this.statusText,
    required this.winAmount,
  });
}

class _BettingRecordCard extends StatelessWidget {
  final _BettingRecordRow row;

  const _BettingRecordCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.nameZh,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                row.statusText.isEmpty ? '—' : row.statusText,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line('期号', '第 ${row.expect} 期'),
          _line('玩法', row.playtitle),
          _line('投注内容', row.tzcode),
          _line('投注金额', '¥${row.amount}  ${row.beishu}倍'),
          if (row.winAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '中奖金额: ¥${row.winAmount}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      ),
    );
  }
}
